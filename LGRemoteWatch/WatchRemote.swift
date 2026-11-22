import Observation
import WatchConnectivity
import WatchKit

@MainActor
@Observable
final class WatchRemote: NSObject, WCSessionDelegate {
    private(set) var errorMessage: String?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ command: TVCommand) {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            finish(error: "아이폰에 연결할 수 없습니다. 아이폰이 가까이 있는지 확인하세요.")
            return
        }
        WKInterfaceDevice.current().play(.click)
        session.sendMessage(["command": command.rawValue]) { reply in
            let error = reply["error"] as? String
            Task { @MainActor in self.finish(error: error) }
        } errorHandler: { error in
            Task { @MainActor in self.finish(error: error.localizedDescription) }
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func finish(error: String?) {
        errorMessage = error
        if error != nil { WKInterfaceDevice.current().play(.failure) }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
}
