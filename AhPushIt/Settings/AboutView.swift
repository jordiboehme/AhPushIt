import ServiceManagement
import SwiftUI

struct AboutPane: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "About", icon: "info.circle")

            ScrollView {
                VStack(spacing: 20) {
                    // App icon, name, version
                    VStack(spacing: 8) {
                        if let icon = NSApp.applicationIconImage {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        }

                        Text("AhPushIt")
                            .font(.title2)
                            .fontWeight(.semibold)

                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                            Text("Version \(version) (\(build))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Text("macOS notification forwarder")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    Divider()
                        .padding(.horizontal, 20)

                    // Launch at Login
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                launchAtLogin = SMAppService.mainApp.status == .enabled
                            }
                        }
                        .padding(.horizontal, 20)

                    Divider()
                        .padding(.horizontal, 20)

                    // Links
                    HStack(spacing: 12) {
                        LinkButton(title: "GitHub", icon: "chevron.left.forwardslash.chevron.right",
                                   url: "https://github.com/jordiboehme/AhPushIt")
                        LinkButton(title: "Report Issue", icon: "exclamationmark.bubble",
                                   url: "https://github.com/jordiboehme/AhPushIt/issues")
                        LinkButton(title: "Ko-fi", icon: "heart",
                                   url: "https://ko-fi.com/V7V31T6CL9")
                    }

                    Divider()
                        .padding(.horizontal, 20)

                    Text("MIT License")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
    }
}

private struct LinkButton: View {
    let title: String
    let icon: String
    let url: String

    var body: some View {
        Button {
            if let link = URL(string: url) {
                NSWorkspace.shared.open(link)
            }
        } label: {
            Label(title, systemImage: icon)
        }
    }
}
