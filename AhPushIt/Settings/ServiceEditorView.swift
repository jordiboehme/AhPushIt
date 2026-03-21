import SwiftUI

struct ServiceEditorView: View {
    @State var configuration: ServiceConfiguration
    var onSave: (ServiceConfiguration) -> Void
    var onCancel: () -> Void
    @State private var testStatus: TestStatus?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: configuration.type.icon)
                    .foregroundStyle(.secondary)
                Text(configuration.displayName.isEmpty ? "New \(configuration.type.displayName) Service" : configuration.displayName)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    GroupBox {
                        VStack(spacing: 10) {
                            FieldRow(label: "Name") {
                                TextField(configuration.type.displayName, text: $configuration.displayName)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .padding(.vertical, 4)
                    } label: {
                        Label("General", systemImage: "gearshape")
                            .font(.subheadline.weight(.medium))
                    }

                    // Service-specific parameters
                    GroupBox {
                        VStack(spacing: 10) {
                            ForEach(configuration.type.parameterDefinitions, id: \.key) { param in
                                parameterField(for: param)
                            }

                            if configuration.type == .csvFile {
                                DisclosureGroup("Placeholder Reference") {
                                    PlaceholderReference()
                                }
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } label: {
                        Label(configuration.type == .csvFile ? "File Settings" : "Connection", systemImage: configuration.type == .csvFile ? "doc.text" : "network")
                            .font(.subheadline.weight(.medium))
                    }

                    // Templates (not shown for CSV)
                    if configuration.type != .csvFile {
                        GroupBox {
                            VStack(spacing: 10) {
                                FieldRow(label: "Title") {
                                    TextField("{{title}}", text: $configuration.titleTemplate)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))
                                }
                                FieldRow(label: "Message") {
                                    TextField("{{message}}", text: $configuration.messageTemplate)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))
                                }

                                DisclosureGroup("Placeholder Reference") {
                                    PlaceholderReference()
                                }
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        } label: {
                            Label("Templates", systemImage: "text.badge.plus")
                                .font(.subheadline.weight(.medium))
                        }
                    }
                }
                .padding(24)
            }

            Divider()

            // Footer buttons
            HStack {
                Button {
                    sendTestNotification()
                } label: {
                    switch testStatus {
                    case .sending:
                        ProgressView()
                            .controlSize(.small)
                    case .success:
                        Label("Sent", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .error:
                        Label("Failed", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    case nil:
                        Label("Test", systemImage: "bell.badge")
                    }
                }
                .disabled(testStatus == .sending || !isValid)
                .help(testStatusHelp)

                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(configuration) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 480, height: 520)
    }

    private var isValid: Bool {
        guard !configuration.displayName.isEmpty else { return false }
        for param in configuration.type.parameterDefinitions where param.isRequired {
            let value = configuration.parameters[param.key] ?? ""
            if value.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        }
        return true
    }

    @ViewBuilder
    private func parameterField(for param: ParameterDefinition) -> some View {
        switch param.fieldType {
        case .columns(let available):
            ColumnsPillField(label: param.label, available: available, value: binding(for: param.key))
        default:
            FieldRow(label: param.label) {
                switch param.fieldType {
                case .text:
                    TextField(param.placeholder, text: binding(for: param.key))
                        .textFieldStyle(.roundedBorder)
                case .secure:
                    SecureField(param.placeholder, text: binding(for: param.key))
                        .textFieldStyle(.roundedBorder)
                case .template:
                    TextField(param.placeholder, text: binding(for: param.key))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                case .filePath:
                    HStack(spacing: 8) {
                        TextField(param.placeholder, text: binding(for: param.key))
                            .textFieldStyle(.roundedBorder)
                        Button("Browse...") {
                            chooseDirectory(for: param.key)
                        }
                        .controlSize(.small)
                    }
                case .picker(let options):
                    Picker("", selection: binding(for: param.key)) {
                        ForEach(options, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                case .columns:
                    EmptyView()
                }
            }
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { configuration.parameters[key] ?? "" },
            set: { configuration.parameters[key] = $0 }
        )
    }

    private func chooseDirectory(for key: String) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            configuration.parameters[key] = url.path
        }
    }

    private var testStatusHelp: String {
        switch testStatus {
        case .error(let msg): return msg
        default: return "Test this service with current settings"
        }
    }

    private func sendTestNotification() {
        guard let service = configuration.createService() else { return }
        testStatus = .sending
        Task {
            let error = await TestNotificationSender.send(to: [service])
            await MainActor.run {
                testStatus = error == nil ? .success : .error(error!)
                autoDismissTestStatus()
            }
        }
    }

    private func autoDismissTestStatus() {
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run { testStatus = nil }
        }
    }
}

// MARK: - Columns Pill Field

struct ColumnsPillField: View {
    let label: String
    let available: [(key: String, label: String)]
    @Binding var value: String

    private var selectedKeys: [String] {
        value.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var unselectedOptions: [(key: String, label: String)] {
        let selected = Set(selectedKeys)
        return available.filter { !selected.contains($0.key) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .frame(width: 80, alignment: .trailing)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Selected pills
            FlowLayout(spacing: 6) {
                ForEach(selectedKeys, id: \.self) { key in
                    let displayLabel = available.first(where: { $0.key == key })?.label ?? key
                    HStack(spacing: 4) {
                        Text(displayLabel)
                            .font(.callout)
                        Button {
                            removeColumn(key)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
                }

                // Add button
                if !unselectedOptions.isEmpty {
                    Menu {
                        ForEach(unselectedOptions, id: \.key) { option in
                            Button(option.label) {
                                addColumn(option.key)
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            .padding(.leading, 84)
        }
    }

    private func addColumn(_ key: String) {
        var keys = selectedKeys
        keys.append(key)
        value = keys.joined(separator: ",")
    }

    private func removeColumn(_ key: String) {
        var keys = selectedKeys
        keys.removeAll { $0 == key }
        value = keys.joined(separator: ",")
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

// MARK: - Helpers

struct FieldRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .frame(width: 80, alignment: .trailing)
                .font(.callout)
                .foregroundStyle(.secondary)
            content
        }
    }
}

struct PlaceholderReference: View {
    private let items: [(String, String)] = [
        ("{{app}}", "Bundle identifier"),
        ("{{appName}}", "Display name"),
        ("{{title}}", "Notification title"),
        ("{{subtitle}}", "Notification subtitle"),
        ("{{body}}", "Body text"),
        ("{{message}}", "Subtitle + body combined"),
        ("{{date}}", "Formatted date/time"),
        ("{{fileDate}}", "Date for filenames (yyyy-MM-dd)"),
        ("{{timestamp}}", "Unix timestamp"),
        ("{{isoDate}}", "ISO 8601 date"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(items, id: \.0) { key, desc in
                HStack(spacing: 8) {
                    Text(key)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.top, 4)
    }
}
