import SwiftUI

struct EditAppView: View {
    let app: ManagedApp
    let onSave: (ManagedApp) -> Void
    @EnvironmentObject var supabase: SupabaseService
    @State private var dailyMinutes: Int
    @State private var enabled: Bool
    @State private var isSaving = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    init(app: ManagedApp, onSave: @escaping (ManagedApp) -> Void) {
        self.app = app
        self.onSave = onSave
        _dailyMinutes = State(initialValue: app.dailyMinutes)
        _enabled = State(initialValue: app.enabled)
    }

    var body: some View {
        Form {
            Section("App") {
                LabeledContent("Name", value: app.appName)
                LabeledContent("Bundle ID", value: app.bundleId)
            }
            Section("Daily Limit") {
                Stepper("**\(dailyMinutes)** min/day", value: $dailyMinutes, in: 5...480, step: 5)
            }
            Section("Status") {
                Toggle("Enabled", isOn: $enabled)
            }
        }
        .navigationTitle("Edit App")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(isSaving)
            }
        }
        .alert("Error", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await supabase.updateManagedApp(appId: app.id, dailyMinutes: dailyMinutes, enabled: enabled)
            var updated = app
            updated.dailyMinutes = dailyMinutes
            updated.enabled = enabled
            onSave(updated)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
