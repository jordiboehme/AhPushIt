import Foundation

struct AppNotification: Identifiable {
    let id: Int64
    let bundleIdentifier: String
    var appName: String
    let title: String
    let subtitle: String
    let body: String
    let date: Date

    var message: String {
        if !subtitle.isEmpty {
            return "\(subtitle)\u{2014}\(body)"
        }
        return body
    }

    static var test: AppNotification {
        AppNotification(
            id: 0,
            bundleIdentifier: "com.jordiboehme.AhPushIt",
            appName: "AhPushIt",
            title: "\u{1F3B6} Ah, Push It!",
            subtitle: "Salt-N-Pepa \u{00D7} AhPushIt \u{1F9C2}\u{1F336}\u{FE0F}",
            body: "Ooh, baby, baby! \u{1F3A4} This is a test notification \u{2014} push it real good!\nSpecial chars: \u{00E4}\u{00F6}\u{00FC} & \"quotes\" <angle> \u{2018}apostrophes\u{2019} \u{1F4A5}\u{1F680}",
            date: Date()
        )
    }
}
