import Foundation

enum WebOSError: LocalizedError, Equatable {
    case notConnected
    case timeout
    case invalidResponse
    case pairingRejected
    case missingManifest
    case tv(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: return "TV에 연결되어 있지 않습니다."
        case .timeout: return "TV가 응답하지 않습니다. IP 주소와 Wi-Fi를 확인하세요."
        case .invalidResponse: return "TV 응답을 해석할 수 없습니다."
        case .pairingRejected: return "TV에서 연결을 거부했습니다."
        case .missingManifest: return "등록 매니페스트(RegistrationPayload.json)가 앱에 없습니다."
        case .tv(let text): return "TV 오류: \(text)"
        }
    }
}

/// webOS TVs serve wss on port 3001 with a self-signed certificate, so the
/// TV's certificate is accepted for this session (used only for LAN TV traffic).
enum LocalTVSession {
    static let shared = URLSession(configuration: .ephemeral, delegate: LocalTVTrustDelegate(), delegateQueue: nil)
}

private final class LocalTVTrustDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }
        return (.useCredential, URLCredential(trust: trust))
    }
}

/// Client for the webOS "SSAP" protocol: JSON messages over a WebSocket,
/// plus a second "pointer input" socket used for remote buttons and the touchpad.
@MainActor
final class WebOSClient {
    enum Event {
        case pairingPrompt
        case disconnected(Error)
    }

    var onEvent: ((Event) -> Void)?

    var isSessionOpen: Bool { socket != nil && isRegistered }

    private let session = LocalTVSession.shared
    private var socket: URLSessionWebSocketTask?
    private var isRegistered = false
    private var registerID: String?
    private var receivedAnyMessage = false
    private var pending: [String: CheckedContinuation<[String: Any], Error>] = [:]
    private var subscriptions: [String: ([String: Any]) -> Void] = [:]
    private var pointerSocket: Task<URLSessionWebSocketTask, Error>?
    private var messageCounter = 0

    /// Connects and registers with the TV. Returns the client key to reuse next time,
    /// which lets later connections skip the on-screen approval prompt.
    func connect(host: String, clientKey: String?) async throws -> String {
        disconnect()
        let endpoints = ["wss://\(host):3001/", "ws://\(host):3000/"].compactMap(URL.init(string:))
        var lastError: Error = WebOSError.notConnected
        for url in endpoints {
            let task = session.webSocketTask(with: url)
            socket = task
            task.resume()
            receiveLoop(task)
            do {
                let key = try await register(clientKey: clientKey, on: task)
                isRegistered = true
                return key
            } catch WebOSError.pairingRejected {
                disconnect()
                throw WebOSError.pairingRejected
            } catch {
                lastError = error
                disconnect()
            }
        }
        throw lastError
    }

    func disconnect() {
        let old = socket
        socket = nil
        isRegistered = false
        registerID = nil
        old?.cancel(with: .goingAway, reason: nil)
        closePointerSocket()
        subscriptions.removeAll()
        failAllPending(WebOSError.notConnected)
    }

    private func register(clientKey: String?, on task: URLSessionWebSocketTask) async throws -> String {
        var payload = try Self.registrationPayload()
        if let clientKey { payload["client-key"] = clientKey }
        let id = makeID("register")
        registerID = id
        receivedAnyMessage = false

        // The approval prompt can take a while, but a live TV answers the
        // register message immediately; no answer means wrong host or port.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard let self, self.registerID == id, !self.receivedAnyMessage else { return }
            self.finish(id, with: .failure(WebOSError.timeout))
        }

