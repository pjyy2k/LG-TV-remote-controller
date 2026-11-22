import SwiftUI

struct KeyStyle: ButtonStyle {
    var shape: KeyShape = .circle
    var size: CGFloat = 60

    enum KeyShape { case circle, rounded }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .keyAppearance(shape: shape, size: size, pressed: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

extension View {
    func keyAppearance(shape: KeyStyle.KeyShape, size: CGFloat, pressed: Bool) -> some View {
        self
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .frame(minWidth: size, minHeight: size)
            .background {
                switch shape {
                case .circle: Circle().fill(.white.opacity(pressed ? 0.28 : 0.12))
                case .rounded: RoundedRectangle(cornerRadius: 18).fill(.white.opacity(pressed ? 0.28 : 0.12))
                }
            }
            .scaleEffect(pressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.1), value: pressed)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    func plainTextInput() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never).autocorrectionDisabled()
        #else
        self
        #endif
    }

    @ViewBuilder
    func ipAddressKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.numbersAndPunctuation).plainTextInput()
        #else
        self
        #endif
    }
}

struct KeyButton: View {
    let systemImage: String
    var label: LocalizedStringKey?
    var shape: KeyStyle.KeyShape = .circle
    var size: CGFloat = 60
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if let label {
                VStack(spacing: 4) {
                    Image(systemName: systemImage)
                    Text(label).font(.caption2)
                }
            } else {
                Image(systemName: systemImage)
            }
        }
        .buttonStyle(KeyStyle(shape: shape, size: size))
        .accessibilityLabel(label.map { Text($0) } ?? Text(systemImage))
    }
}

struct RepeatKey: View {
    let systemImage: String
    var size: CGFloat = 60
    let action: () async -> Bool
    @State private var isPressed = false
    @State private var repeatTask: Task<Void, Never>?

    var body: some View {
        Image(systemName: systemImage)
            .keyAppearance(shape: .rounded, size: size, pressed: isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: isPressed) { _, pressed in pressed }
            .onLongPressGesture(minimumDuration: .infinity, maximumDistance: 40, perform: {}) { pressing in
                isPressed = pressing
                pressing ? startRepeating() : stopRepeating()
            }
            .onDisappear(perform: stopRepeating)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { Task { _ = await action() } }
    }

    private func startRepeating() {
        repeatTask?.cancel()
        Task { _ = await action() }
        repeatTask = Task {
            do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
            while await action() {
                do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            }
        }
    }

    private func stopRepeating() {
        repeatTask?.cancel()
        repeatTask = nil
    }
}
