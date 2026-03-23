import Foundation

@Observable
final class NotificationPoller {
    private var timer: Timer?
    private var database: SQLiteDatabase?
    private var lastID: Int64 = 0
    private var lastDate: Double = 0
    private var isChecking = false
    private let idleManager = IdleManager()
    private var wasUserAway = false

    private(set) var forwardedCount: Int = 0
    private(set) var lastForwardedTime: Date?
    private(set) var lastError: String?

    private let settings = AppSettings.shared
    private let resolver = BundleNameResolver.shared

    var services: [any NotificationService] {
        settings.serviceConfigurations.compactMap { config in
            guard config.isEnabled else { return nil }
            return config.createService()
        }
    }

    func start() {
        stop()

        do {
            let path = SQLiteDatabase.databasePath()
            database = try SQLiteDatabase(path: path)
            try initializeLastRecord()
        } catch {
            lastError = error.localizedDescription
            return
        }

        lastError = nil
        idleManager.start()
        scheduleTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        database = nil
        idleManager.stop()
    }

    func restart() {
        stop()
        start()
    }

    private func scheduleTimer() {
        let interval = TimeInterval(max(settings.pollInterval, 1))
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    private func initializeLastRecord() throws {
        guard let db = database else { return }
        if let record = try db.fetchRecord(offset: 0) {
            lastID = record.id
            lastDate = record.timestamp
        }
    }

    func check() {
        guard !isChecking else { return }
        guard let db = database else { return }

        // Check schedule before doing any DB work
        guard settings.isWithinSchedule() else { return }

        // Away detection gate
        if settings.awayDetectionEnabled {
            let idleSeconds = idleManager.idleTimeSeconds
            let thresholdSeconds = Double(settings.awayAfterMinutes * 60)
            let isAway = idleSeconds >= thresholdSeconds
                         || (settings.forwardOnScreenLock && idleManager.isScreenLocked)

            if !wasUserAway && isAway {
                // Transition: just went away — cap backfill to threshold
                let backfillDate = Date().timeIntervalSinceReferenceDate - thresholdSeconds
                lastDate = max(lastDate, backfillDate)
            }
            wasUserAway = isAway

            guard isAway else { return }
        }

        isChecking = true
        defer { isChecking = false }

        do {
            var offset = 0
            var record = try db.fetchRecord(offset: offset)
            guard let first = record else { return }

            let newestID = first.id
            let newestDate = first.timestamp

            // Collect notifications that pass filters
            var toForward: [AppNotification] = []

            while let rec = record, rec.id != lastID, rec.timestamp >= lastDate {
                if let notification = PlistParser.parse(data: rec.data) {
                    let notif = AppNotification(
                        id: rec.id,
                        bundleIdentifier: notification.bundleIdentifier,
                        appName: notification.appName,
                        title: notification.title,
                        subtitle: notification.subtitle,
                        body: notification.body,
                        date: Date(timeIntervalSinceReferenceDate: rec.timestamp)
                    )

                    // Check filters before adding to forward list
                    if settings.shouldForward(bundleIdentifier: notif.bundleIdentifier, displayName: notif.appName) {
                        toForward.append(notif)
                    }
                }
                offset += 1
                record = try db.fetchRecord(offset: offset)
            }

            lastID = newestID
            lastDate = newestDate
            lastError = nil

            // Forward collected notifications after DB reads are done
            if !toForward.isEmpty {
                Task {
                    for notif in toForward {
                        let success = await forward(notif)
                        if success {
                            await MainActor.run {
                                forwardedCount += 1
                                lastForwardedTime = Date()
                            }
                        }
                    }
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func forward(_ notification: AppNotification) async -> Bool {
        var notif = notification

        // Resolve display name
        let resolvedName = await resolver.resolve(notif.bundleIdentifier)
        notif = AppNotification(
            id: notif.id,
            bundleIdentifier: notif.bundleIdentifier,
            appName: resolvedName,
            title: notif.title,
            subtitle: notif.subtitle,
            body: notif.body,
            date: notif.date
        )

        // Build resolved fields for templates
        let fields = TemplateEngine.buildFields(from: notif)

        // Send to all enabled services
        var anySuccess = false
        for service in services {
            do {
                try await service.send(notification: notif, resolvedFields: fields)
                anySuccess = true
            } catch {
                await MainActor.run {
                    lastError = "[\(service.displayName)] \(error.localizedDescription)"
                }
            }
        }

        return anySuccess
    }
}
