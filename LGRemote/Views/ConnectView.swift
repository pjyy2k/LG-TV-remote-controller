import SwiftUI

struct ConnectView: View {
    @Environment(RemoteViewModel.self) private var model
    @State private var manualHost = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("아이폰과 TV가 같은 Wi-Fi에 연결되어 있어야 합니다. 처음 연결하면 TV 화면에 연결 허용 창이 뜹니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    if model.isScanning {
                        HStack { ProgressView(); Text("네트워크에서 TV 검색 중…") }
                    } else if model.scanResults.isEmpty {
                        Text("발견된 TV가 없습니다. 다시 검색하거나 IP를 직접 입력하세요.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(model.scanResults, id: \.self) { host in
                        Button {
                            Task { await model.connect(host: host) }
                        } label: {
                            Label(host, systemImage: "tv")
                        }
                    }
                } header: {
                    HStack {
                        Text("발견된 TV")
                        Spacer()
                        Button("다시 검색") { Task { await model.scan() } }
                            .disabled(model.isScanning)
                    }
                }

                Section("IP 주소로 연결") {
                    TextField("예: 192.168.0.10", text: $manualHost)
                        .ipAddressKeyboard()
                    Button("연결") { Task { await model.connect(host: manualHost) } }
                        .disabled(manualHost.isEmpty || model.state == .connecting)
                }

                Section { status }
            }
            .navigationTitle("LG TV 연결")
            .task { await model.scan() }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch model.state {
        case .connecting:
            HStack { ProgressView(); Text("연결 중…") }
        case .awaitingApproval:
            Label("TV 화면에서 '허용'을 눌러 주세요.", systemImage: "hand.tap")
                .foregroundStyle(.orange)
        case .failed(let reason):
            Label(reason, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        case .poweredOff:
            Label("TV가 대기 상태입니다. 리모컨으로 켜거나 저장 후 '켜기'를 누르세요.", systemImage: "power")
                .foregroundStyle(.secondary)
        case .idle, .connected:
            EmptyView()
        }
    }
}
