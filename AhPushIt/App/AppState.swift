import Foundation
import SwiftUI

@Observable
final class AppState {
    static let shared = AppState()

    var isPaused: Bool = false
    var showFullDiskAccessAlert: Bool = false

    let poller = NotificationPoller()

    func start() {
        guard !isPaused else { return }

        if !SQLiteDatabase.checkAccess() {
            showFullDiskAccessAlert = true
            return
        }

        poller.start()
    }

    func stop() {
        poller.stop()
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused {
            poller.stop()
        } else {
            poller.start()
        }
    }
}
