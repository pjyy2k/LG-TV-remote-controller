import UIKit
import WatchConnectivity

/// watchOS blocks WebSocket connections for ordinary apps (TN3135), so the watch
/// sends each command here and the iPhone talks to the TV on its behalf.
@MainActor
final class WatchRelay: NSObject, WCSessionDelegate {
    static let shared = WatchRelay()

    private let client = WebOSClient()
    private var queue: Task<Void, Never>?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let command = (message["command"] as? String).flatMap(TVCommand.init(rawValue:))
        Task { @MainActor in
            guard let command else {
                replyHandler(["error": String(localized: "알 수 없는 명령입니다. 아이폰 앱을 업데이트하세요.")])
                return
            }
            self.enqueue(command, reply: replyHandler)
        }
    }

    // Commands run one at a time so a second tap cannot restart a connection the first is still opening.
    private func enqueue(_ command: TVCommand, reply: @escaping ([String: Any]) -> Void) {
        let previous = queue
        queue = Task {
            await previous?.value
            let background = UIApplication.shared.beginBackgroundTask(withName: "WatchCommand")
            defer { UIApplication.shared.endBackgroundTask(background) }
            do {
                try await TVCommandRunner.run(command, on: client)
                reply([:])
            } catch {
                client.disconnect()
                reply(["error": error.localizedDescription])
            }
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
