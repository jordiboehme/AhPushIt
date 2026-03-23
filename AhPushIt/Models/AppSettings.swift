import Foundation
import SwiftUI

@Observable
final class AppSettings {
    static let shared = AppSettings()

    // MARK: - Polling

    var pollInterval: Int {
        didSet { UserDefaults.standard.set(pollInterval, forKey: "pollInterval") }
    }

    // MARK: - Schedule

    var scheduleEnabled: Bool {
        didSet { UserDefaults.standard.set(scheduleEnabled, forKey: "scheduleEnabled") }
    }

    var timeWindows: [TimeWindow] {
        didSet {
            if let data = try? JSONEncoder().encode(timeWindows) {
                UserDefaults.standard.set(data, forKey: "timeWindows")
            }
        }
    }

    // MARK: - Away Detection

    var awayDetectionEnabled: Bool {
        didSet { UserDefaults.standard.set(awayDetectionEnabled, forKey: "awayDetectionEnabled") }
    }

    var awayAfterMinutes: Int {
        didSet { UserDefaults.standard.set(awayAfterMinutes, forKey: "awayAfterMinutes") }
    }

    var forwardOnScreenLock: Bool {
        didSet { UserDefaults.standard.set(forwardOnScreenLock, forKey: "forwardOnScreenLock") }
    }

    // MARK: - Filters

    var filterMode: FilterMode {
        didSet { UserDefaults.standard.set(filterMode.rawValue, forKey: "filterMode") }
    }

    var filterRules: [FilterRule] {
        didSet {
            if let data = try? JSONEncoder().encode(filterRules) {
                UserDefaults.standard.set(data, forKey: "filterRules")
            }
        }
    }

    // MARK: - Services

    var serviceConfigurations: [ServiceConfiguration] {
        didSet {
            if let data = try? JSONEncoder().encode(serviceConfigurations) {
                UserDefaults.standard.set(data, forKey: "serviceConfigurations")
            }
        }
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard

        self.pollInterval = defaults.object(forKey: "pollInterval") as? Int ?? 5
        self.scheduleEnabled = defaults.bool(forKey: "scheduleEnabled")
        self.awayDetectionEnabled = defaults.bool(forKey: "awayDetectionEnabled")
        self.awayAfterMinutes = defaults.object(forKey: "awayAfterMinutes") as? Int ?? 5
        self.forwardOnScreenLock = defaults.object(forKey: "forwardOnScreenLock") as? Bool ?? true

        if let data = defaults.data(forKey: "timeWindows"),
           let windows = try? JSONDecoder().decode([TimeWindow].self, from: data) {
            self.timeWindows = windows
        } else {
            self.timeWindows = []
        }

        if let raw = defaults.string(forKey: "filterMode"),
           let mode = FilterMode(rawValue: raw) {
            self.filterMode = mode
        } else {
            self.filterMode = .exclude
        }

        if let data = defaults.data(forKey: "filterRules"),
           let rules = try? JSONDecoder().decode([FilterRule].self, from: data) {
            self.filterRules = rules
        } else {
            self.filterRules = []
        }

        if let data = defaults.data(forKey: "serviceConfigurations"),
           let configs = try? JSONDecoder().decode([ServiceConfiguration].self, from: data) {
            self.serviceConfigurations = configs
        } else {
            self.serviceConfigurations = []
        }
    }

    // MARK: - Schedule Logic

    func isWithinSchedule(at date: Date = Date()) -> Bool {
        guard scheduleEnabled else { return true }
        if timeWindows.isEmpty { return true }
        return timeWindows.contains { $0.isActive(at: date) }
    }

    func shouldForward(bundleIdentifier: String, displayName: String) -> Bool {
        let selectedRules = filterRules.filter(\.isSelected)
        if selectedRules.isEmpty { return true }

        let matches = selectedRules.contains {
            $0.bundleIdentifier == bundleIdentifier || $0.displayName == displayName
        }

        switch filterMode {
        case .exclude: return !matches
        case .include: return matches
        }
    }
}

