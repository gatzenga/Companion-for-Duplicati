import SwiftUI

struct EmptyStateView: View {
    @Environment(BackupStore.self) private var store
    @AppStorage("appLanguage") private var lang = "en"

    var body: some View {
        ContentUnavailableView {
            Label(tr("Welcome", "Willkommen", lang),
                  systemImage: "externaldrive.connected.to.line.below")
        } description: {
            Text(tr(
                "Connect to your Duplicati server in Settings.",
                "Verbinde dich in den Einstellungen mit deinem Duplicati-Server.",
                lang
            ))
        } actions: {
            Button(tr("Open Settings", "Einstellungen öffnen", lang)) {
                store.selectedTab = .settings
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
