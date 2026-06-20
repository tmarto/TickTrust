import DeviceActivity
import FamilyControls
import ManagedSettings

/// Runs in the background on the child's device. iOS invokes these callbacks
/// against the schedule/events the app registered via `DeviceActivityCenter`.
///
/// - `eventDidReachThreshold`: the day's allowance for the managed apps was
///   used up → shield (block) them.
/// - `intervalDidStart`: a new day began → lift the shields so the allowance
///   resets.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // New monitoring interval (new day) — clear yesterday's shields.
        clearShield()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        clearShield()
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        guard event == MonitorStore.dailyLimitEvent else { return }
        applyShield()
    }

    // MARK: - Shield helpers

    private func applyShield() {
        let selection = MonitorStore.selection
        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil
            : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
    }

    private func clearShield() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }
}
