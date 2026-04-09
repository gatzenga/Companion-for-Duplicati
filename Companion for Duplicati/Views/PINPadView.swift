import SwiftUI

struct PINPadView: View {
    @Binding var pin: String
    @Binding var shake: Bool
    let pinLength: Int

    var body: some View {
        VStack(spacing: 36) {
            dots
            keypad
        }
    }

    // MARK: - Dots

    private var dots: some View {
        HStack(spacing: 20) {
            ForEach(0..<pinLength, id: \.self) { i in
                Circle()
                    .fill(i < pin.count ? Color.primary : Color.clear)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(Color.primary, lineWidth: 1.5)
                    )
            }
        }
        .offset(x: shake ? 10 : 0)
        .animation(
            shake
                ? .easeInOut(duration: 0.07).repeatCount(6, autoreverses: true)
                : .default,
            value: shake
        )
    }

    // MARK: - Keypad

    private var keypad: some View {
        VStack(spacing: 12) {
            ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                HStack(spacing: 20) {
                    ForEach(row, id: \.self) { digit in
                        numberButton(digit)
                    }
                }
            }
            HStack(spacing: 20) {
                Color.clear
                    .frame(width: 80, height: 80)
                numberButton(0)
                deleteButton
            }
        }
    }

    private func numberButton(_ digit: Int) -> some View {
        Button {
            append("\(digit)")
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text("\(digit)")
                .font(.system(size: 32, weight: .regular, design: .rounded))
                .frame(width: 80, height: 80)
                .background(Color(UIColor.tertiarySystemBackground))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private var deleteButton: some View {
        Button {
            guard !pin.isEmpty else { return }
            pin.removeLast()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 22, weight: .regular))
                .frame(width: 80, height: 80)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    // MARK: -

    private func append(_ digit: String) {
        guard pin.count < pinLength else { return }
        pin += digit
    }
}
