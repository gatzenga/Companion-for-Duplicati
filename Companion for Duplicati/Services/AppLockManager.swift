enum AppLockManager {
    static func hasPIN() -> Bool {
        KeychainService.load(.appPIN) != nil
    }

    static func setPIN(_ pin: String) {
        KeychainService.save(pin, for: .appPIN)
    }

    static func verifyPIN(_ pin: String) -> Bool {
        KeychainService.load(.appPIN) == pin
    }

    static func removePIN() {
        KeychainService.delete(.appPIN)
    }
}
