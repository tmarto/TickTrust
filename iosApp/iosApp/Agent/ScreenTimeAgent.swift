import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// On-device (child) agent built on Apple's Screen Time APIs.
///
/// Phase 3 foundation: requests Family Controls authorization, lets the parent
/// pick which apps/categories to manage (a `FamilyActivitySelection`), persists
/// that selection in the shared App Group so a future `DeviceActivityMonitor`
/// extension can read it, and can immediately shield/unshield the selection via
/// `ManagedSettings`.
///
/// Time-based daily limits (the core product) will be layered on next via a
/// `DeviceActivityMonitor` extension that flips these shields when a threshold
/// is reached. This type intentionally owns the selection + shield plumbing so
/// the extension can reuse it.
@MainActor
final class ScreenTimeAgent: ObservableObject {
    static let shared = ScreenTimeAgent()

    /// App Group shared between the app and the (future) monitor extension.
    static let appGroup = "group.com.ticktrust.siwa"

    @Published private(set) var isAuthorized = false
    @Published private(set) var selection = FamilyActivitySelection()
    @Published private(set) var isMonitoring = false

    private let store = ManagedSettingsStore()
    private let center = DeviceActivityCenter()

    private init() {
        refreshAuthorization()
        loadSelection()
        isMonitoring = MonitorStore.isMonitoring
    }

    // MARK: - Authorization

    func refreshAuthorization() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    /// Prompts for Family Controls authorization for a child on this device.
    /// Requires the device to be signed into a managed/child Apple ID (or, in
    /// development, any account) and the `family-controls` entitlement.
    func requestAuthorization() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .child)
            refreshAuthorization()
        } catch {
            isAuthorized = false
        }
        return isAuthorized
    }

    // MARK: - Selection (apps & categories)

    func updateSelection(_ newValue: FamilyActivitySelection) {
        selection = newValue
        persistSelection()
    }

    private func persistSelection() {
        // Shared with the monitor extension via the App Group.
        MonitorStore.selection = selection
    }

    private func loadSelection() {
        selection = MonitorStore.selection
    }

    // MARK: - Daily limit monitoring

    /// Schedules a daily allowance for the selected apps. When usage reaches
    /// `dailyLimitMinutes`, the monitor extension shields them; at the start of
    /// each day the interval resets and shields lift.
    func startMonitoring(dailyLimitMinutes: Int) {
        persistSelection()
        MonitorStore.dailyLimitMinutes = dailyLimitMinutes

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            threshold: DateComponents(minute: dailyLimitMinutes)
        )

        do {
            center.stopMonitoring([MonitorStore.activityName])
            try center.startMonitoring(
                MonitorStore.activityName,
                during: schedule,
                events: [MonitorStore.dailyLimitEvent: event]
            )
            setMonitoring(true)
        } catch {
            setMonitoring(false)
        }
    }

    func stopMonitoring() {
        center.stopMonitoring([MonitorStore.activityName])
        clearShield()
        setMonitoring(false)
    }

    private func setMonitoring(_ value: Bool) {
        isMonitoring = value
        MonitorStore.isMonitoring = value
    }

    // MARK: - Shielding

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
    }

    /// Immediately blocks the selected apps and categories.
    func applyShield() {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
    }

    /// Removes all shields managed by this app.
    func clearShield() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }
}
