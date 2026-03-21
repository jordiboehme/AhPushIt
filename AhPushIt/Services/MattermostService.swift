import Foundation

struct MattermostService: NotificationService {
    let id: UUID
    let displayName: String
    let isEnabled: Bool

    private let webhookURL: String
    private let titleTemplate: String
    private let messageTemplate: String

    init(configuration: ServiceConfiguration) {
        self.id = configuration.id
        self.displayName = configuration.displayName
        self.isEnabled = configuration.isEnabled
        self.titleTemplate = configuration.titleTemplate
        self.messageTemplate = configuration.messageTemplate
        self.webhookURL = configuration.parameters["webhookURL"] ?? ""
    }

    func send(notification: AppNotification, resolvedFields: [String: String]) async throws {
        let title = TemplateEngine.resolve(template: titleTemplate, fields: resolvedFields)
        let message = TemplateEngine.resolve(template: messageTemplate, fields: resolvedFields)

        let text = title.isEmpty ? message : "**\(title)**\n\(message)"
        let payload: [String: Any] = ["text": text]
        let body = try JSONSerialization.data(withJSONObject: payload)

        guard let url = URL(string: webhookURL) else {
            throw WebhookError.invalidURL(webhookURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 300 {
            let snippet = String(data: data.prefix(1024), encoding: .utf8) ?? ""
            throw WebhookError.httpError(httpResponse.statusCode, snippet)
        }
    }
}
