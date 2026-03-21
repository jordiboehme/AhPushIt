import Foundation

struct NtfyService: NotificationService {
    let id: UUID
    let displayName: String
    let isEnabled: Bool

    private let serverURL: String
    private let topic: String
    private let authToken: String
    private let titleTemplate: String
    private let messageTemplate: String
    private let tagsTemplate: String
    private let priority: Int

    init(configuration: ServiceConfiguration) {
        self.id = configuration.id
        self.displayName = configuration.displayName
        self.isEnabled = configuration.isEnabled
        self.titleTemplate = configuration.titleTemplate
        self.messageTemplate = configuration.messageTemplate
        self.serverURL = configuration.parameters["serverURL"] ?? ""
        self.topic = configuration.parameters["topic"] ?? ""
        self.authToken = configuration.parameters["authToken"] ?? ""
        self.tagsTemplate = configuration.parameters["tagsTemplate"] ?? "{{appName}}"
        self.priority = Int(configuration.parameters["priority"] ?? "3") ?? 3
    }

    func send(notification: AppNotification, resolvedFields: [String: String]) async throws {
        let title = TemplateEngine.resolve(template: titleTemplate, fields: resolvedFields)
        let message = TemplateEngine.resolve(template: messageTemplate, fields: resolvedFields)
        let tags = TemplateEngine.resolve(template: tagsTemplate, fields: resolvedFields)

        let payload: [String: Any] = [
            "topic": topic,
            "title": title,
            "message": message,
            "tags": tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            "priority": priority,
        ]

        let body = try JSONSerialization.data(withJSONObject: payload)

        guard let url = URL(string: serverURL) else {
            throw NtfyError.invalidURL(serverURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if !authToken.isEmpty {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 300 {
            let snippet = String(data: data.prefix(1024), encoding: .utf8) ?? ""
            throw NtfyError.httpError(httpResponse.statusCode, snippet)
        }
    }
}

enum NtfyError: LocalizedError {
    case invalidURL(String)
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "Invalid ntfy URL: \(url)"
        case .httpError(let code, let body): return "ntfy returned \(code): \(body)"
        }
    }
}
