import SwiftUI

/// Shown immediately after a device is created.
/// Gives parent step-by-step install instructions for the device type.
struct DeviceInstallView: View {
    let device: Device
    let child: Child
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: device.type.systemImage)
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name).font(.title2).fontWeight(.semibold)
                        Text(child.name).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                switch device.type {
                case .mac:
                    MacInstallInstructions(device: device)
                case .iphone, .ipad:
                    iOSInstallInstructions(device: device)
                }

                Button(action: onDone) {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
        .navigationTitle("Install TickTrust")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
    }
}

// MARK: - macOS instructions

private struct MacInstallInstructions: View {
    let device: Device
    @State private var copied = false

    private var command: String {
        SupabaseService.shared.macInstallCommand(deviceId: device.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepCard(number: 1, title: "Open Terminal on \(device.name)") {
                Text("Press **⌘ Space**, type **Terminal**, press Enter.")
            }

            StepCard(number: 2, title: "Run the install command") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Copy and paste this into Terminal:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(command)
                        .font(.system(.caption, design: .monospaced))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))

                    Button {
                        UIPasteboard.general.string = command
                        copied = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            copied = false
                        }
                    } label: {
                        Label(copied ? "Copied!" : "Copy Command",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(copied ? .green : .blue)
                }
            }

            StepCard(number: 3, title: "Enter your admin password") {
                Text("macOS will ask for your password — this is your Mac login password. The agent installs silently and starts immediately.")
            }

            StepCard(number: 4, title: "Add managed apps") {
                Text("Go back to \(device.name)'s device in TickTrust and add the apps you want to limit.")
            }

            InfoBox(
                icon: "checkmark.shield.fill",
                color: .green,
                message: "Once installed, \(device.name) cannot remove the agent. It restarts automatically after reboots."
            )
        }
    }
}

// MARK: - iOS instructions

private struct iOSInstallInstructions: View {
    let device: Device

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            InfoBox(
                icon: "hammer.fill",
                color: .orange,
                message: "iOS agent coming in the next release. Device registered — you can add app limits now."
            )

            StepCard(number: 1, title: "Device registered") {
                Text("Device ID: **\(device.id)**")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            StepCard(number: 2, title: "MDM profile") {
                Text("Ensure this device has the TickTrust supervision profile installed via Apple Configurator.")
            }

            StepCard(number: 3, title: "iOS agent") {
                Text("Install instructions will appear here once the iOS agent is released.")
            }
        }
    }
}

// MARK: - Reusable components

private struct StepCard<Content: View>: View {
    let number: Int
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("\(number)")
                    .font(.caption).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(.blue, in: Circle())
                Text(title).font(.headline)
            }
            content
                .font(.subheadline)
                .padding(.leading, 32)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct InfoBox: View {
    let icon: String
    let color: Color
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            Text(message)
                .font(.subheadline)
        }
        .padding()
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}
