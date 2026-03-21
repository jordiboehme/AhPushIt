import Foundation

struct ParameterDefinition {
    let key: String
    let label: String
    let placeholder: String
    let fieldType: ParameterFieldType
    let isRequired: Bool
    let defaultValue: String
}

enum ParameterFieldType {
    case text
    case secure
    case template
    case filePath
    case picker([(label: String, value: String)])
    case columns(available: [(key: String, label: String)])
}
