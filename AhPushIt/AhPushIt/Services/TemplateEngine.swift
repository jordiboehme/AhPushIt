import Foundation

enum TemplateEngine {
    static func buildFields(from notification: AppNotification) -> [String: String] {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        let fileDateFormatter = DateFormatter()
        fileDateFormatter.dateFormat = "yyyy-MM-dd"

        let isoFormatter = ISO8601DateFormatter()

        return [
            "app": notification.bundleIdentifier,
            "appName": notification.appName,
            "title": notification.title,
            "subtitle": notification.subtitle,
            "body": notification.body,
            "message": notification.message,
            "date": formatter.string(from: notification.date),
            "fileDate": fileDateFormatter.string(from: notification.date),
            "timestamp": String(Int(notification.date.timeIntervalSince1970)),
            "isoDate": isoFormatter.string(from: notification.date),
        ]
    }

    static func resolve(template: String, fields: [String: String]) -> String {
        var result = template
        for (key, value) in fields {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }

    static func resolveForPath(template: String, fields: [String: String], dateFormat: String = "yyyy-MM-dd") -> String {
        var sanitized = fields
        for (key, value) in sanitized {
            if key == "date" || key == "fileDate" {
                // Re-format date with custom format if needed
                continue
            }
            sanitized[key] = value
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: ":", with: "_")
                .replacingOccurrences(of: "\0", with: "")
        }
        return resolve(template: template, fields: sanitized)
    }
}
