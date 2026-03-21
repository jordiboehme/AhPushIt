import Foundation

struct TimeWindow: Identifiable, Codable, Equatable {
    var id = UUID()
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var weekdays: Set<Int> // 1=Sunday, 7=Saturday

    static var allDay: TimeWindow {
        TimeWindow(startHour: 0, startMinute: 0, endHour: 23, endMinute: 59, weekdays: Set(1...7))
    }

    func isActive(at date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        guard weekdays.contains(weekday) else { return false }

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let currentMinutes = hour * 60 + minute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute

        if startMinutes <= endMinutes {
            return currentMinutes >= startMinutes && currentMinutes <= endMinutes
        } else {
            return currentMinutes >= startMinutes || currentMinutes <= endMinutes
        }
    }
}
