import Foundation

struct FilterRule: Identifiable, Codable, Equatable {
    var id = UUID()
    var bundleIdentifier: String
    var displayName: String
    var isSelected: Bool
    var isManual: Bool = false
}

enum FilterMode: String, Codable, CaseIterable {
    case exclude
    case include
}
