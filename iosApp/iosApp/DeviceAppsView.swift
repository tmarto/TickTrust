import SwiftUI

struct DeviceAppsView: View {
    let device: Device
    let childId: String
    @EnvironmentObject var supabase: SupabaseService
    @State private var apps: [ManagedApp] = []
    @State private var isLoading = false
    @State private var showAddApp = false
    @State private var showBonus = false
    @State private var bonusMinutes = 15
    @State private var error: String?

    var body: some View {
        List {
            Section("Managed Apps") {
                if apps.isEmpty && !isLoading {
                    Text("No apps yet — tap + to add one.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                ForEach(apps) { app in
                    NavigationLink(destination: EditAppView(app: app, onSave: { updated in
                        if let i = apps.firstIndex(where: { $0.id == updated.id }) {
                            apps[i] = updated
                        }
                    })) {
                        AppRowView(app: app)
                    }
                }
                .onDelete { offsets in
                    Task { await deleteApps(at: offsets) }
                }
            }

            Section("Bonus Time") {
                Button {
                    showBonus = true
                } label: {
                    Label("Grant Bonus Time", systemImage: "gift")
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle(device.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddApp = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddApp, onDismiss: { Task { await load() } }) {
            NavigationStack {
                AddManagedAppView(deviceId: device.id)
                    .environmentObject(supabase)
            }
        }
        .alert("Grant Bonus Time", isPresented: $showBonus) {
            TextField("Minutes", value: $bonusMinutes, format: .number)
                .keyboardType(.numberPad)
            Button("Grant") { Task { await grantBonus() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Extra minutes for all apps on \(device.name) today.")
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
        isLoading = true
        defer { isLoading = false }
        do { apps = try await supabase.fetchManagedApps(deviceId: device.id) }
        catch { self.error = error.localizedDescription }
    }

    private func deleteApps(at offsets: IndexSet) async {
        for i in offsets {
            do { try await supabase.deleteManagedApp(appId: apps[i].id) }
            catch { self.error = error.localizedDescription; return }
        }
        apps.remove(atOffsets: offsets)
    }

    private func grantBonus() async {
        guard let parentId = supabase.currentParentId else { return }
        do {
            try await supabase.grantBonus(childId: childId, parentId: parentId, minutes: bonusMinutes)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct AppRowView: View {
    let app: ManagedApp
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(app.appName).font(.body)
                Text(app.bundleId)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(app.dailyMinutes) min/day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Circle()
                    .fill(app.enabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 2)
    }
}
