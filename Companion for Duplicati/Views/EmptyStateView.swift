import SwiftUI

struct EmptyStateView: View {
    @Environment(BackupStore.self) private var store

    var body: some View {
        ContentUnavailableView {
            Label("Willkommen", systemImage: "externaldrive.connected.to.line.below")
        } description: {
            Text("Verbinde dich in den Einstellungen mit deinem Duplicati-Server.")
        } actions: {
            Button("Einstellungen öffnen") {
                store.selectedTab = .settings
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
