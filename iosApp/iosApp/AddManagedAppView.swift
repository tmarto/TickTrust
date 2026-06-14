import SwiftUI

struct AddManagedAppView: View {
    let deviceId: String
    @EnvironmentObject var supabase: SupabaseService
    @State private var appName = ""
    @State private var bundleId = ""
    @State private var dailyMinutes = 60
    @State private var isSaving = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var canSave: Bool {
        !appName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !bundleId.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isSaving
    }

    var body: some View {
        Form {
            Section("App Info") {
                TextField("App Name (e.g. Minecraft)", text: $appName)
                    .autocorrectionDisabled()
                TextField("Bundle ID (e.g. com.mojang.minecraftpe)", text: $bundleId)
                    .autocorrectionDisabled()
                    .autocapitalization(.none)
                    .keyboardType(.asciiCapable)
            }
            Section {
                Stepper("**\(dailyMinutes)** min/day", value: $dailyMinutes, in: 5...480, step: 5)
            } header: {
                Text("Daily Limit")
            } footer: {
                Text("The macOS agent hard-kills the app when this limit is reached.")
            }
        }
        .navigationTitle("Add App")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { Task { await save() } }
                    .disabled(!canSave)
            }
        }
        .overlay {
            if isSaving { ProgressView() }
        }
        .alert("Error", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await supabase.createManagedApp(
                deviceId: deviceId,
                bundleId: bundleId.trimmingCharacters(in: .whitespaces),
                appName: appName.trimmingCharacters(in: .whitespaces),
                dailyMinutes: dailyMinutes
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
