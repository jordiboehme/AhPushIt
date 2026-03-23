import Foundation

struct IMessageService: NotificationService {
    let id: UUID
    let displayName: String
    let isEnabled: Bool

    private let recipient: String
    private let titleTemplate: String
    private let messageTemplate: String

    init(configuration: ServiceConfiguration) {
        self.id = configuration.id
        self.displayName = configuration.displayName
        self.isEnabled = configuration.isEnabled
        self.titleTemplate = configuration.titleTemplate
        self.messageTemplate = configuration.messageTemplate
        self.recipient = configuration.parameters["recipient"] ?? ""
    }

    func send(notification: AppNotification, resolvedFields: [String: String]) async throws {
        guard !recipient.isEmpty else {
            throw IMessageError.missingRecipient
        }

        let title = TemplateEngine.resolve(template: titleTemplate, fields: resolvedFields)
        let message = TemplateEngine.resolve(template: messageTemplate, fields: resolvedFields)
        let text = title.isEmpty ? message : "\(title)\n\(message)"

        let escapedText = escapeForAppleScript(text)
        let escapedRecipient = escapeForAppleScript(recipient)

        let script = """
            tell application "Messages"
                send "\(escapedText)" to buddy "\(escapedRecipient)"
            end tell
            """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrString = String(data: stderrData, encoding: .utf8) ?? ""
            throw IMessageError.scriptError(Int(process.terminationStatus), stderrString)
        }
    }

    private func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

enum IMessageError: LocalizedError {
    case missingRecipient
    case scriptError(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingRecipient: return "Apple Messages recipient is required"
        case .scriptError(let code, let stderr): return "Apple Messages script failed (\(code)): \(stderr)"
        }
    }
}
