import Foundation

protocol NotificationService: Identifiable {
    var id: UUID { get }
    var displayName: String { get }
    var isEnabled: Bool { get }
    func send(notification: AppNotification, resolvedFields: [String: String]) async throws
}

enum TestStatus: Equatable {
    case sending
    case success
    case error(String)
}

enum TestNotificationSender {
    static func send(to services: [any NotificationService]) async -> String? {
        let notification = AppNotification.test
        let fields = TemplateEngine.buildFields(from: notification)
        var lastError: String?
        for service in services {
            do {
                try await service.send(notification: notification, resolvedFields: fields)
            } catch {
                lastError = "[\(service.displayName)] \(error.localizedDescription)"
            }
        }
        return lastError
    }
}

enum WebhookError: LocalizedError {
    case invalidURL(String)
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "Invalid webhook URL: \(url)"
        case .httpError(let code, let body): return "Webhook returned \(code): \(body)"
        }
    }
}
