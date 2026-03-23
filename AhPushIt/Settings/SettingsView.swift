import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case filters = "Filters"
    case services = "Services"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .filters: return "line.3.horizontal.decrease.circle"
        case .services: return "paperplane"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 140, ideal: 160, max: 180)
        } detail: {
            Group {
                switch selectedTab {
                case .general:
                    GeneralPane()
                case .filters:
                    FiltersPane()
                case .services:
                    ServicesPane()
                case .about:
                    AboutPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 620, height: 460)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
