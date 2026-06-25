import FamilyControls
import SwiftUI

/// Run on the *child's* device: the parent authorizes Screen Time, picks the
/// apps/categories to manage, and can block them immediately. Daily time limits
/// (via a DeviceActivityMonitor extension) build on this in the next milestone.
struct ChildDeviceSetupView: View {
    @StateObject private var agent = ScreenTimeAgent.shared
    @State private var pickerPresented = false
    @State private var working = false
    @State private var dailyLimitMinutes = 60

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
                Stepper(value: $dailyLimitMinutes, in: 5...600, step: 5) {
                    Text("Daily limit: \(dailyLimitMinutes) min")
                }

                if agent.isMonitoring {
                    Label("Daily limit active", systemImage: "timer")
                        .foregroundStyle(.green)
                    Button(role: .destructive) {
                        agent.stopMonitoring()
                    } label: {
                        Label("Stop daily limit", systemImage: "stop.circle")
                    }
                } else {
                    Button {
                        agent.startMonitoring(dailyLimitMinutes: dailyLimitMinutes)
                    } label: {
                        Label("Start daily limit", systemImage: "timer")
                    }
                    .disabled(!agent.isAuthorized || !agent.hasSelection)
                }
            } header: {
                Text("Step 3 — Daily limit")
            } footer: {
                Text("When the selected apps reach the daily limit they're blocked until the next day. Limit resets each day at midnight.")
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
                Text("Manual override (testing)")
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
