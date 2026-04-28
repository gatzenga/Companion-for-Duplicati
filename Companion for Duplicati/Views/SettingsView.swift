import SwiftUI

struct SettingsView: View {
    @Environment(BackupStore.self) private var store
    @Environment(\.appLanguage) private var appLanguage
    @AppStorage("appLanguage") private var lang = "en"
    @AppStorage("timeFormat") private var timeFormat = "24h"
    @AppStorage("isDarkModeEnabled") private var isDarkModeEnabled = false
    @AppStorage("isAppLockEnabled") private var isAppLockEnabled = false
    @AppStorage("isBiometricEnabled") private var isBiometricEnabled = false
    @AppStorage("trustSelfSignedCerts") private var trustSelfSignedCerts = false

    @State private var serverURL = ""
    @State private var password = ""
    @State private var showPINSetup = false
    @State private var showDisableConfirm = false

    private let biometric = BiometricService.available

    var body: some View {
        NavigationStack {
            List {
                serverSection
                generalSection
                appearanceSection
                appLockSection
                linksSection
                infoSection
            }
            .navigationTitle(tr("Settings", "Einstellungen", lang))
        }
        .sheet(isPresented: $showPINSetup) {
            PINSetupView(isChanging: AppLockManager.hasPIN()) {
                isAppLockEnabled = true
                showPINSetup = false
            } onCancel: {
                showPINSetup = false
            }
        }
        .alert(
            tr("Disable App Lock?", "Code-Sperre deaktivieren?", lang),
            isPresented: $showDisableConfirm
        ) {
            Button(tr("Disable", "Deaktivieren", lang), role: .destructive) {
                isAppLockEnabled = false
                isBiometricEnabled = false
                AppLockManager.removePIN()
            }
            Button(tr("Cancel", "Abbrechen", lang), role: .cancel) {}
        } message: {
            Text(tr("The app code will be removed.", "Der App-Code wird entfernt.", lang))
        }
    }

    // MARK: - Server

    private var serverSection: some View {
        Section(tr("Server", "Server", lang)) {
            if !store.isLoggedIn {
                TextField(tr("Server URL", "Server-URL", lang), text: $serverURL)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField(tr("Password", "Passwort", lang), text: $password)
                    .textContentType(.password)

                Button {
                    Task { await store.login(url: serverURL, password: password) }
                } label: {
                    HStack {
                        if store.isLoading {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text(tr("Connect", "Verbinden", lang))
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(serverURL.isEmpty || password.isEmpty || store.isLoading)
            } else {
                HStack {
                    Text(tr("Server", "Server", lang))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(store.serverURL)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Button(tr("Disconnect", "Abmelden", lang), role: .destructive) {
                    store.logout()
                    serverURL = ""
                    password = ""
                }
            }

            Toggle(tr("Trust Self-Signed Certificates", "Selbstsignierten Zertifikaten vertrauen", lang), isOn: $trustSelfSignedCerts)
                .onChange(of: trustSelfSignedCerts) { _, _ in store.resetSession() }

            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(tr(
                    "Only enable if you manage the server and trust its network.",
                    "Nur aktivieren, wenn Sie den Server selbst betreiben und dem Netzwerk vertrauen.",
                    lang
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let error = store.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }

    // MARK: - General

    private var generalSection: some View {
        Section(tr("General", "Allgemein", lang)) {
            Picker(tr("Time Format", "Zeitformat", lang), selection: $timeFormat) {
                Text("24h").tag("24h")
                Text("12h (AM/PM)").tag("12h")
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section(tr("Appearance", "Erscheinungsbild", lang)) {
            Toggle(tr("Enable Dark Mode", "Dark Mode aktivieren", lang), isOn: $isDarkModeEnabled)
            Text(tr(
                "When enabled, the app is always shown in dark mode.",
                "Wenn aktiviert, wird die App immer im Dunklen Modus angezeigt.",
                lang
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            Picker(tr("Language", "Sprache", lang), selection: $lang) {
                Text("English").tag("en")
                Text("Deutsch").tag("de")
            }
            .id(lang)
        }
    }

    // MARK: - App Lock

    private var appLockSection: some View {
        Section(tr("App Lock", "Code-Sperre", lang)) {
            Toggle(tr("Enable App Lock", "Code-Sperre aktivieren", lang), isOn: Binding(
                get: { isAppLockEnabled },
                set: { newValue in
                    if newValue {
                        showPINSetup = true
                    } else {
                        showDisableConfirm = true
                    }
                }
            ))

            if isAppLockEnabled {
                Button(tr("Change Code", "Code ändern", lang)) {
                    showPINSetup = true
                }

                if biometric != .none {
                    Toggle(
                        tr("Use \(biometric.displayName)", "\(biometric.displayName) aktivieren", lang),
                        isOn: $isBiometricEnabled
                    )
                }
            }
        }
    }

    // MARK: - Links & Contact

    private var linksSection: some View {
        Section(tr("Links & Contact", "Links & Kontakt", lang)) {
            if let url = URL(string: "https://vkugler.app") {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text(tr("Developer Website", "Developer-Website", lang))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let url = URL(string: "https://github.com/gatzenga/Companion-for-Duplicati") {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text("GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let url = URL(string: "https://gatzenga.github.io/Companion-for-Duplicati/privacy.html") {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "hand.raised")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text(tr("Privacy Policy", "Datenschutz", lang))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let url = URL(string: "mailto:contact@vkugler.app") {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text(tr("Contact", "Kontakt", lang))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        Section("Info") {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
            Text("Companion for Duplicati \(version) (\(build))")
            Text(tr(
                "A companion app for monitoring Duplicati backup servers.",
                "Eine Companion-App zum Überwachen von Duplicati-Backup-Servern.",
                lang
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
