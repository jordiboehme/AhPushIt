import SwiftUI

struct FiltersPane: View {
    @Bindable private var settings = AppSettings.shared
    @State private var searchText = ""
    @State private var newEntry = ""
    @State private var isLoadingApps = false
    @State private var testStatus: TestStatus?

    var filteredRules: [FilterRule] {
        let rules = settings.filterRules.sorted { a, b in
            a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
        if searchText.isEmpty { return rules }
        return rules.filter {
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText) ||
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var selectedCount: Int {
        settings.filterRules.filter(\.isSelected).count
    }

    var hasEnabledIMessageService: Bool {
        settings.serviceConfigurations.contains { $0.type == .iMessage && $0.isEnabled }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: mode picker + status
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "App Filters", icon: "line.3.horizontal.decrease.circle")

                HStack(spacing: 12) {
                    Picker("", selection: $settings.filterMode) {
                        Label("Exclude", systemImage: "xmark.circle").tag(FilterMode.exclude)
                        Label("Include Only", systemImage: "checkmark.circle").tag(FilterMode.include)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)

                    Spacer()

                    Text("\(selectedCount) selected")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Text(settings.filterMode == .exclude
                     ? "Selected apps will NOT be forwarded."
                     : "ONLY selected apps will be forwarded.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if hasEnabledIMessageService {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Messages notifications are automatically blocked to prevent loops with the Apple Messages service.")
                            .font(.callout)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                TextField("Search by name or bundle ID...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // App list
            if filteredRules.isEmpty && settings.filterRules.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 28))
                        .foregroundStyle(.quaternary)
                    Text("No apps discovered yet")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Scan Notification Database") {
                        loadAppsFromDatabase()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoadingApps)
                }
                Spacer()
            } else if filteredRules.isEmpty {
                Spacer()
                Text("No apps matching \"\(searchText)\"")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                Spacer()
            } else {
                List {
                    ForEach(filteredRules) { rule in
                        if let idx = settings.filterRules.firstIndex(where: { $0.id == rule.id }) {
                            AppFilterRow(
                                rule: $settings.filterRules[idx],
                                isManual: rule.isManual,
                                onDelete: rule.isManual ? {
                                    withAnimation {
                                        settings.filterRules.removeAll { $0.id == rule.id }
                                    }
                                } : nil
                            )
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            Divider()

            // Bottom toolbar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                    TextField("Add by name or bundle ID...", text: $newEntry)
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .onSubmit { addManualEntry() }
                }

                if !newEntry.isEmpty {
                    Button("Add") { addManualEntry() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }

                Spacer()

                Button {
                    sendTestNotification()
                } label: {
                    switch testStatus {
                    case .sending:
                        ProgressView()
                            .controlSize(.small)
                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .error:
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    case nil:
                        Image(systemName: "bell.badge")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(testStatus == .sending)
                .help(testStatusHelp)

                if !settings.filterRules.isEmpty {
                    Button {
                        loadAppsFromDatabase()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Rescan notification database")
                    .disabled(isLoadingApps)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func loadAppsFromDatabase() {
        isLoadingApps = true
        Task {
            do {
                let db = try SQLiteDatabase(path: SQLiteDatabase.databasePath())
                let bundleIDs = try db.fetchDistinctBundleIDs()
                let resolver = BundleNameResolver.shared

                for bundleID in bundleIDs {
                    guard !settings.filterRules.contains(where: { $0.bundleIdentifier == bundleID }) else {
                        continue
                    }
                    let name = await resolver.resolve(bundleID)
                    let rule = FilterRule(bundleIdentifier: bundleID, displayName: name, isSelected: false)
                    await MainActor.run {
                        settings.filterRules.append(rule)
                    }
                }
            } catch {
                // Silently fail
            }
            await MainActor.run {
                isLoadingApps = false
            }
        }
    }

    private var testStatusHelp: String {
        switch testStatus {
        case .error(let msg): return msg
        default: return "Send a test notification to all enabled services"
        }
    }

    private func sendTestNotification() {
        let services = settings.serviceConfigurations
            .filter(\.isEnabled)
            .compactMap { $0.createService() }
        guard !services.isEmpty else {
            testStatus = .error("No enabled services")
            autoDismissTestStatus()
            return
        }
        testStatus = .sending
        Task {
            let error = await TestNotificationSender.send(to: services)
            await MainActor.run {
                testStatus = error == nil ? .success : .error(error!)
                autoDismissTestStatus()
            }
        }
    }

    private func autoDismissTestStatus() {
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run { testStatus = nil }
        }
    }

    private func addManualEntry() {
        let trimmed = newEntry.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let isBundleID = trimmed.contains(".")
        let bundleID = trimmed
        let displayName = isBundleID ? (trimmed.split(separator: ".").last.map(String.init) ?? trimmed) : trimmed

        guard !settings.filterRules.contains(where: {
            $0.bundleIdentifier.caseInsensitiveCompare(bundleID) == .orderedSame ||
            $0.displayName.caseInsensitiveCompare(displayName) == .orderedSame
        }) else {
            newEntry = ""
            return
        }

        withAnimation {
            settings.filterRules.append(
                FilterRule(bundleIdentifier: bundleID, displayName: displayName, isSelected: false, isManual: true)
            )
        }
        newEntry = ""
    }
}

// MARK: - App Filter Row

struct AppFilterRow: View {
    @Binding var rule: FilterRule
    let isManual: Bool
    var onDelete: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $rule.isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(rule.displayName)
                        .font(.callout)
                    if isManual {
                        Text("manual")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .foregroundStyle(.secondary)
                    }
                }
                if !rule.bundleIdentifier.isEmpty && rule.bundleIdentifier != rule.displayName {
                    Text(rule.bundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if let onDelete, isHovering {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { rule.isSelected.toggle() }
    }
}
