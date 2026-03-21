import SwiftUI

struct GeneralPane: View {
    @Bindable private var settings = AppSettings.shared

    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols // ["Sun","Mon",...]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Polling
                SectionHeader(title: "Polling", icon: "arrow.triangle.2.circlepath")

                GroupBox {
                    HStack {
                        Text("Check for new notifications every")
                        TextField("", value: Bindable(settings).pollInterval, format: .number)
                            .frame(width: 44)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                        Text("seconds")
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }

                // MARK: - Schedule
                SectionHeader(title: "Schedule", icon: "clock")

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Only forward during scheduled windows", isOn: $settings.scheduleEnabled)

                        if settings.scheduleEnabled {
                            Divider()

                            if settings.timeWindows.isEmpty {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(.secondary)
                                    Text("No windows configured — notifications are always forwarded.")
                                        .foregroundStyle(.secondary)
                                        .font(.callout)
                                }
                                .padding(.vertical, 4)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(settings.timeWindows) { window in
                                        TimeWindowRow(
                                            window: binding(for: window),
                                            weekdaySymbols: weekdaySymbols,
                                            onDelete: {
                                                withAnimation {
                                                    settings.timeWindows.removeAll { $0.id == window.id }
                                                }
                                            }
                                        )
                                    }
                                }
                            }

                            Button {
                                withAnimation {
                                    settings.timeWindows.append(
                                        TimeWindow(startHour: 9, startMinute: 0,
                                                   endHour: 17, endMinute: 0,
                                                   weekdays: Set(2...6))
                                    )
                                }
                            } label: {
                                Label("Add Window", systemImage: "plus")
                            }
                            .buttonStyle(.borderless)
                            .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(20)
        }
    }

    private func binding(for window: TimeWindow) -> Binding<TimeWindow> {
        Binding(
            get: { settings.timeWindows.first { $0.id == window.id } ?? window },
            set: { newValue in
                if let idx = settings.timeWindows.firstIndex(where: { $0.id == window.id }) {
                    settings.timeWindows[idx] = newValue
                }
            }
        )
    }
}

// MARK: - Time Window Row (inline editing)

struct TimeWindowRow: View {
    @Binding var window: TimeWindow
    let weekdaySymbols: [String]
    var onDelete: () -> Void

    private var startDate: Binding<Date> {
        Binding {
            Calendar.current.date(from: DateComponents(hour: window.startHour, minute: window.startMinute)) ?? Date()
        } set: { d in
            window.startHour = Calendar.current.component(.hour, from: d)
            window.startMinute = Calendar.current.component(.minute, from: d)
        }
    }

    private var endDate: Binding<Date> {
        Binding {
            Calendar.current.date(from: DateComponents(hour: window.endHour, minute: window.endMinute)) ?? Date()
        } set: { d in
            window.endHour = Calendar.current.component(.hour, from: d)
            window.endMinute = Calendar.current.component(.minute, from: d)
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                DatePicker("", selection: startDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(width: 80)
                Text("to")
                    .foregroundStyle(.secondary)
                DatePicker("", selection: endDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(width: 80)

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove window")
            }

            HStack(spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { offset, name in
                    let day = offset + 1 // 1=Sun
                    let isOn = window.weekdays.contains(day)
                    Button {
                        if isOn { window.weekdays.remove(day) }
                        else { window.weekdays.insert(day) }
                    } label: {
                        Text(String(name.prefix(2)))
                            .font(.caption.weight(.medium))
                            .frame(width: 28, height: 22)
                            .background(isOn ? Color.accentColor : Color.clear)
                            .foregroundStyle(isOn ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(isOn ? Color.clear : Color.secondary.opacity(0.3))
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Shared Components

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}
