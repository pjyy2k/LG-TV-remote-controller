import SwiftUI

struct RemoteView: View {
    @Environment(RemoteViewModel.self) private var model
    @State private var showNumberPad = false
    @State private var showSettings = false

    var body: some View {
        GeometryReader { geometry in
            let padSize = min(geometry.size.width * 0.68, max(140, geometry.size.height - 390), 260)
            VStack(spacing: 0) {
                header
                Spacer(minLength: 8)
                topRow
                Spacer(minLength: 8)
                DirectionPad(size: padSize)
                Spacer(minLength: 8)
                rockers
                Spacer(minLength: 8)
                mediaRow
                Spacer(minLength: 6)
                colorRow
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .sheet(isPresented: $showNumberPad) {
            NumberPadView().presentationDetents([.medium])
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var header: some View {
        HStack {
            Button {
                model.isConnected ? model.powerOff() : model.powerOn()
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(KeyStyle(size: 44))
            .foregroundStyle(.red)

            VStack(alignment: .leading) {
                Text(model.savedTV?.name ?? "LG TV").font(.headline)
                Text(model.isConnected ? "연결됨" : model.state == .poweredOff ? "TV 꺼짐" : "연결 안 됨")
                    .font(.caption)
                    .foregroundStyle(model.isConnected ? .green : .secondary)
            }
            Spacer()
            Button { showSettings = true } label: { Image(systemName: "gearshape") }
                .buttonStyle(KeyStyle(size: 44))
        }
    }

    private var topRow: some View {
        HStack {
            KeyButton(systemImage: "arrow.uturn.backward", label: "뒤로", size: 54) { model.button("BACK") }
            Spacer()
            KeyButton(systemImage: "house", label: "홈", size: 54) { model.button("HOME") }
            Spacer()
            KeyButton(systemImage: "slider.horizontal.3", label: "설정", size: 54) { model.button("MENU") }
            Spacer()
            KeyButton(systemImage: "number", label: "숫자", size: 54) { showNumberPad = true }
        }
    }

    private var rockers: some View {
        HStack(alignment: .center) {
            VStack(spacing: 4) {
                RepeatKey(systemImage: "plus", size: 50) { await model.volumeUp() }
                Text(volumeLabel).font(.caption2).lineLimit(1)
                RepeatKey(systemImage: "minus", size: 50) { await model.volumeDown() }
            }
            Spacer()
            VStack(spacing: 10) {
                KeyButton(systemImage: model.isMuted ? "speaker.slash.fill" : "speaker.wave.2", label: "음소거", size: 52) {
                    model.toggleMute()
                }
                KeyButton(systemImage: "info.circle", label: "정보", size: 52) { model.button("INFO") }
            }
            Spacer()
            VStack(spacing: 4) {
                RepeatKey(systemImage: "chevron.up", size: 50) { await model.channelUp() }
                Text("채널").font(.caption2)
                RepeatKey(systemImage: "chevron.down", size: 50) { await model.channelDown() }
            }
        }
    }

    private var volumeLabel: String {
        if model.usesExternalSpeaker { return "외부 스피커" }
        return model.volume.map { "음량 \($0)" } ?? "음량"
    }

    private var mediaRow: some View {
        HStack {
            KeyButton(systemImage: "backward.fill", size: 44) { model.rewind() }
            Spacer()
            KeyButton(systemImage: "play.fill", size: 44) { model.play() }
            Spacer()
            KeyButton(systemImage: "pause.fill", size: 44) { model.pause() }
            Spacer()
            KeyButton(systemImage: "forward.fill", size: 44) { model.fastForward() }
        }
    }

    private var colorRow: some View {
        HStack(spacing: 12) {
            ForEach([("RED", Color.red), ("GREEN", .green), ("YELLOW", .yellow), ("BLUE", .blue)], id: \.0) { name, color in
                Button { model.button(name) } label: {
                    Capsule().fill(color).frame(height: 8).padding(.horizontal, 12)
                }
                .buttonStyle(KeyStyle(shape: .rounded, size: 30))
            }
        }
    }
}

struct DirectionPad: View {
    @Environment(RemoteViewModel.self) private var model
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.06))
            VStack(spacing: 0) {
                arrow("chevron.up", "UP")
                HStack(spacing: 0) {
                    arrow("chevron.left", "LEFT")
                    Button { model.button("ENTER") } label: { Text("확인") }
                        .buttonStyle(KeyStyle(size: size * 0.32))
                    arrow("chevron.right", "RIGHT")
                }
                arrow("chevron.down", "DOWN")
            }
        }
        .frame(width: size, height: size)
    }

    private func arrow(_ image: String, _ key: String) -> some View {
        Button { model.button(key) } label: { Image(systemName: image) }
            .buttonStyle(KeyStyle(size: size * 0.31))
            .accessibilityLabel(key)
    }
}

struct NumberPadView: View {
    @Environment(RemoteViewModel.self) private var model
    private let columns = Array(repeating: GridItem(.flexible()), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(1...9, id: \.self) { digit in key("\(digit)") }
            Button { model.button("DASH") } label: { Text("-") }
                .buttonStyle(KeyStyle(shape: .rounded))
            key("0")
            Button { model.button("ENTER") } label: { Text("확인") }
                .buttonStyle(KeyStyle(shape: .rounded))
        }
        .padding(24)
    }

    private func key(_ digit: String) -> some View {
        Button { model.button(digit) } label: { Text(digit) }
            .buttonStyle(KeyStyle(shape: .rounded))
    }
}
