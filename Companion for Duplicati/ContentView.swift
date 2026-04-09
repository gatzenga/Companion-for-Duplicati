import SwiftUI

struct ContentView: View {
    @Environment(BackupStore.self) private var store
    @Environment(\.appLanguage) private var appLanguage

    var body: some View {
        @Bindable var store = store

        TabView(selection: $store.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(AppTab.home)

            NotificationsView()
                .tabItem {
                    Label(
                        tr("Notifications", "Benachrichtigungen", appLanguage),
                        systemImage: "bell.fill"
                    )
                }
                .badge(store.notificationBadgeCount)
                .tag(AppTab.notifications)

            SettingsView()
                .tabItem {
                    Label(
                        tr("Settings", "Einstellungen", appLanguage),
                        systemImage: "gearshape"
                    )
                }
                .tag(AppTab.settings)
        }
    }
}