        let result = try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            send(["type": "register", "id": id, "payload": payload], on: task, failing: id)
        }
        guard let key = result["client-key"] as? String else { throw WebOSError.invalidResponse }
        return key
    }

    private static func registrationPayload() throws -> [String: Any] {
        guard let url = Bundle.main.url(forResource: "RegistrationPayload", withExtension: "json") else {
            throw WebOSError.missingManifest
        }
        let data = try Data(contentsOf: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WebOSError.missingManifest
        }
        return object
    }

    @discardableResult
    func request(_ uri: String, payload: [String: Any]? = nil) async throws -> [String: Any] {
        guard let socket, isRegistered else { throw WebOSError.notConnected }
        let id = makeID("req")
        var message: [String: Any] = ["type": "request", "id": id, "uri": uri]
        if let payload { message["payload"] = payload }
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            send(message, on: socket, failing: id)
        }
    }

    func subscribe(_ uri: String, handler: @escaping ([String: Any]) -> Void) throws {
        guard let socket, isRegistered else { throw WebOSError.notConnected }
        let id = makeID("sub")
        subscriptions[id] = handler
        send(["type": "subscribe", "id": id, "uri": uri], on: socket, failing: id)
    }

    func requestOrButton(_ uri: String, button: String) async throws {
        do {
            try await request(uri)
        } catch WebOSError.tv(_) {
            try await sendButton(button)
        }
    }

    func turnOff() async throws {
        guard socket != nil, isRegistered else { throw WebOSError.notConnected }
        do {
            try await request("ssap://system/turnOff")
        } catch WebOSError.tv(let reason) {
            throw WebOSError.tv(reason)
        } catch {
            // The TV drops the socket while it shuts down, so a lost connection here means it turned off.
        }
    }

    func isPoweredOn() async throws -> Bool {
        do {
            let payload = try await request(TVPowerState.uri)
            return !TVPowerState.isStandby(payload)
        } catch WebOSError.tv(_) {
            return true
        }
    }

    private func send(_ message: [String: Any], on task: URLSessionWebSocketTask, failing id: String) {
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: message)
        } catch {
            finish(id, with: .failure(error))
            return
        }
        task.send(.string(String(decoding: data, as: UTF8.self))) { [weak self] error in
            guard let error else { return }
            Task { @MainActor in self?.finish(id, with: .failure(error)) }
        }
    }

    private func makeID(_ prefix: String) -> String {
        messageCounter += 1
        return "\(prefix)_\(messageCounter)"
    }

    private func receiveLoop(_ task: URLSessionWebSocketTask) {
        Task { [weak self] in
            do {
                while true {
                    let message = try await task.receive()
                    guard let self else { return }
                    switch message {
                    case .string(let text): self.handle(Data(text.utf8))
                    case .data(let data): self.handle(data)
                    @unknown default: break
                    }
                }
            } catch {
                guard let self, self.socket === task else { return }
                let wasRegistered = self.isRegistered
                self.socket = nil
                self.isRegistered = false
                self.closePointerSocket()
                self.subscriptions.removeAll()
                self.failAllPending(error)
                if wasRegistered { self.onEvent?(.disconnected(error)) }
            }
        }
    }

    private func handle(_ data: Data) {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
        receivedAnyMessage = true
        let id = object["id"] as? String ?? ""
        let type = object["type"] as? String ?? ""
        let payload = object["payload"] as? [String: Any] ?? [:]
        let errorText = object["error"] as? String ?? payload["errorText"] as? String

        if id == registerID {
            switch type {
            case "registered":
                registerID = nil
                finish(id, with: .success(payload))
            case "error":
                registerID = nil
                let rejected = errorText?.localizedCaseInsensitiveContains("denied") == true
                finish(id, with: .failure(rejected ? WebOSError.pairingRejected : WebOSError.tv(errorText ?? type)))
            default:
                if payload["pairingType"] as? String == "PROMPT" { onEvent?(.pairingPrompt) }
            }
            return
        }

        if let handler = subscriptions[id] {
            if type != "error" { handler(payload) }
            return
        }

        if type == "error" || payload["returnValue"] as? Bool == false {
            finish(id, with: .failure(WebOSError.tv(errorText ?? "알 수 없는 오류")))
        } else {
            finish(id, with: .success(payload))
        }
    }

    private func finish(_ id: String, with result: Result<[String: Any], Error>) {
        subscriptions.removeValue(forKey: id)
        pending.removeValue(forKey: id)?.resume(with: result)
    }

    private func failAllPending(_ error: Error) {
        let waiting = pending
        pending.removeAll()
        for continuation in waiting.values { continuation.resume(throwing: error) }
    }

    /// Sends a remote key such as "UP", "ENTER", "BACK", "HOME", "MENU", "0"..."9".
    func sendButton(_ name: String) async throws {
        try await sendPointer("type:button\nname:\(name)\n\n")
    }

    func moveCursor(dx: Int, dy: Int) async throws {
        try await sendPointer("type:move\ndx:\(dx)\ndy:\(dy)\ndown:0\n\n")
    }

    func click() async throws {
        try await sendPointer("type:click\n\n")
    }

    func scroll(dy: Int) async throws {
        try await sendPointer("type:scroll\ndx:0\ndy:\(dy)\n\n")
    }

    private func closePointerSocket() {
        guard let pending = pointerSocket else { return }
        pointerSocket = nil
        Task { (try? await pending.value)?.cancel(with: .goingAway, reason: nil) }
    }

    private func sendPointer(_ text: String) async throws {
        let pointer = try await pointerTask()
        do {
            try await pointer.send(.string(text))
        } catch {
            pointerSocket = nil
            throw error
        }
    }

    private func pointerTask() async throws -> URLSessionWebSocketTask {
        if let pointerSocket { return try await pointerSocket.value }
        let task = Task { [session] () throws -> URLSessionWebSocketTask in
            let payload = try await self.request("ssap://com.webos.service.networkinput/getPointerInputSocket")
            guard let path = payload["socketPath"] as? String, let url = URL(string: path) else {
                throw WebOSError.invalidResponse
            }
            let socket = session.webSocketTask(with: url)
            socket.resume()
            return socket
        }
        pointerSocket = task
        do {
            return try await task.value
        } catch {
            pointerSocket = nil
            throw error
        }
    }
}
