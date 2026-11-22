import SwiftUI

struct SettingsView: View {
    @Environment(RemoteViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var mac = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("TV") {
                    LabeledContent("이름", value: model.savedTV?.name ?? "-")
                    LabeledContent("IP 주소", value: model.savedTV?.host ?? "-")
                }
                Section {
                    LabeledContent("유선", value: model.savedTV?.wiredMAC ?? String(localized: "확인 안 됨"))
                    LabeledContent("무선(Wi-Fi)", value: model.savedTV?.wifiMAC ?? String(localized: "확인 안 됨"))
                    TextField("직접 추가 (예: A1:B2:C3:D4:E5:F6)", text: $mac)
                        .plainTextInput()
                        .onChange(of: mac) { _, value in
                            if value.isEmpty || WakeOnLAN.isValidMAC(value) { model.updateMAC(value) }
                        }
                    if !mac.isEmpty && !WakeOnLAN.isValidMAC(mac) {
                        Text("MAC 주소 형식이 아닙니다. 저장되지 않았습니다.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("전원 켜기용 MAC 주소")
                } footer: {
                    Text("유선·무선 주소는 TV에 연결할 때마다 자동으로 확인하고, 켜기 신호는 여기 표시된 주소 모두로 보냅니다. 자동 확인이 안 될 때만 직접 추가하세요(입력하면 바로 저장됩니다). TV에서 '모바일로 TV 켜기'가 켜져 있어야 합니다.")
                }
                Section {
                    Button("다른 TV 연결 (저장된 TV 삭제)", role: .destructive) {
                        model.forgetTV()
                        dismiss()
                    }
                }
                Section {
                    NavigationLink("개인정보 처리방침") { PrivacyPolicyView() }
                } footer: {
                    Text("이 앱은 LG전자와 관련이 없는 독립 앱입니다. LG와 webOS는 LG전자의 상표입니다.")
                }
            }
            .navigationTitle("설정")
            .toolbar { Button("닫기") { dismiss() } }
            .onAppear { mac = model.savedTV?.mac ?? "" }
        }
    }
}

private struct PrivacyPolicyView: View {
    private let policy: AttributedString = {
        guard let url = Bundle.main.url(forResource: "privacy", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              let parsed = try? AttributedString(
                  markdown: text,
                  options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
              ) else {
            return AttributedString(localized: "개인정보 처리방침을 불러오지 못했습니다.")
        }
        return parsed
    }()

    var body: some View {
        ScrollView {
            Text(policy)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle("개인정보 처리방침")
        .navigationBarTitleDisplayMode(.inline)
    }
}
