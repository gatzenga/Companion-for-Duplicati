import SwiftUI

struct PINSetupView: View {
    let isChanging: Bool
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @AppStorage("appLanguage") private var lang = "en"

    @State private var step: Step = .enter
    @State private var firstPIN = ""
    @State private var pin = ""
    @State private var shake = false

    private let pinLength = 6

    enum Step {
        case enter, confirm

        func title(lang: String) -> String {
            switch self {
            case .enter: tr("Enter New Code", "Neuen Code eingeben", lang)
            case .confirm: tr("Confirm Code", "Code bestätigen", lang)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 44, weight: .regular))
                            .foregroundStyle(.secondary)

                        Text(step.title(lang: lang))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .animation(.default, value: step)
                    }

                    Spacer().frame(height: 48)

                    PINPadView(pin: $pin, shake: $shake, pinLength: pinLength)

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle(isChanging
                ? tr("Change Code", "Code ändern", lang)
                : tr("Set Code", "Code einrichten", lang)
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("Cancel", "Abbrechen", lang)) { onCancel() }
                }
            }
        }
        .onChange(of: pin) { _, newValue in
            if newValue.count == pinLength { handleComplete() }
        }
    }

    private func handleComplete() {
        switch step {
        case .enter:
            firstPIN = pin
            pin = ""
            step = .confirm
        case .confirm:
            if pin == firstPIN {
                AppLockManager.setPIN(pin)
                onSuccess()
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                shake = true
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.6))
                    shake = false
                    pin = ""
                    firstPIN = ""
                    step = .enter
                }
            }
        }
    }
}