struct ServiceConfiguration: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: ServiceType
    var displayName: String
    var isEnabled: Bool
    var titleTemplate: String
    var messageTemplate: String
    var parameters: [String: String]

    static func defaultConfiguration(for type: ServiceType) -> ServiceConfiguration {
        var params: [String: String] = [:]
        for def in type.parameterDefinitions {
            params[def.key] = def.defaultValue
        }
        return ServiceConfiguration(
            type: type,
            displayName: type.displayName,
            isEnabled: true,
            titleTemplate: "{{title}}",
            messageTemplate: "{{message}}",
            parameters: params
        )
    }

    func createService() -> (any NotificationService)? {
        switch type {
        case .ntfy: return NtfyService(configuration: self)
        case .n8n: return N8nService(configuration: self)
        case .pushover: return PushoverService(configuration: self)
        case .jsonHTTP: return JSONHTTPService(configuration: self)
        case .csvFile: return CSVFileService(configuration: self)
        case .slack: return SlackService(configuration: self)
        case .discord: return DiscordService(configuration: self)
        case .telegram: return TelegramService(configuration: self)
        case .mattermost: return MattermostService(configuration: self)
        }
    }

    var summaryDescription: String {
        switch type {
        case .ntfy:
            let url = parameters["serverURL"] ?? ""
            let topic = parameters["topic"] ?? ""
            return topic.isEmpty ? url : "\(url)/\(topic)"
        case .pushover:
            return "Pushover"
        case .csvFile:
            return parameters["directoryPath"] ?? "~/Documents/AhPushIt"
        case .n8n, .jsonHTTP, .slack, .discord, .mattermost:
            return parameters["webhookURL"] ?? parameters["url"] ?? ""
        case .telegram:
            return "Chat \(parameters["chatID"] ?? "")"
        }
    }

    // MARK: - Backward-compatible decoding

    init(type: ServiceType, displayName: String, isEnabled: Bool,
         titleTemplate: String, messageTemplate: String, parameters: [String: String]) {
        self.type = type
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.titleTemplate = titleTemplate
        self.messageTemplate = messageTemplate
        self.parameters = parameters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ServiceType.self, forKey: .type)
        displayName = try container.decode(String.self, forKey: .displayName)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        titleTemplate = try container.decode(String.self, forKey: .titleTemplate)
        messageTemplate = try container.decode(String.self, forKey: .messageTemplate)

        // Try new format first
        if let params = try? container.decode([String: String].self, forKey: .parameters) {
            parameters = params
        } else {
            // Migrate from old flat fields
            var params: [String: String] = [:]
            if let v = try? container.decode(String.self, forKey: .serverURL) { params["serverURL"] = v }
            if let v = try? container.decode(String.self, forKey: .topic) { params["topic"] = v }
            if let v = try? container.decode(String.self, forKey: .authToken), !v.isEmpty { params["authToken"] = v }
            if let v = try? container.decode(String.self, forKey: .tagsTemplate) { params["tagsTemplate"] = v }
            if let v = try? container.decode(Int.self, forKey: .priority) { params["priority"] = String(v) }
            parameters = params
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(titleTemplate, forKey: .titleTemplate)
        try container.encode(messageTemplate, forKey: .messageTemplate)
        try container.encode(parameters, forKey: .parameters)
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, displayName, isEnabled, titleTemplate, messageTemplate, parameters
        // Legacy keys for migration
        case serverURL, topic, authToken, tagsTemplate, priority
    }
}

enum ServiceType: String, Codable, CaseIterable {
    case ntfy
    case n8n
    case pushover
    case jsonHTTP
    case csvFile
    case slack
    case discord
    case telegram
    case mattermost

    var displayName: String {
        switch self {
        case .ntfy: return "ntfy"
        case .n8n: return "n8n"
        case .pushover: return "Pushover"
        case .jsonHTTP: return "JSON HTTP"
        case .csvFile: return "CSV File"
        case .slack: return "Slack"
        case .discord: return "Discord"
        case .telegram: return "Telegram"
        case .mattermost: return "Mattermost"
        }
    }

    var icon: String {
        switch self {
        case .ntfy: return "bell"
        case .n8n: return "gearshape.2"
        case .pushover: return "iphone.badge.play"
        case .jsonHTTP: return "curlybraces"
        case .csvFile: return "doc.text"
        case .slack: return "number"
        case .discord: return "bubble.left.and.bubble.right"
        case .telegram: return "paperplane"
        case .mattermost: return "message"
        }
    }

