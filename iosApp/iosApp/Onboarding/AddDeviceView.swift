import SwiftUI

struct AddDeviceView: View {
    let child: Child
    let onComplete: (Device) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AddDeviceViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Device name") {
                    TextField("e.g. Pedro's MacBook", text: $vm.deviceName)
                        .autocorrectionDisabled()
                }

                Section("Device type") {
                    ForEach(DeviceType.allCases) { type in
                        DeviceTypeRow(type: type, selected: vm.selectedType == type) {
                            vm.selectedType = type
                        }
                    }
                }
            }
            .navigationTitle("Add Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await vm.createDevice(child: child, onComplete: onComplete) }
                    }
                    .disabled(vm.deviceName.trimmingCharacters(in: .whitespaces).isEmpty || vm.isLoading)
                }
            }
            .overlay {
                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .alert("Error", isPresented: $vm.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage)
            }
            // Navigate to install instructions once device created
            .navigationDestination(item: $vm.createdDevice) { device in
                DeviceInstallView(device: device, child: child) {
                    onComplete(device)
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Row

private struct DeviceTypeRow: View {
    let type: DeviceType
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: type.systemImage)
                    .font(.title2)
                    .frame(width: 32)
                    .foregroundStyle(selected ? .blue : .secondary)
                Text(type.displayName)
                    .foregroundStyle(.primary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
final class AddDeviceViewModel: ObservableObject {
    @Published var deviceName     = ""
    @Published var selectedType   = DeviceType.mac
    @Published var isLoading      = false
    @Published var showError      = false
    @Published var errorMessage   = ""
    @Published var createdDevice: Device?

    func createDevice(child: Child, onComplete: (Device) -> Void) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let device = try await SupabaseService.shared.createDevice(
                childId: child.id,
                name: deviceName.trimmingCharacters(in: .whitespaces),
                type: selectedType
            )
            createdDevice = device
        } catch {
            errorMessage = error.localizedDescription
            showError    = true
        }
    }
}
