import Foundation

struct CSVFileService: NotificationService {
    let id: UUID
    let displayName: String
    let isEnabled: Bool

    private let directoryPath: String
    private let fileNameTemplate: String
    private let columns: [String]
    private let includeHeader: Bool
    private let dateFormat: String

    init(configuration: ServiceConfiguration) {
        self.id = configuration.id
        self.displayName = configuration.displayName
        self.isEnabled = configuration.isEnabled
        self.directoryPath = configuration.parameters["directoryPath"] ?? "~/Documents/AhPushIt"
        self.fileNameTemplate = configuration.parameters["fileNameTemplate"] ?? "{{fileDate}}.csv"
        self.columns = (configuration.parameters["columns"] ?? "date,appName,title,subtitle,body")
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        self.includeHeader = configuration.parameters["includeHeader"] != "false"
        self.dateFormat = configuration.parameters["dateFormat"] ?? "yyyy-MM-dd"
    }

    func send(notification: AppNotification, resolvedFields: [String: String]) async throws {
        let expandedDir = (directoryPath as NSString).expandingTildeInPath
        let resolvedDir = TemplateEngine.resolveForPath(template: expandedDir, fields: resolvedFields, dateFormat: dateFormat)
        let resolvedFileName = TemplateEngine.resolveForPath(template: fileNameTemplate, fields: resolvedFields, dateFormat: dateFormat)

        let dirURL = URL(fileURLWithPath: resolvedDir)
        let fileURL = dirURL.appendingPathComponent(resolvedFileName)

        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let values = columns.map { col in
            csvEscape(resolvedFields[col] ?? "")
        }
        let row = values.joined(separator: ",")

        let fileExists = FileManager.default.fileExists(atPath: fileURL.path)

        if !fileExists {
            var content = ""
            if includeHeader {
                content = columns.joined(separator: ",") + "\n"
            }
            content += row + "\n"
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } else {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { handle.closeFile() }
            handle.seekToEndOfFile()
            if let data = (row + "\n").data(using: .utf8) {
                handle.write(data)
            }
        }
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}

enum CSVFileError: LocalizedError {
    case writeError(String)

    var errorDescription: String? {
        switch self {
        case .writeError(let msg): return "CSV write error: \(msg)"
        }
    }
}
