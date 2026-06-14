import SwiftUI

struct ChildDetailView: View {
    let child: Child
    @EnvironmentObject var supabase: SupabaseService
    @State private var devices: [Device] = []
    @State private var isLoading = false
    @State private var showAddDevice = false
    @State private var error: String?

    var body: some View {
        List {
            if devices.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Devices",
                    systemImage: "laptopcomputer.and.iphone",
                    description: Text("Tap + to add a device for \(child.name).")
                )
            }
            Section("Devices") {
                ForEach(devices) { device in
                    NavigationLink(destination: DeviceAppsView(device: device, childId: child.id)) {
                        DeviceRowView(device: device)
                    }
                }
                .onDelete { offsets in
                    Task { await deleteDevices(at: offsets) }
                }
            }
        }
        .navigationTitle(child.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddDevice = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddDevice, onDismiss: { Task { await load() } }) {
            AddDeviceView(child: child) { _ in }
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
        isLoading = true
        defer { isLoading = false }
        do {
            devices = try await supabase.fetchDevices(childId: child.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deleteDevices(at offsets: IndexSet) async {
        for i in offsets {
            do { try await supabase.deleteDevice(deviceId: devices[i].id) }
            catch { self.error = error.localizedDescription; return }
        }
        devices.remove(atOffsets: offsets)
    }
}

struct DeviceRowView: View {
    let device: Device
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.type.systemImage)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(.body)
                Text(device.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
