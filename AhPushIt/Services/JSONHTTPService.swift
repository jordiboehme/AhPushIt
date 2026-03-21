import Foundation

struct JSONHTTPService: NotificationService {
    let id: UUID
    let displayName: String
    let isEnabled: Bool

    private let url: String
    private let method: String
    private let headers: String
    private let authToken: String
    private let bodyTemplate: String
    private let titleTemplate: String
    private let messageTemplate: String

    init(configuration: ServiceConfiguration) {
        self.id = configuration.id
        self.displayName = configuration.displayName
        self.isEnabled = configuration.isEnabled
        self.titleTemplate = configuration.titleTemplate
        self.messageTemplate = configuration.messageTemplate
        self.url = configuration.parameters["url"] ?? ""
        self.method = configuration.parameters["method"] ?? "POST"
        self.headers = configuration.parameters["headers"] ?? ""
        self.authToken = configuration.parameters["authToken"] ?? ""
        self.bodyTemplate = configuration.parameters["bodyTemplate"] ?? "{}"
    }

    func send(notification: AppNotification, resolvedFields: [String: String]) async throws {
        var fields = resolvedFields
        fields["title"] = TemplateEngine.resolve(template: titleTemplate, fields: resolvedFields)
        fields["message"] = TemplateEngine.resolve(template: messageTemplate, fields: resolvedFields)

        let resolvedBody = TemplateEngine.resolve(template: bodyTemplate, fields: fields)

        guard let requestURL = URL(string: url) else {
            throw JSONHTTPError.invalidURL(url)
        }

        guard let bodyData = resolvedBody.data(using: .utf8) else {
            throw JSONHTTPError.invalidBody
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if !authToken.isEmpty {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        // Parse custom headers (one "Key: Value" per line)
        for line in headers.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[trimmed.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                if !key.isEmpty {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 300 {
            let snippet = String(data: data.prefix(1024), encoding: .utf8) ?? ""
            throw JSONHTTPError.httpError(httpResponse.statusCode, snippet)
        }
    }
}

enum JSONHTTPError: LocalizedError {
    case invalidURL(String)
    case invalidBody
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "Invalid URL: \(url)"
        case .invalidBody: return "Failed to encode request body"
        case .httpError(let code, let body): return "HTTP \(code): \(body)"
        }
    }
}
