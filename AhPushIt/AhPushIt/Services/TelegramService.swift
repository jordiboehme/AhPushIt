import Foundation

struct TelegramService: NotificationService {
    let id: UUID
    let displayName: String
    let isEnabled: Bool

    private let botToken: String
    private let chatID: String
    private let titleTemplate: String
    private let messageTemplate: String

    init(configuration: ServiceConfiguration) {
        self.id = configuration.id
        self.displayName = configuration.displayName
        self.isEnabled = configuration.isEnabled
        self.titleTemplate = configuration.titleTemplate
        self.messageTemplate = configuration.messageTemplate
        self.botToken = configuration.parameters["botToken"] ?? ""
        self.chatID = configuration.parameters["chatID"] ?? ""
    }

    func send(notification: AppNotification, resolvedFields: [String: String]) async throws {
        guard !botToken.isEmpty, !chatID.isEmpty else {
            throw TelegramError.missingCredentials
        }

        let title = TemplateEngine.resolve(template: titleTemplate, fields: resolvedFields)
        let message = TemplateEngine.resolve(template: messageTemplate, fields: resolvedFields)

        let text = title.isEmpty ? message : "\(title)\n\(message)"
        let payload: [String: Any] = [
            "chat_id": chatID,
            "text": text,
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)

        guard let url = URL(string: "https://api.telegram.org/bot\(botToken)/sendMessage") else {
            throw TelegramError.invalidToken
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 300 {
            let snippet = String(data: data.prefix(1024), encoding: .utf8) ?? ""
            throw TelegramError.httpError(httpResponse.statusCode, snippet)
        }
    }
}

enum TelegramError: LocalizedError {
    case missingCredentials
    case invalidToken
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "Telegram bot token and chat ID are required"
        case .invalidToken: return "Invalid Telegram bot token"
        case .httpError(let code, let body): return "Telegram returned \(code): \(body)"
        }
    }
}
