import SwiftUI

struct AddChildView: View {
    @EnvironmentObject var supabase: SupabaseService
    @State private var name = ""
    @State private var isSaving = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Child's Name") {
                    TextField("e.g. Ines", text: $name)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Add Child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await save() } }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .overlay {
                if isSaving { ProgressView() }
            }
        }
        .alert("Error", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private func save() async {
        guard let parentId = supabase.currentParentId else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await supabase.createChild(parentId: parentId, name: name.trimmingCharacters(in: .whitespaces))
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
