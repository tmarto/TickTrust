import AppKit
import Foundation

struct ActiveApp {
    let bundleId: String
    let pid: pid_t
    let name: String
}

protocol AppMonitorDelegate: AnyObject {
    func managedAppBecameActive(_ app: ActiveApp)
    func managedAppBecameInactive(_ bundleId: String)
}

final class AppMonitor {
    weak var delegate: AppMonitorDelegate?

    private var managedBundleIds: Set<String> = []
    private var activeManagedApp: String?
    private let lock = NSLock()

    func updateManagedApps(_ apps: [ManagedApp]) {
        lock.lock()
        managedBundleIds = Set(apps.map(\.bundleId))
        lock.unlock()
    }

    func start() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(appActivated(_:)),
                       name: NSWorkspace.didActivateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(appTerminated(_:)),
                       name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(appHid(_:)),
                       name: NSWorkspace.didHideApplicationNotification, object: nil)

        // Check current frontmost app on start
        if let front = NSWorkspace.shared.frontmostApplication,
           let bid = front.bundleIdentifier {
            checkAndNotify(bundleId: bid, pid: front.processIdentifier,
                           name: front.localizedName ?? bid, active: true)
        }
    }

    // MARK: - Notifications

    @objc private func appActivated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bid = app.bundleIdentifier else { return }

        lock.lock()
        let prevManaged = activeManagedApp
        lock.unlock()

        // Previous managed app lost focus
        if let prev = prevManaged, prev != bid {
            lock.lock(); activeManagedApp = nil; lock.unlock()
            delegate?.managedAppBecameInactive(prev)
        }

        checkAndNotify(bundleId: bid, pid: app.processIdentifier,
                       name: app.localizedName ?? bid, active: true)
    }

    @objc private func appTerminated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bid = app.bundleIdentifier else { return }
        lock.lock()
        let wasActive = activeManagedApp == bid
        if wasActive { activeManagedApp = nil }
        lock.unlock()
        if wasActive { delegate?.managedAppBecameInactive(bid) }
    }

    @objc private func appHid(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bid = app.bundleIdentifier else { return }
        lock.lock()
        let wasActive = activeManagedApp == bid
        if wasActive { activeManagedApp = nil }
        lock.unlock()
        if wasActive { delegate?.managedAppBecameInactive(bid) }
    }

    // MARK: - Private

    private func checkAndNotify(bundleId: String, pid: pid_t, name: String, active: Bool) {
        lock.lock()
        let isManaged = managedBundleIds.contains(bundleId)
        lock.unlock()

        guard isManaged else { return }

        lock.lock(); activeManagedApp = bundleId; lock.unlock()
        delegate?.managedAppBecameActive(ActiveApp(bundleId: bundleId, pid: pid, name: name))
    }
}
