import Foundation
import Observation
import WidgetKit

struct TVApp: Identifiable, Hashable {
    let id: String
    let title: String
    let iconURL: URL?
}

struct TVInput: Identifiable, Hashable {
    let id: String
    let label: String
    let connected: Bool
}

struct TVKeyboardRequest: Identifiable, Equatable {
    let id = UUID()
    let isSecure: Bool
}

enum ConnectionState: Equatable {
    case idle
    case connecting
    case awaitingApproval
    case connected
    case poweredOff
    case failed(String)
}

@MainActor
@Observable
final class RemoteViewModel {
    private(set) var state: ConnectionState = .idle
    private(set) var savedTV: SavedTV?
    private(set) var volume: Int?
    private(set) var isMuted = false
    private(set) var usesExternalSpeaker = false
    private(set) var keyboardRequest: TVKeyboardRequest?
    private(set) var apps: [TVApp] = []
    private(set) var inputs: [TVInput] = []
    private(set) var scanResults: [String] = []
    private(set) var tvNames: [String: String] = [:]
    private(set) var isScanning = false
    var errorMessage: String?

    private let client = WebOSClient()
    private var powerOnTask: Task<Void, Never>?
    private var isPoweringOn = false
    private var watchTask: Task<Void, Never>?
    private var lastProbeReachable: Bool?