    var parameterDefinitions: [ParameterDefinition] {
        switch self {
        case .ntfy:
            return [
                ParameterDefinition(key: "serverURL", label: "Server URL", placeholder: "https://ntfy.sh", fieldType: .text, isRequired: true, defaultValue: "https://ntfy.sh"),
                ParameterDefinition(key: "topic", label: "Topic", placeholder: "my-topic", fieldType: .text, isRequired: true, defaultValue: ""),
                ParameterDefinition(key: "authToken", label: "Auth Token", placeholder: "Optional", fieldType: .secure, isRequired: false, defaultValue: ""),
                ParameterDefinition(key: "tagsTemplate", label: "Tags", placeholder: "{{appName}}", fieldType: .template, isRequired: false, defaultValue: "{{appName}}"),
                ParameterDefinition(key: "priority", label: "Priority", placeholder: "", fieldType: .picker([
                    (label: "Min (1)", value: "1"),
                    (label: "Low (2)", value: "2"),
                    (label: "Default (3)", value: "3"),
                    (label: "High (4)", value: "4"),
                    (label: "Urgent (5)", value: "5"),
                ]), isRequired: false, defaultValue: "3"),
            ]
        case .n8n:
            return [
                ParameterDefinition(key: "webhookURL", label: "Webhook URL", placeholder: "https://n8n.example.com/webhook/...", fieldType: .text, isRequired: true, defaultValue: ""),
            ]
        case .pushover:
            return [
                ParameterDefinition(key: "userKey", label: "User Key", placeholder: "Your Pushover user key", fieldType: .secure, isRequired: true, defaultValue: ""),
                ParameterDefinition(key: "appToken", label: "App Token", placeholder: "Your Pushover app token", fieldType: .secure, isRequired: true, defaultValue: ""),
                ParameterDefinition(key: "device", label: "Device", placeholder: "Optional device name", fieldType: .text, isRequired: false, defaultValue: ""),
                ParameterDefinition(key: "sound", label: "Sound", placeholder: "pushover", fieldType: .text, isRequired: false, defaultValue: ""),
                ParameterDefinition(key: "priority", label: "Priority", placeholder: "", fieldType: .picker([
                    (label: "Lowest (-2)", value: "-2"),
                    (label: "Low (-1)", value: "-1"),
                    (label: "Normal (0)", value: "0"),
                    (label: "High (1)", value: "1"),
                ]), isRequired: false, defaultValue: "0"),
            ]
        case .jsonHTTP:
            return [
                ParameterDefinition(key: "url", label: "URL", placeholder: "https://example.com/webhook", fieldType: .text, isRequired: true, defaultValue: ""),
                ParameterDefinition(key: "method", label: "Method", placeholder: "", fieldType: .picker([
                    (label: "POST", value: "POST"),
                    (label: "PUT", value: "PUT"),
                ]), isRequired: false, defaultValue: "POST"),
                ParameterDefinition(key: "headers", label: "Headers", placeholder: "Key: Value (one per line)", fieldType: .text, isRequired: false, defaultValue: ""),
                ParameterDefinition(key: "authToken", label: "Auth Token", placeholder: "Optional Bearer token", fieldType: .secure, isRequired: false, defaultValue: ""),
                ParameterDefinition(key: "bodyTemplate", label: "Body", placeholder: "{\"title\":\"{{title}}\"}", fieldType: .template, isRequired: false, defaultValue: "{\"title\":\"{{title}}\",\"message\":\"{{message}}\",\"app\":\"{{appName}}\",\"date\":\"{{date}}\"}"),
            ]
        case .csvFile:
            let availableColumns: [(key: String, label: String)] = [
                ("date", "Date/Time"),
                ("fileDate", "File Date"),
                ("isoDate", "ISO Date"),
                ("timestamp", "Timestamp"),
                ("app", "Bundle ID"),
                ("appName", "App Name"),
                ("title", "Title"),
                ("subtitle", "Subtitle"),
                ("body", "Body"),
                ("message", "Message"),
            ]
            return [
                ParameterDefinition(key: "directoryPath", label: "Directory", placeholder: "~/Documents/AhPushIt", fieldType: .filePath, isRequired: true, defaultValue: "~/Documents/AhPushIt"),
                ParameterDefinition(key: "fileNameTemplate", label: "Filename", placeholder: "{{fileDate}}.csv", fieldType: .template, isRequired: true, defaultValue: "{{fileDate}}.csv"),
                ParameterDefinition(key: "columns", label: "Columns", placeholder: "", fieldType: .columns(available: availableColumns), isRequired: false, defaultValue: "date,appName,title,subtitle,body"),
                ParameterDefinition(key: "includeHeader", label: "Include Header", placeholder: "", fieldType: .picker([
                    (label: "Yes", value: "true"),
                    (label: "No", value: "false"),
                ]), isRequired: false, defaultValue: "true"),
                ParameterDefinition(key: "dateFormat", label: "Date Format", placeholder: "yyyy-MM-dd", fieldType: .text, isRequired: false, defaultValue: "yyyy-MM-dd"),
            ]
        case .slack:
            return [
                ParameterDefinition(key: "webhookURL", label: "Webhook URL", placeholder: "https://hooks.slack.com/services/...", fieldType: .text, isRequired: true, defaultValue: ""),
            ]
        case .discord:
            return [
                ParameterDefinition(key: "webhookURL", label: "Webhook URL", placeholder: "https://discord.com/api/webhooks/...", fieldType: .text, isRequired: true, defaultValue: ""),
            ]
        case .telegram:
            return [
                ParameterDefinition(key: "botToken", label: "Bot Token", placeholder: "123456:ABC-DEF...", fieldType: .secure, isRequired: true, defaultValue: ""),
                ParameterDefinition(key: "chatID", label: "Chat ID", placeholder: "Your chat or group ID", fieldType: .text, isRequired: true, defaultValue: ""),
            ]
        case .mattermost:
            return [
                ParameterDefinition(key: "webhookURL", label: "Webhook URL", placeholder: "https://mattermost.example.com/hooks/...", fieldType: .text, isRequired: true, defaultValue: ""),
            ]
        }
    }
}
