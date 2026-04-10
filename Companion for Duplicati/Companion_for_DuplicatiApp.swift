import SwiftUI

@main
struct Companion_for_DuplicatiApp: App {
    @State private var store = BackupStore()
    @AppStorage("appLanguage") private var appLanguage = "en"
    @AppStorage("timeFormat") private var timeFormat = "24h"
    @AppStorage("isDarkModeEnabled") private var isDarkModeEnabled = false
    @AppStorage("isAppLockEnabled") private var isAppLockEnabled = false
    @Environment(\.scenePhase) private var scenePhase

    @State private var isLocked = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(store)
                    .environment(\.appLanguage, appLanguage)
                    .environment(\.timeFormat, timeFormat)
                    .preferredColorScheme(isDarkModeEnabled ? .dark : .light)

                if isLocked {
                    AppLockView(isLocked: $isLocked)
                }
            }
            .tint(Color(red: 55/255, green: 100/255, blue: 185/255))
            .fullScreenCover(isPresented: $isLocked) {
                AppLockView(isLocked: $isLocked)
            }
            .onAppear {
                isLocked = isAppLockEnabled && AppLockManager.hasPIN()
            }
            .onChange(of: isAppLockEnabled) { _, newValue in
                if !newValue {
                    isLocked = false
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background && isAppLockEnabled && AppLockManager.hasPIN() {
                    isLocked = true
                }
            }
        }
    }
}

// MARK: - Environment Keys

struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: String = "en"
}

struct TimeFormatKey: EnvironmentKey {
    static let defaultValue: String = "24h"
}

extension EnvironmentValues {
    var appLanguage: String {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }

    var timeFormat: String {
        get { self[TimeFormatKey.self] }
        set { self[TimeFormatKey.self] = newValue }
    }
}

// MARK: - Localization

func tr(_ en: String, _ de: String, _ lang: String) -> String {
    lang == "de" ? de : en
}
