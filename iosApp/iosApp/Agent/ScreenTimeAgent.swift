import Foundation
import FamilyControls
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

    private let store = ManagedSettingsStore()
    private let defaults = UserDefaults(suiteName: ScreenTimeAgent.appGroup) ?? .standard
    private let selectionKey = "familyActivitySelection"

    private init() {
        refreshAuthorization()
        loadSelection()
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
        if let data = try? JSONEncoder().encode(selection) {
            defaults.set(data, forKey: selectionKey)
        }
    }

    private func loadSelection() {
        guard
            let data = defaults.data(forKey: selectionKey),
            let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }
        selection = saved
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
