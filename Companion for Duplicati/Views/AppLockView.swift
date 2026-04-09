import SwiftUI

struct AppLockView: View {
    @Binding var isLocked: Bool
    @AppStorage("isBiometricEnabled") private var isBiometricEnabled = false
    @AppStorage("appLanguage") private var lang = "en"

    @State private var pin = ""
    @State private var shake = false

    private let pinLength = 6
    private let biometric = BiometricService.available

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 44, weight: .regular))
                        .foregroundStyle(.secondary)

                    Text(tr("Enter Code", "Code eingeben", lang))
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer().frame(height: 48)

                PINPadView(pin: $pin, shake: $shake, pinLength: pinLength)

                Spacer().frame(height: 32)

                if isBiometricEnabled && biometric != .none {
                    Button {
                        Task { await tryBiometric() }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: biometric.systemImage)
                                .font(.system(size: 28))
                            Text(biometric.displayName)
                                .font(.caption)
                        }
                        .frame(width: 80, height: 60)
                    }
                    .foregroundStyle(Color.accentColor)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .onChange(of: pin) { _, newValue in
            if newValue.count == pinLength { verify() }
        }
        .task {
            guard AppLockManager.hasPIN() else {
                isLocked = false
                return
            }
            if isBiometricEnabled && biometric != .none {
                await tryBiometric()
            }
        }
    }

    private func verify() {
        if AppLockManager.verifyPIN(pin) {
            isLocked = false
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            shake = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                shake = false
                pin = ""
            }
        }
    }

    private func tryBiometric() async {
        let reason = tr(
            "Unlock Companion for Duplicati",
            "Companion for Duplicati entsperren",
            lang
        )
        if await BiometricService.authenticate(reason: reason) {
            isLocked = false
        }
    }
}
