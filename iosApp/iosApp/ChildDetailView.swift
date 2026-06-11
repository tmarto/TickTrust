import SwiftUI

struct AppLimitRow: Identifiable {
    let id: String
    let appName: String
    let dailyMinutes: Int
    var enabled: Bool
}

struct ChildDetailView: View {
    let childName: String

    @State private var appLimits: [AppLimitRow] = [
        AppLimitRow(id: "a1", appName: "Minecraft", dailyMinutes: 60, enabled: true),
        AppLimitRow(id: "a2", appName: "Roblox", dailyMinutes: 45, enabled: true),
    ]
    @State private var bonusGranted = false

    var body: some View {
        List {
            Section("App Limits") {
                ForEach($appLimits) { $limit in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(limit.appName).font(.body)
                            Text("\(limit.dailyMinutes) min/day")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $limit.enabled).labelsHidden()
                    }
                }
            }

            Section("Rewards") {
                Button {
                    bonusGranted = true
                } label: {
                    Label("Grant +15 min bonus", systemImage: "gift")
                }
            }
        }
        .navigationTitle(childName)
        .alert("Bonus Granted!", isPresented: $bonusGranted) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("+15 minutes added to \(childName)'s account.")
        }
    }
}
