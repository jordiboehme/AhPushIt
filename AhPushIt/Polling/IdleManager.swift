import Cocoa

@Observable
final class IdleManager {
    private(set) var isScreenLocked = false
    private var lockObserver: NSObjectProtocol?
    private var unlockObserver: NSObjectProtocol?

    func start() {
        let dnc = DistributedNotificationCenter.default()
        lockObserver = dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.isScreenLocked = true
        }
        unlockObserver = dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.isScreenLocked = false
        }
    }

    func stop() {
        let dnc = DistributedNotificationCenter.default()
        if let o = lockObserver { dnc.removeObserver(o) }
        if let o = unlockObserver { dnc.removeObserver(o) }
        lockObserver = nil
        unlockObserver = nil
    }

    var idleTimeSeconds: Double {
        CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~0)!)
    }
}
