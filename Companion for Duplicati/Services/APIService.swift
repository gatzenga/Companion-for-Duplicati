import Foundation

// MARK: - Fehlertypen

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(Int)
    case networkError(Error)
    case decodingError
    case loginFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:             "Ungültige Server-URL"
        case .unauthorized:           "Nicht autorisiert"
        case .serverError(let code):  "Serverfehler (\(code))"
        case .networkError(let err):  err.localizedDescription
        case .decodingError:          "Antwort konnte nicht verarbeitet werden"
        case .loginFailed(let msg):   msg
        }
    }
}

// MARK: - SSL-Delegate
// Accepts self-signed certificates — intentional for Homelab/self-hosted Duplicati instances.
// This bypasses TLS validation: only use with trusted local networks or known servers.
private final class SSLDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - API Service

@Observable
final class APIService {
    private(set) var baseURL: String = ""
    private var token: String = ""
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config, delegate: SSLDelegate(), delegateQueue: nil)
    }

    func configure(baseURL: String, token: String) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.token = token
    }

    // MARK: - Login

    func login(baseURL: String, password: String) async throws -> AuthResponse {
        let cleanURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard let url = URL(string: "\(cleanURL)/api/v1/auth/login") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["Password": password])

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        guard http.statusCode == 200 else {
            throw APIError.loginFailed("Login fehlgeschlagen (Status \(http.statusCode))")
        }

        guard let auth = try? JSONDecoder().decode(AuthResponse.self, from: data) else {
            throw APIError.decodingError
        }

        self.baseURL = cleanURL
        self.token = auth.AccessToken

        return auth
    }

    // MARK: - Backups

    func fetchBackups() async throws -> [BackupListItem] {
        let data = try await authenticatedRequest(path: "/api/v1/backups")

        guard let backups = try? JSONDecoder().decode([BackupListItem].self, from: data) else {
            throw APIError.decodingError
        }

        return backups
    }

    // MARK: - Backup starten

    func runBackup(id: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/v1/backup/\(id)/run") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if http.statusCode == 401 {
            guard try await refreshToken() else { throw APIError.unauthorized }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (_, retry) = try await session.data(for: request)
            guard let retryHTTP = retry as? HTTPURLResponse,
                  (200...299).contains(retryHTTP.statusCode) else {
                throw APIError.unauthorized
            }
            return
        }

        guard (200...299).contains(http.statusCode) else {
            throw APIError.serverError(http.statusCode)
        }
    }

    // MARK: - Backup-Detail (volle Konfiguration)

    func fetchBackupDetail(id: String) async throws -> BackupDetailResponse {
        let data = try await authenticatedRequest(path: "/api/v1/backup/\(id)")

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let backupObj = (json["backup"] ?? json["Backup"]) as? [String: Any],
              let rawSettings = (backupObj["settings"] ?? backupObj["Settings"]) as? [[String: Any]]
        else {
            return BackupDetailResponse(settings: [])
        }

        let settings: [BackupSetting] = rawSettings.compactMap { dict in
            guard let name = (dict["name"] ?? dict["Name"]) as? String else { return nil }
            let value = (dict["value"] ?? dict["Value"]) as? String
            return BackupSetting(name: name, value: value)
        }

        return BackupDetailResponse(settings: settings)
    }

    // MARK: - Letzter Log-Eintrag eines Backups

    func fetchLastLog(id: String) async throws -> BackupLogMessage? {
        let data = try await authenticatedRequest(path: "/api/v1/backup/\(id)/log?pagesize=1")

        guard let entries = try? JSONDecoder().decode([BackupLogEntry].self, from: data),
              let first = entries.first else {
            return nil
        }

        return parseLogMessage(first.message)
    }

    // MARK: - Alle Log-Einträge eines Backups

    func fetchBackupLogs(id: String, pageSize: Int = 50) async throws -> [BackupLogEntry] {
        let data = try await authenticatedRequest(path: "/api/v1/backup/\(id)/log?pagesize=\(pageSize)")

        guard let entries = try? JSONDecoder().decode([BackupLogEntry].self, from: data) else {
            throw APIError.decodingError
        }

        return entries
    }

    // MARK: - Notifications

    func fetchNotifications() async throws -> [DuplicatiNotification] {
        let data = try await authenticatedRequest(path: "/api/v1/notifications")

        guard let notifications = try? JSONDecoder().decode([DuplicatiNotification].self, from: data) else {
            return []
        }

        return notifications
    }

    func dismissNotification(id: Int) async throws {
        try await authenticatedPost(path: "/api/v1/notification/\(id)", method: "DELETE")
    }

    // MARK: - Server-Status

    func fetchServerState() async throws -> ServerState {
        let data = try await authenticatedRequest(path: "/api/v1/serverstate")

        guard let state = try? JSONDecoder().decode(ServerState.self, from: data) else {
            throw APIError.decodingError
        }

        return state
    }

    // MARK: - Server Pause / Resume

    func pauseServer() async throws {
        try await authenticatedPost(path: "/api/v1/serverstate/pause")
    }

    func resumeServer() async throws {
        try await authenticatedPost(path: "/api/v1/serverstate/resume")
    }

    // MARK: - Live-Fortschritt

    func fetchProgressState() async throws -> ProgressState {
        let data = try await authenticatedRequest(path: "/api/v1/progressstate")

        guard let progress = try? JSONDecoder().decode(ProgressState.self, from: data) else {
            throw APIError.decodingError
        }

        return progress
    }

    // MARK: - Interne Hilfsmethoden

    private func authenticatedPost(path: String, method: String = "POST") async throws {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if http.statusCode == 401 {
            guard try await refreshToken() else { throw APIError.unauthorized }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (_, retry) = try await session.data(for: request)
            guard let retryHTTP = retry as? HTTPURLResponse,
                  (200...299).contains(retryHTTP.statusCode) else {
                throw APIError.unauthorized
            }
            return
        }

        guard (200...299).contains(http.statusCode) else {
            throw APIError.serverError(http.statusCode)
        }
    }

    private func authenticatedRequest(path: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if http.statusCode == 401 {
            guard try await refreshToken() else { throw APIError.unauthorized }

            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await session.data(for: request)

            guard let retryHTTP = retryResponse as? HTTPURLResponse,
                  (200...299).contains(retryHTTP.statusCode) else {
                throw APIError.unauthorized
            }
            return retryData
        }

        guard (200...299).contains(http.statusCode) else {
            throw APIError.serverError(http.statusCode)
        }

        return data
    }

    private func refreshToken() async throws -> Bool {
        guard let password = KeychainService.load(.password) else { return false }

        do {
            let auth = try await login(baseURL: baseURL, password: password)
            KeychainService.save(auth.AccessToken, for: .token)
            return true
        } catch {
            return false
        }
    }
}
