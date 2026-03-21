import Foundation

struct PushoverService: NotificationService {
    let id: UUID
    let displayName: String
    let isEnabled: Bool

    private let userKey: String
    private let appToken: String
    private let device: String
    private let sound: String
    private let priority: Int
    private let titleTemplate: String
    private let messageTemplate: String

    init(configuration: ServiceConfiguration) {
        self.id = configuration.id
        self.displayName = configuration.displayName
        self.isEnabled = configuration.isEnabled
        self.titleTemplate = configuration.titleTemplate
        self.messageTemplate = configuration.messageTemplate
        self.userKey = configuration.parameters["userKey"] ?? ""
        self.appToken = configuration.parameters["appToken"] ?? ""
        self.device = configuration.parameters["device"] ?? ""
        self.sound = configuration.parameters["sound"] ?? ""
        self.priority = Int(configuration.parameters["priority"] ?? "0") ?? 0
    }

    func send(notification: AppNotification, resolvedFields: [String: String]) async throws {
        guard !userKey.isEmpty, !appToken.isEmpty else {
            throw PushoverError.missingCredentials
        }

        let title = TemplateEngine.resolve(template: titleTemplate, fields: resolvedFields)
        let message = TemplateEngine.resolve(template: messageTemplate, fields: resolvedFields)

        var params: [(String, String)] = [
            ("token", appToken),
            ("user", userKey),
            ("title", title),
            ("message", message),
            ("priority", String(priority)),
        ]

        if !device.isEmpty { params.append(("device", device)) }
        if !sound.isEmpty { params.append(("sound", sound)) }

        let bodyString = params.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }.joined(separator: "&")

        guard let url = URL(string: "https://api.pushover.net/1/messages.json") else {
            throw PushoverError.httpError(0, "Invalid Pushover URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 300 {
            let snippet = String(data: data.prefix(1024), encoding: .utf8) ?? ""
            throw PushoverError.httpError(httpResponse.statusCode, snippet)
        }
    }
}

enum PushoverError: LocalizedError {
    case missingCredentials
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "Pushover user key and app token are required"
        case .httpError(let code, let body): return "Pushover returned \(code): \(body)"
        }
    }
}
