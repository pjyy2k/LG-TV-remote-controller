import SwiftUI

struct TouchpadView: View {
    @Environment(RemoteViewModel.self) private var model
    @State private var lastLocation: CGPoint?
    @State private var residual = CGSize.zero
    @State private var lastScrollY: CGFloat?
    @State private var scrollTravel: CGFloat = 0
    @State private var scrollSteps = 0
    @State private var clicks = 0
    private let sensitivity: CGFloat = 1.6
    // Finger travel per scroll notch, like one detent of the Magic Remote wheel.
    private let scrollStepDistance: CGFloat = 18

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.white.opacity(0.08))
                    .overlay(Text("드래그: 포인터 이동 · 탭: 클릭").font(.footnote).foregroundStyle(.secondary))
                    .gesture(pointerGesture)
                    .sensoryFeedback(.impact(weight: .light), trigger: clicks)
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.05))
                    .frame(width: 48)
                    .overlay(Image(systemName: "arrow.up.and.down").foregroundStyle(.secondary))
                    .gesture(scrollGesture)
                    .sensoryFeedback(.selection, trigger: scrollSteps)
            }
            HStack {
                KeyButton(systemImage: "arrow.uturn.backward", label: "뒤로") { model.button("BACK") }
                Spacer()
                KeyButton(systemImage: "house", label: "홈") { model.button("HOME") }
                Spacer()
                KeyButton(systemImage: "checkmark", label: "확인") { model.button("ENTER") }
            }
        }
        .padding()
    }

    private var pointerGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                defer { lastLocation = value.location }
                guard let lastLocation else { return }
                let dx = (value.location.x - lastLocation.x) * sensitivity + residual.width
                let dy = (value.location.y - lastLocation.y) * sensitivity + residual.height
                let sendX = Int(dx), sendY = Int(dy)
                residual = CGSize(width: dx - CGFloat(sendX), height: dy - CGFloat(sendY))
                if sendX != 0 || sendY != 0 { model.moveCursor(dx: sendX, dy: sendY) }
            }
            .onEnded { value in
                lastLocation = nil
                residual = .zero
                if abs(value.translation.width) < 4 && abs(value.translation.height) < 4 {
                    clicks += 1
                    model.click()
                }
            }
    }

    private var scrollGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                defer { lastScrollY = value.location.y }
                guard let lastScrollY else { return }
                scrollTravel += value.location.y - lastScrollY
                let notches = Int(scrollTravel / scrollStepDistance)
                guard notches != 0 else { return }
                scrollTravel -= CGFloat(notches) * scrollStepDistance
                scrollSteps += abs(notches)
                model.scroll(dy: -notches)
            }
            .onEnded { _ in
                lastScrollY = nil
                scrollTravel = 0
            }
    }
}
