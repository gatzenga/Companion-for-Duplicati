import SwiftUI

enum AppTab: Hashable {
    case home, settings
}

enum SortOrder: String, CaseIterable {
    case name
    case lastBackup
    case status

    var label: String {
        switch self {
        case .name: "Name"
        case .lastBackup: "Letztes Backup"
        case .status: "Status"
        }
    }
}

@Observable
final class BackupStore {
    var backups: [BackupListItem] = []
    var isLoggedIn = false
    var isLoading = false
    var errorMessage: String?
    var sortOrder: SortOrder = .name
    var serverURL: String = ""
    var selectedTab: AppTab = .home

    private let api = APIService()

    init() {
        if let url = KeychainService.load(.serverURL),
           let token = KeychainService.load(.token) {
            serverURL = url
            api.configure(baseURL: url, token: token)
            isLoggedIn = true
        }
    }

    var sortedBackups: [BackupListItem] {
        switch sortOrder {
        case .name:
            backups.sorted {
                $0.Backup.Name.localizedCaseInsensitiveCompare($1.Backup.Name) == .orderedAscending
            }
        case .lastBackup:
            backups.sorted {
                ($0.lastBackupDate ?? .distantPast) > ($1.lastBackupDate ?? .distantPast)
            }
        case .status:
            backups.sorted {
                if $0.status.sortPriority != $1.status.sortPriority {
                    return $0.status.sortPriority < $1.status.sortPriority
                }
                return $0.Backup.Name.localizedCaseInsensitiveCompare($1.Backup.Name) == .orderedAscending
            }
        }
    }

    // MARK: - Login

    func login(url: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await api.login(baseURL: url, password: password)
            KeychainService.save(password, for: .password)
            KeychainService.save(response.AccessToken, for: .token)
            KeychainService.save(url, for: .serverURL)
            serverURL = url
            isLoggedIn = true
            selectedTab = .home
            await fetchBackups()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Logout

    func logout() {
        KeychainService.deleteAll()
        backups = []
        isLoggedIn = false
        serverURL = ""
        errorMessage = nil
    }

    // MARK: - Fetch

    func fetchBackups() async {
        guard isLoggedIn else { return }
        isLoading = true

        do {
            backups = try await api.fetchBackups()
            errorMessage = nil
        } catch {
            if let apiError = error as? APIError, case .unauthorized = apiError {
                isLoggedIn = false
                errorMessage = "Sitzung abgelaufen. Bitte erneut anmelden."
                selectedTab = .settings
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    // MARK: - Run Backup

    func runBackup(id: String) async throws {
        try await api.runBackup(id: id)
    }
}