    init() {
        savedTV = TVStore.load()
        client.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .pairingPrompt:
                self.state = .awaitingApproval
            case .disconnected:
                if self.state != .poweredOff { self.state = .idle }
            }
        }
    }

    var isConnected: Bool { state == .connected }

    func scan() async {
        isScanning = true
        scanResults = await TVScanner.scan()
        isScanning = false
        await withTaskGroup(of: (String, String?).self) { group in
            for host in scanResults where tvNames[host] == nil {
                group.addTask { (host, await TVScanner.name(of: host)) }
            }
            for await (host, name) in group {
                if let name { tvNames[host] = name }
            }
        }
    }

    func connect(host: String) async {
        let host = host.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty else { return }
        state = .connecting
        let previous = savedTV?.host == host ? savedTV : nil
        guard await TVScanner.isReachable(host) else {
            state = previous == nil ? .failed(String(localized: "TV가 응답하지 않습니다. IP 주소와 Wi-Fi를 확인하세요.")) : .poweredOff
            return
        }
        do {
            let key = try await client.connect(host: host, clientKey: previous?.clientKey)
            var tv = previous ?? SavedTV(host: host, name: tvNames[host] ?? "LG TV")
            tv.clientKey = key
            save(tv)
            state = .connected
            subscribePowerState()
            subscribeVolume()
            subscribeKeyboard()
            await loadDeviceDetails()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func reconnectIfNeeded() async {
        guard let savedTV, state == .idle || isFailed else { return }
        await connect(host: savedTV.host)
    }

    func startWatching() {
        watchTask?.cancel()
        lastProbeReachable = nil
        watchTask = Task {
            while !Task.isCancelled {
                await watchTick()
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }

    func stopWatching() {
        watchTask?.cancel()
        watchTask = nil
    }

    private func watchTick() async {
        guard let tv = savedTV, !isPoweringOn else { return }
        guard state == .idle || state == .poweredOff || isFailed, !client.isSessionOpen else { return }
        let reachable = await TVScanner.isReachable(tv.host)
        let wasReachable = lastProbeReachable
        lastProbeReachable = reachable
        guard reachable else {
            if state != .poweredOff { state = .poweredOff }
            return
        }
        if state == .poweredOff && wasReachable == true { return }
        await connect(host: tv.host)
    }

    func reconnectNow() async {
        guard let savedTV else { return }
        await connect(host: savedTV.host)
    }

    func forgetTV() {
        powerOnTask?.cancel()
        client.disconnect()
        TVStore.clear()
        WidgetCenter.shared.reloadAllTimelines()
        savedTV = nil
        apps = []
        inputs = []
        volume = nil
        state = .idle
    }

    func updateMAC(_ mac: String) {
        guard var tv = savedTV else { return }
        let trimmed = mac.trimmingCharacters(in: .whitespaces)
        tv.mac = trimmed.isEmpty ? nil : trimmed.uppercased()
        save(tv)
    }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }

    private func save(_ tv: SavedTV) {
        savedTV = tv
        TVStore.save(tv)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func subscribePowerState() {
        do {
            try client.subscribe(TVPowerState.uri) { [weak self] payload in
                guard let self else { return }
                if TVPowerState.isStandby(payload) {
                    self.state = .poweredOff
                } else if self.state == .poweredOff, TVPowerState.isOn(payload) {
                    self.state = .connected
                }
            }
        } catch {
            report(error.localizedDescription)
        }
    }


    private func loadDeviceDetails() async {
        guard var tv = savedTV else { return }
        if let info = try? await client.request("ssap://system/getSystemInfo"),
           let model = info["modelName"] as? String {
            tv.name = "LG \(model)"
        }
        if let info = try? await client.request("ssap://com.webos.service.connectionmanager/getinfo") {
            tv.wiredMAC = Self.macAddress(in: info, interface: "wiredInfo")
            tv.wifiMAC = Self.macAddress(in: info, interface: "wifiInfo")
            if let manual = tv.mac, manual == tv.wiredMAC || manual == tv.wifiMAC { tv.mac = nil }
        }
        save(tv)
    }

    private static func macAddress(in info: [String: Any], interface: String) -> String? {
        guard let section = info[interface] as? [String: Any],
              let mac = section["macAddress"] as? String,
              WakeOnLAN.isValidMAC(mac) else { return nil }
        return mac.uppercased()
    }

    private func subscribeVolume() {
        do {
            try client.subscribe("ssap://audio/getVolume") { [weak self] payload in
                let status = payload["volumeStatus"] as? [String: Any] ?? payload
                if let volume = status["volume"] as? Int { self?.volume = volume }
                let scenario = (status["scenario"] ?? payload["scenario"]) as? String ?? ""
                self?.usesExternalSpeaker = scenario.contains("ext_speaker") || (self?.volume ?? 0) < 0
                if let muted = (status["muteStatus"] ?? status["muted"]) as? Bool { self?.isMuted = muted }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func subscribeKeyboard() {
        do {
            try client.subscribe("ssap://com.webos.service.ime/registerRemoteKeyboard") { [weak self] payload in
                guard let self, let widget = payload["currentWidget"] as? [String: Any] else { return }
                if widget["focus"] as? Bool == true {
                    let focusChanged = payload["focusChanged"] as? Bool ?? true
                    if focusChanged && self.keyboardRequest == nil {
                        self.keyboardRequest = TVKeyboardRequest(isSecure: widget["hiddenText"] as? Bool ?? false)
                    }
                } else {
                    self.keyboardRequest = nil
                }
            }
        } catch {
            report(error.localizedDescription)
        }
    }

    func sendKeyboardText(_ text: String) {
        keyboardRequest = nil
        run { client in
            try await client.request("ssap://com.webos.service.ime/insertText", payload: ["text": text, "replace": 0])
            try await client.request("ssap://com.webos.service.ime/sendEnterKey")
        }
    }

    func cancelKeyboard() {
        keyboardRequest = nil
        button("BACK")
    }

    func hideKeyboardPopup() {
        keyboardRequest = nil
    }

    func button(_ name: String) { run { try await $0.sendButton(name) } }
    @discardableResult func volumeUp() async -> Bool { await perform { try await $0.sendButton("VOLUMEUP") } }
    @discardableResult func volumeDown() async -> Bool { await perform { try await $0.sendButton("VOLUMEDOWN") } }
    @discardableResult func channelUp() async -> Bool {
        await perform { try await $0.requestOrButton("ssap://tv/channelUp", button: "CHANNELUP") }
    }
    @discardableResult func channelDown() async -> Bool {
        await perform { try await $0.requestOrButton("ssap://tv/channelDown", button: "CHANNELDOWN") }
    }
    func play() { run { try await $0.request("ssap://media.controls/play") } }
    func pause() { run { try await $0.request("ssap://media.controls/pause") } }
    func rewind() { run { try await $0.request("ssap://media.controls/rewind") } }
    func fastForward() { run { try await $0.request("ssap://media.controls/fastForward") } }

    func toggleMute() { run { try await $0.sendButton("MUTE") } }

    func powerOff() {
        powerOnTask?.cancel()
        Task {
            if await perform({ try await $0.turnOff() }) { state = .poweredOff }
        }
    }

    func powerOn() {
        guard let tv = savedTV else { return }
        guard !tv.wakeMACs.isEmpty else {
            report(TVCommandError.missingMAC.localizedDescription)
            return
        }
        powerOnTask?.cancel()
        powerOnTask = Task {
            isPoweringOn = true
            defer { isPoweringOn = false }
            do {
                try await WakeOnLAN.wake(macs: tv.wakeMACs, lastKnownHost: tv.host)
            } catch {
                report(error.localizedDescription)
                return
            }
            state = .connecting
            for second in 1...45 {
                if await TVScanner.isReachable(tv.host) {
                    await connect(host: tv.host)
                    if isConnected { return }
                } else if second % 5 == 0 {
                    try? await WakeOnLAN.wake(macs: tv.wakeMACs, lastKnownHost: tv.host)
                }
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
            state = .failed(String(localized: "TV가 켜지지 않았습니다. TV의 '모바일로 TV 켜기' 설정을 확인하세요."))
        }
    }

    func launch(_ app: TVApp) { run { try await $0.request("ssap://system.launcher/launch", payload: ["id": app.id]) } }
    func switchInput(_ input: TVInput) { run { try await $0.request("ssap://tv/switchInput", payload: ["inputId": input.id]) } }

    func moveCursor(dx: Int, dy: Int) { run { try await $0.moveCursor(dx: dx, dy: dy) } }
    func click() { run { try await $0.click() } }
    func scroll(dy: Int) { run { try await $0.scroll(dy: dy) } }

    func loadAppsAndInputs() async {
        do {
            let launchPoints = try await client.request("ssap://com.webos.applicationManager/listLaunchPoints")
            apps = (launchPoints["launchPoints"] as? [[String: Any]] ?? []).compactMap { item in
                guard let id = item["id"] as? String, let title = item["title"] as? String else { return nil }
                return TVApp(id: id, title: title, iconURL: (item["icon"] as? String).flatMap(URL.init(string:)))
            }
            let inputList = try await client.request("ssap://tv/getExternalInputList")
            inputs = (inputList["devices"] as? [[String: Any]] ?? []).compactMap { item in
                guard let id = item["id"] as? String else { return nil }
                return TVInput(id: id, label: item["label"] as? String ?? id, connected: item["connected"] as? Bool ?? false)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func run(_ command: @escaping (WebOSClient) async throws -> Void) {
        Task { await perform(command) }
    }

    @discardableResult
    private func perform(_ command: (WebOSClient) async throws -> Void) async -> Bool {
        do {
            try await command(client)
            return true
        } catch WebOSError.notConnected {
            report(WebOSError.notConnected.localizedDescription)
            await reconnectIfNeeded()
        } catch {
            report(error.localizedDescription)
        }
        return false
    }

    private func report(_ message: String) {
        guard errorMessage == nil else { return }
        errorMessage = message
    }
}
