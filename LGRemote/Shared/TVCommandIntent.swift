import AppIntents
import Foundation

enum TVCommandError: LocalizedError {
    case noSavedTV
    case missingMAC

    var errorDescription: String? {
        switch self {
        case .noSavedTV: return String(localized: "앱에서 먼저 TV를 연결하세요.")
        case .missingMAC: return String(localized: "TV를 켜려면 TV가 켜져 있을 때 앱으로 한 번 연결하거나, 설정에서 MAC 주소를 입력하세요.")
        }
    }
}

struct TVCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "LG TV 조작"
    static var isDiscoverable = false

    @Parameter(title: "명령")
    var command: TVCommand

    init() {}

    init(_ command: TVCommand) {
        self.command = command
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let client = WebOSClient()
        defer { client.disconnect() }
        try await TVCommandRunner.run(command, on: client)
        return .result()
    }
}

/// Runs a TVCommand against the saved TV, reusing `client` when its session is already open.
@MainActor
enum TVCommandRunner {
    static func run(_ command: TVCommand, on client: WebOSClient) async throws {
        guard let tv = TVStore.load() else { throw TVCommandError.noSavedTV }
        if command == .power {
            try await togglePower(tv, client: client)
            return
        }

        try await ensureSession(client, tv: tv)
        switch command {
        case .channelUp: try await client.requestOrButton("ssap://tv/channelUp", button: "CHANNELUP")
        case .channelDown: try await client.requestOrButton("ssap://tv/channelDown", button: "CHANNELDOWN")
        case .play: try await client.request("ssap://media.controls/play")
        case .pause: try await client.request("ssap://media.controls/pause")
        case .volumeUp: try await client.sendButton("VOLUMEUP")
        case .volumeDown: try await client.sendButton("VOLUMEDOWN")
        case .mute: try await client.sendButton("MUTE")
        case .home: try await client.sendButton("HOME")
        case .back: try await client.sendButton("BACK")
        case .up: try await client.sendButton("UP")
        case .down: try await client.sendButton("DOWN")
        case .left: try await client.sendButton("LEFT")
        case .right: try await client.sendButton("RIGHT")
        case .ok: try await client.sendButton("ENTER")
        case .power: break
        }
    }

    private static func ensureSession(_ client: WebOSClient, tv: SavedTV) async throws {
        guard !client.isSessionOpen else { return }
        _ = try await client.connect(host: tv.host, clientKey: tv.clientKey)
    }

    private static func togglePower(_ tv: SavedTV, client: WebOSClient) async throws {
        if await TVScanner.isReachable(tv.host) {
            do {
                try await ensureSession(client, tv: tv)
                if try await client.isPoweredOn() {
                    try await client.turnOff()
                    return
                }
            } catch WebOSError.pairingRejected {
                throw WebOSError.pairingRejected
            } catch {
                // An open port that cannot complete a session is a TV in standby; fall through and wake it.
            }
        }
        guard !tv.wakeMACs.isEmpty else { throw TVCommandError.missingMAC }
        try await WakeOnLAN.wake(macs: tv.wakeMACs, lastKnownHost: tv.host)
    }
}
