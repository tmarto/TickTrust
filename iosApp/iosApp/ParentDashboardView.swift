import SwiftUI

struct ChildRow: Identifiable {
    let id: String
    let name: String
    let deviceCount: Int
}

struct ParentDashboardView: View {
    let children: [ChildRow] = [
        ChildRow(id: "c1", name: "Ines", deviceCount: 1),
        ChildRow(id: "c2", name: "Pedro", deviceCount: 1),
    ]

    var body: some View {
        List(children) { child in
            NavigationLink(destination: ChildDetailView(childName: child.name)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(child.name)
                        .font(.headline)
                    Text("\(child.deviceCount) device(s)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("ZeitBank")
    }
}
