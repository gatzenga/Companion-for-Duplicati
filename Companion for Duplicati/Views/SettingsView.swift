import SwiftUI

struct SettingsView: View {
    @Environment(BackupStore.self) private var store
    @State private var serverURL = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                if !store.isLoggedIn {
                    loginSection
                } else {
                    connectionSection
                }

                if let error = store.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                infoSection
            }
            .navigationTitle("Einstellungen")
        }
    }

    // MARK: - Login

    private var loginSection: some View {
        Section("Server") {
            TextField("Server-URL", text: $serverURL)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            SecureField("Passwort", text: $password)
                .textContentType(.password)

            Button {
                Task { await store.login(url: serverURL, password: password) }
            } label: {
                HStack {
                    Spacer()
                    if store.isLoading {
                        ProgressView()
                            .padding(.trailing, 8)
                    }
                    Text("Verbinden")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .disabled(serverURL.isEmpty || password.isEmpty || store.isLoading)
        }
    }

    // MARK: - Connected

    private var connectionSection: some View {
        Section("Verbindung") {
            HStack {
                Text("Server")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(store.serverURL)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Button("Abmelden", role: .destructive) {
                store.logout()
                serverURL = ""
                password = ""
            }
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        Section("Info") {
            HStack {
                Text("Version")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
            }
        }
    }
}
