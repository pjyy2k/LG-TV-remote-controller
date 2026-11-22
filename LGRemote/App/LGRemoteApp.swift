import SwiftUI

@main
struct LGRemoteApp: App {
    @State private var model = RemoteViewModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        WatchRelay.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    switch phase {
                    case .active: model.startWatching()
                    case .background: model.stopWatching()
                    default: break
                    }
                }
        }
    }
}

struct RootView: View {
    @Environment(RemoteViewModel.self) private var model

    var body: some View {
        if model.savedTV == nil {
            ConnectView()
        } else {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    @Environment(RemoteViewModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 8) {
            ConnectionBanner()
            TabView {
                RemoteView()
                    .tabItem { Label("리모컨", systemImage: "av.remote") }
                AppsView()
                    .tabItem { Label("앱·입력", systemImage: "square.grid.2x2") }
                TouchpadView()
                    .tabItem { Label("터치패드", systemImage: "hand.point.up.left") }
            }
        }
        .sheet(item: Binding(
            get: { model.keyboardRequest },
            set: { if $0 == nil { model.hideKeyboardPopup() } }
        )) { request in
            KeyboardPopup(request: request)
        }
        .alert("알림", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

struct ConnectionBanner: View {
    @Environment(RemoteViewModel.self) private var model

    var body: some View {
        switch model.state {
        case .connected:
            EmptyView()
        case .connecting:
            banner { ProgressView(); Text("TV에 연결 중…") }
        case .awaitingApproval:
            banner { Image(systemName: "tv"); Text("TV 화면에서 연결 요청을 '허용'해 주세요.") }
        case .poweredOff:
            banner {
                Image(systemName: "power")
                Text("TV가 꺼져 있습니다.")
                Spacer()
                Button("다시 연결") { Task { await model.reconnectNow() } }
                    .buttonStyle(.bordered)
                Button("켜기") { model.powerOn() }
                    .buttonStyle(.borderedProminent)
            }
        case .idle, .failed:
            banner {
                Image(systemName: "wifi.exclamationmark")
                Text(failureText).lineLimit(2)
                Spacer()
                Button("다시 연결") { Task { await model.reconnectIfNeeded() } }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var failureText: String {
        if case .failed(let reason) = model.state { return reason }
        return String(localized: "연결되지 않음")
    }

    private func banner<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 10, content: content)
            .font(.footnote)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
    }
}
