import AppIntents

/// Commands shared by the widget and the Apple Watch app; the watch sends the raw value to the iPhone.
enum TVCommand: String, AppEnum {
    case power, volumeUp, volumeDown, mute, home, back
    case up, down, left, right, ok
    case channelUp, channelDown, play, pause

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "TV 명령"
    static var caseDisplayRepresentations: [TVCommand: DisplayRepresentation] = [
        .power: "전원",
        .volumeUp: "음량 올리기",
        .volumeDown: "음량 내리기",
        .mute: "음소거",
        .home: "홈",
        .back: "뒤로",
        .up: "위",
        .down: "아래",
        .left: "왼쪽",
        .right: "오른쪽",
        .ok: "확인",
        .channelUp: "채널 올리기",
        .channelDown: "채널 내리기",
        .play: "재생",
        .pause: "일시정지",
    ]
}
