import FamilyControls
import SwiftUI

/// Run on the *child's* device: the parent authorizes Screen Time, picks the
/// apps/categories to manage, and can block them immediately. Daily time limits
/// (via a DeviceActivityMonitor extension) build on this in the next milestone.
struct ChildDeviceSetupView: View {
    @StateObject private var agent = ScreenTimeAgent.shared
    @State private var pickerPresented = false
    @State private var working = false

    var body: some View {
        Form {
            Section {
                if agent.isAuthorized {
                    Label("Screen Time authorized", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        working = true
                        Task {
                            _ = await agent.requestAuthorization()
                            working = false
                        }
                    } label: {
                        Label("Authorize Screen Time", systemImage: "lock.shield")
                    }
                    .disabled(working)
                }
            } header: {
                Text("Step 1 — Access")
            } footer: {
                Text("On the child's device, authorize TickTrust to manage Screen Time. Requires this device to be set up as a child in Family Sharing.")
            }

            Section {
                Button {
                    pickerPresented = true
                } label: {
                    Label("Choose apps & categories…", systemImage: "square.grid.2x2")
                }
                .disabled(!agent.isAuthorized)

                Text("\(agent.selection.applicationTokens.count) apps · \(agent.selection.categoryTokens.count) categories selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Step 2 — Managed apps")
            }

            Section {
                Button {
                    agent.applyShield()
                } label: {
                    Label("Block selected now", systemImage: "hand.raised.fill")
                }
                .disabled(!agent.isAuthorized || !agent.hasSelection)

                Button(role: .destructive) {
                    agent.clearShield()
                } label: {
                    Label("Unblock all", systemImage: "hand.thumbsup")
                }
                .disabled(!agent.isAuthorized)
            } header: {
                Text("Step 3 — Enforce")
            } footer: {
                Text("Immediate block is for testing. Daily time limits arrive with the monitoring extension.")
            }
        }
        .navigationTitle("Child Device Setup")
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(
            isPresented: $pickerPresented,
            selection: Binding(
                get: { agent.selection },
                set: { agent.updateSelection($0) }
            )
        )
        .task { agent.refreshAuthorization() }
    }
}
