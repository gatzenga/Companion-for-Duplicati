import SwiftUI

@main
struct Companion_for_DuplicatiApp: App {
    @State private var store = BackupStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
