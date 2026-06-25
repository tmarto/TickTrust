import DeviceActivity
import FamilyControls
import Foundation

/// Data shared between the main app and the DeviceActivityMonitor extension via
/// the App Group. The app writes the selection + daily limit; the extension
/// reads them when a threshold is reached so it knows what to shield.
///
/// This file is a member of BOTH the app target and the monitor extension target.
enum MonitorStore {
    static let appGroup = "group.com.ticktrust.siwa"

    /// Shared activity + event names so the app (scheduler) and extension agree.
    static let activityName = DeviceActivityName("ticktrust.daily")
    static let dailyLimitEvent = DeviceActivityEvent.Name("ticktrust.dailyLimit")

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    /// Apps & categories the parent chose to manage on this device.
    static var selection: FamilyActivitySelection {
        get {
            guard
                let data = defaults.data(forKey: "selection"),
                let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            else { return FamilyActivitySelection() }
            return decoded
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "selection") }
    }

    /// Combined daily allowance (minutes) for the selected apps. 0 = no limit.
    static var dailyLimitMinutes: Int {
        get { defaults.integer(forKey: "dailyLimitMinutes") }
        set { defaults.set(newValue, forKey: "dailyLimitMinutes") }
    }

    /// Whether monitoring is currently scheduled (UI hint).
    static var isMonitoring: Bool {
        get { defaults.bool(forKey: "isMonitoring") }
        set { defaults.set(newValue, forKey: "isMonitoring") }
    }
}
