import Foundation

actor BundleNameResolver {
    static let shared = BundleNameResolver()

    private var cache: [String: String] = [:]

    func resolve(_ bundleIdentifier: String) async -> String {
        let trimmed = bundleIdentifier.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "Unknown" }

        if let cached = cache[trimmed] {
            return cached
        }

        let name = await lookup(trimmed)
        cache[trimmed] = name
        return name
    }

    private func lookup(_ identifier: String) async -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["kMDItemCFBundleIdentifier", "=", identifier, "-attr", "kMDItemDisplayName"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if output.isEmpty {
                return fallbackName(identifier)
            }

            let lines = output.components(separatedBy: "\n")
            guard let lastLine = lines.last else {
                return fallbackName(identifier)
            }

            let parts = lastLine.components(separatedBy: "=")
            guard parts.count == 2 else {
                return fallbackName(identifier)
            }

            let name = parts[1].trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? fallbackName(identifier) : name
        } catch {
            return fallbackName(identifier)
        }
    }

    private func fallbackName(_ identifier: String) -> String {
        let parts = identifier.split(separator: ".")
        let last = parts.last.map(String.init) ?? identifier
        return last.isEmpty ? identifier : last
    }
}
