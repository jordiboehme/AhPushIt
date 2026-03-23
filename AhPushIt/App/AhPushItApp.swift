import SwiftUI

@main
struct AhPushItApp: App {
    @State private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            Image(systemName: appState.isPaused ? "bell.slash" : "bell.badge")
        }

        Settings {
            SettingsView()
        }
    }

    init() {
        AppState.shared.start()
    }
}

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @State private var showingPermissionAlert = false

    var body: some View {
        VStack {
            if appState.showFullDiskAccessAlert {
                Button("Full Disk Access Required") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .foregroundStyle(.red)
                Divider()
            } else if let error = appState.poller.lastError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                Divider()
            }

            statusLine

            Divider()

            Button(appState.isPaused ? "Resume Forwarding" : "Pause Forwarding") {
                appState.togglePause()
            }

            SettingsLink {
                Text("Settings...")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .onAppear {
            showingPermissionAlert = appState.showFullDiskAccessAlert
        }
        .onChange(of: appState.showFullDiskAccessAlert) { _, newValue in
            showingPermissionAlert = newValue
        }
        .alert("Full Disk Access Required", isPresented: $showingPermissionAlert) {
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Quit", role: .cancel) {
                NSApplication.shared.terminate(nil)
            }
        } message: {
            Text("AhPushIt needs Full Disk Access to read the macOS Notification Center database.\n\nGo to System Settings > Privacy & Security > Full Disk Access and enable AhPushIt. The app will automatically start when you return.")
        }
    }

    private var statusLine: some View {
        Group {
            if appState.isPaused {
                Text("Paused")
                    .foregroundStyle(.secondary)
            } else if appState.showFullDiskAccessAlert {
                Text("No database access")
                    .foregroundStyle(.red)
            } else {
                let count = appState.poller.forwardedCount
                if let lastTime = appState.poller.lastForwardedTime {
                    Text("\(count) forwarded \u{2014} last \(lastTime, style: .relative) ago")
                } else {
                    Text("\(count) forwarded")
                }
            }
        }
        .font(.caption)
        .padding(.horizontal, 8)
    }

}
