import Foundation
import SwiftUI

@Observable
final class AppState {
    static let shared = AppState()

    var isPaused: Bool = false
    var showFullDiskAccessAlert: Bool = false

    let poller = NotificationPoller()

    private var activationObserver: NSObjectProtocol?

    func start() {
        guard !isPaused else { return }

        if !SQLiteDatabase.checkAccess() {
            showFullDiskAccessAlert = true
            startObservingActivation()
            return
        }

        showFullDiskAccessAlert = false
        stopObservingActivation()
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

    private func startObservingActivation() {
        guard activationObserver == nil else { return }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.showFullDiskAccessAlert else { return }
            if SQLiteDatabase.checkAccess() {
                self.showFullDiskAccessAlert = false
                self.stopObservingActivation()
                self.poller.start()
            }
        }
    }

    private func stopObservingActivation() {
        if let observer = activationObserver {
            NotificationCenter.default.removeObserver(observer)
            activationObserver = nil
        }
    }
}
