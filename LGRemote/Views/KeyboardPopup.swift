import SwiftUI

struct KeyboardPopup: View {
    @Environment(RemoteViewModel.self) private var model
    let request: TVKeyboardRequest
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Group {
                    if request.isSecure {
                        SecureField("비밀번호", text: $text)
                    } else {
                        TextField("TV에 입력할 내용", text: $text)
                    }
                }
                .plainTextInput()
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit(send)
                .padding(12)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                Text("전송하면 TV 입력창에 들어가고 확인(엔터)까지 누릅니다. 취소하면 TV 키보드도 닫습니다(뒤로).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("TV 키보드 입력")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { model.cancelKeyboard() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("전송", action: send).disabled(text.isEmpty)
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium])
    }

    private func send() {
        guard !text.isEmpty else { return }
        model.sendKeyboardText(text)
    }
}
