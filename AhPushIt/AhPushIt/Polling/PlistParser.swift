import Foundation

enum PlistParser {
    static func parse(data: Data) -> AppNotification? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = plist as? [String: Any] else {
            return nil
        }

        let bundleID = dict["app"] as? String ?? ""

        var dateValue: Double = 0
        if let d = dict["date"] as? Double {
            dateValue = d
        } else if let d = dict["date"] as? Int {
            dateValue = Double(d)
        }

        var title = ""
        var subtitle = ""
        var body = ""
        if let req = dict["req"] as? [String: Any] {
            title = req["titl"] as? String ?? ""
            subtitle = req["subt"] as? String ?? ""
            body = req["body"] as? String ?? ""
        }

        let date = Date(timeIntervalSinceReferenceDate: dateValue)

        return AppNotification(
            id: 0,
            bundleIdentifier: bundleID,
            appName: fallbackAppName(bundleID),
            title: title,
            subtitle: subtitle,
            body: body,
            date: date
        )
    }

    static func parseBundleIdentifier(from data: Data) -> String? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = plist as? [String: Any],
              let bundleID = dict["app"] as? String,
              !bundleID.isEmpty else {
            return nil
        }
        return bundleID
    }

    private static func fallbackAppName(_ identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "Unknown" }
        let parts = trimmed.split(separator: ".")
        let last = parts.last.map(String.init) ?? trimmed
        return last.isEmpty ? trimmed : last
    }
}
