import LocalAuthentication

enum BiometricType {
    case none, faceID, touchID

    var displayName: String {
        switch self {
        case .none: ""
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        }
    }

    var systemImage: String {
        switch self {
        case .none: ""
        case .faceID: "faceid"
        case .touchID: "touchid"
        }
    }
}

enum BiometricService {
    static var available: BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return .none
        }
    }

    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }
}
