import SwiftUI

@main
struct LGRemoteWatchApp: App {
    @State private var remote = WatchRemote()

    var body: some Scene {
        WindowGroup {
            WatchRemoteView()
                .environment(remote)
                .onAppear { remote.activate() }
        }
    }
}

struct WatchRemoteView: View {
    @Environment(WatchRemote.self) private var remote

    var body: some View {
        TabView {
            NavigationPad()
            VolumePage()
        }
        .tabViewStyle(.verticalPage)
        .overlay(alignment: .bottom) {
            if let message = remote.errorMessage {
                Text(message)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(8)
                    .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                    .onTapGesture { remote.dismissError() }
                    .task(id: message) {
                        try? await Task.sleep(for: .seconds(4))
                        remote.dismissError()
                    }
            }
        }
    }
}

private struct NavigationPad: View {
    var body: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            GridRow {
                WatchKey(.back, "arrow.uturn.backward")
                WatchKey(.up, "chevron.up")
                WatchKey(.home, "house")
            }
            GridRow {
                WatchKey(.left, "chevron.left")
                WatchKey(.ok, "circle.fill", tint: .accentColor)
                WatchKey(.right, "chevron.right")
            }
            GridRow {
                WatchKey(.power, "power", tint: .red)
                WatchKey(.down, "chevron.down")
                WatchKey(.mute, "speaker.slash")
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct VolumePage: View {
    @Environment(WatchRemote.self) private var remote
    @State private var crown = 0.0
    @State private var crownStep = 0

    var body: some View {
        VStack(spacing: 6) {
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    WatchKey(.volumeUp, "speaker.plus")
                    WatchKey(.play, "play.fill")
                    WatchKey(.channelUp, "chevron.up.square")
                }
                GridRow {
                    WatchKey(.volumeDown, "speaker.minus")
                    WatchKey(.pause, "pause.fill")
                    WatchKey(.channelDown, "chevron.down.square")
                }
            }
            Label("크라운으로 음량 조절", systemImage: "digitalcrown.arrow.clockwise")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .focusable()
        .digitalCrownRotation($crown, from: -10_000, through: 10_000, by: 1, sensitivity: .low,
                              isContinuous: false, isHapticFeedbackEnabled: true)
        .onChange(of: crown) { _, value in
            let step = Int(value.rounded())
            guard step != crownStep else { return }
            remote.send(step > crownStep ? .volumeUp : .volumeDown)
            crownStep = step
        }
    }
}

private struct WatchKey: View {
    @Environment(WatchRemote.self) private var remote
    let command: TVCommand
    let systemImage: String
    var tint: Color = .white

    init(_ command: TVCommand, _ systemImage: String, tint: Color = .white) {
        self.command = command
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        Button { remote.send(command) } label: {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.bordered)
        .foregroundStyle(tint)
        .accessibilityLabel(Text(TVCommand.caseDisplayRepresentations[command]?.title ?? "TV"))
    }
}
