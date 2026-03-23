import Foundation

struct HomeAssistantService: NotificationService {
    let id: UUID
    let displayName: String
    let isEnabled: Bool

    private let baseURL: String
    private let accessToken: String
    private let eventType: String
    private let titleTemplate: String
    private let messageTemplate: String

    init(configuration: ServiceConfiguration) {
        self.id = configuration.id
        self.displayName = configuration.displayName
        self.isEnabled = configuration.isEnabled
        self.titleTemplate = configuration.titleTemplate
        self.messageTemplate = configuration.messageTemplate
        self.baseURL = configuration.parameters["baseURL"] ?? ""
        self.accessToken = configuration.parameters["accessToken"] ?? ""
        self.eventType = configuration.parameters["eventType"] ?? "ahpushit_notification"
    }

    func send(notification: AppNotification, resolvedFields: [String: String]) async throws {
        let title = TemplateEngine.resolve(template: titleTemplate, fields: resolvedFields)
        let message = TemplateEngine.resolve(template: messageTemplate, fields: resolvedFields)

        var payload: [String: String] = [:]
        for (key, value) in resolvedFields {
            payload[key] = value
        }
        payload["title"] = title
        payload["message"] = message

        let body = try JSONSerialization.data(withJSONObject: payload)

        let urlString = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(urlString)/api/events/\(eventType)") else {
            throw HomeAssistantError.invalidURL(baseURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 300 {
            let snippet = String(data: data.prefix(1024), encoding: .utf8) ?? ""
            throw HomeAssistantError.httpError(httpResponse.statusCode, snippet)
        }
    }
}

enum HomeAssistantError: LocalizedError {
    case invalidURL(String)
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "Invalid Home Assistant URL: \(url)"
        case .httpError(let code, let body): return "Home Assistant returned \(code): \(body)"
        }
    }
}
