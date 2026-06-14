import SwiftUI

struct ParentDashboardView: View {
    @EnvironmentObject var supabase: SupabaseService
    @State private var children: [Child] = []
    @State private var isLoading = false
    @State private var showAddChild = false
    @State private var error: String?

    var body: some View {
        List {
            if children.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Children Yet",
                    systemImage: "person.2",
                    description: Text("Tap + to add your first child.")
                )
            }
            ForEach(children) { child in
                NavigationLink(destination: ChildDetailView(child: child)) {
                    Label(child.name, systemImage: "person.fill")
                        .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("TickTrust")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Sign Out") { supabase.signOut() }
                    .foregroundStyle(.red)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddChild = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddChild, onDismiss: { Task { await load() } }) {
            AddChildView()
                .environmentObject(supabase)
        }
        .overlay {
            if isLoading { ProgressView() }
        }
        .alert("Error", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let parentId = supabase.currentParentId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            children = try await supabase.fetchChildren(parentId: parentId)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
