import SwiftUI

struct ServicesPane: View {
    @Bindable private var settings = AppSettings.shared
    @State private var editingService: ServiceConfiguration?
    @State private var serviceToDelete: ServiceConfiguration?
    @State private var testStatus: TestStatus?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                SectionHeader(title: "Notification Services", icon: "paperplane")
                Spacer()

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
                .buttonStyle(.borderless)
                .disabled(testStatus == .sending)
                .help(testStatusHelp)

                Menu {
                    ForEach(ServiceType.allCases, id: \.self) { type in
                        Button {
                            let config = ServiceConfiguration.defaultConfiguration(for: type)
                            editingService = config
                        } label: {
                            Label(type.displayName, systemImage: type.icon)
                        }
                    }
                } label: {
                    Label("Add Service", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            if settings.serviceConfigurations.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "paperplane.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.quaternary)
                    Text("No services configured")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Add a service to start forwarding notifications.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(settings.serviceConfigurations) { config in
                            if let idx = settings.serviceConfigurations.firstIndex(where: { $0.id == config.id }) {
                                ServiceCard(
                                    config: $settings.serviceConfigurations[idx],
                                    onEdit: { editingService = config },
                                    onDelete: { serviceToDelete = config }
                                )
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .sheet(item: $editingService) { service in
            ServiceEditorView(configuration: service) { updated in
                if let idx = settings.serviceConfigurations.firstIndex(where: { $0.id == updated.id }) {
                    settings.serviceConfigurations[idx] = updated
                } else {
                    settings.serviceConfigurations.append(updated)
                }
                editingService = nil
            } onCancel: {
                editingService = nil
            }
        }
        .alert("Remove Service", isPresented: Binding(
            get: { serviceToDelete != nil },
            set: { if !$0 { serviceToDelete = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let svc = serviceToDelete {
                    withAnimation {
                        settings.serviceConfigurations.removeAll { $0.id == svc.id }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove \"\(serviceToDelete?.displayName ?? "")\"? This cannot be undone.")
        }
    }

    private var testStatusHelp: String {
        switch testStatus {
        case .error(let msg): return msg
        default: return "Send a test notification to all enabled services"
        }
    }

    private func sendTestNotification() {
        let services = settings.serviceConfigurations
            .filter(\.isEnabled)
            .compactMap { $0.createService() }
        guard !services.isEmpty else {
            testStatus = .error("No enabled services")
            autoDismissTestStatus()
            return
        }
        testStatus = .sending
        Task {
            let error = await TestNotificationSender.send(to: services)
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

// MARK: - Service Card

struct ServiceCard: View {
    @Binding var config: ServiceConfiguration
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        GroupBox {
            HStack(spacing: 12) {
                // Type icon + status
                ZStack {
                    Image(systemName: config.type.icon)
                        .font(.callout)
                        .foregroundStyle(config.isEnabled ? .primary : .secondary)
                }
                .frame(width: 20)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(config.displayName)
                        .font(.callout.weight(.medium))
                    Text(config.summaryDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Controls
                if isHovering {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }

                Button(action: onEdit) {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Edit service")

                Toggle("", isOn: $config.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            }
            .padding(.vertical, 4)
        }
        .onHover { isHovering = $0 }
    }
}
