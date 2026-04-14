# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This App Does

Companion for Duplicati is a native iOS app that monitors self-hosted Duplicati backup servers. It provides real-time backup status, manual backup triggering, log viewing, and server notifications. Authentication uses token-based auth against the Duplicati REST API v1, with credentials stored in the iOS Keychain.

## Build Commands

```bash
# Debug build for simulator
xcodebuild -scheme "Companion for Duplicati" -configuration Debug -sdk iphonesimulator build

# Debug build for device
xcodebuild -scheme "Companion for Duplicati" -configuration Debug -sdk iphoneos build

# Release build
xcodebuild -scheme "Companion for Duplicati" -configuration Release -sdk iphoneos build
```

There are no tests, no linting tools (SwiftLint, SwiftFormat), and no external package dependencies — only Apple frameworks (SwiftUI, Foundation, LocalAuthentication, Security).

## Architecture

**State Management:** `BackupStore` (Services/BackupStore.swift) is the central `@Observable` store, injected via SwiftUI environment. It holds all app state: backups, login status, notifications, progress, and server state.

**Networking:** `APIService` (Services/APIService.swift) is a singleton HTTP client. It handles token auth with auto-refresh against Duplicati's REST API. The Info.plist sets `NSAllowsArbitraryLoads = YES` to support HTTP (non-HTTPS) homelab servers. Users can also enable a setting to bypass SSL certificate verification for self-signed certs.

**Polling:** `BackupStore.startPolling()` runs a 1-second loop fetching `/api/v1/progressstate` and `/api/v1/serverstate`. It stops on logout or when the app is backgrounded.

**Security:**
- Credentials (server URL, password, token) live in the iOS Keychain via `KeychainService`
- `AppLockManager` manages a 4-digit PIN stored in Keychain
- `BiometricService` wraps LocalAuthentication for Face ID/Touch ID
- The app locks itself when backgrounded if PIN is enabled (handled in `Companion_for_DuplicatiApp.swift` via `scenePhase`)

**Localization:** Uses a custom `tr()` function (not Apple's `NSLocalizedString`) for English/German. Language preference is stored in `UserDefaults` under key `appLanguage`. All user-visible strings must go through `tr()`.

**API-Quelldateien im Duplicati-Repo** (`~/Repositorys/GitHub/duplicati`):

| Thema | Quelldatei |
|---|---|
| Endpoints (Auth, State, Backups, Progress, Notifications, Logs) | `Duplicati/WebserverCore/Endpoints/V1/` |
| DTOs (Request-/Response-Strukturen) | `Duplicati/WebserverCore/Dto/` |
| Enums (BackupStatus, LogMessageType, DuplicatiOperation, SuggestedStatusIcon) | `Duplicati/Server/Duplicati.Server.Serialization/Enums.cs` |
| Live Controls (ProgramState: Running/Paused) | `Duplicati/Library/RestAPI/LiveControls.cs` |
| Logging-Typen | `Duplicati/Library/Logging/Log.cs` |

## UI Structure

`ContentView.swift` sets up a tab bar with Home, Notifications, and Settings tabs. The app entry point (`Companion_for_DuplicatiApp.swift`) wraps everything in `AppLockView` if a PIN is set, and sets the global tint to `#3764B9`.

Views are in `Views/`, models in `Models/`, services in `Services/`, and date/number formatting helpers in `Utilities/Formatters.swift`.
