import Foundation
import Network

/// Finds webOS TVs by probing the SSAP ports (3001/3000) on the phone's Wi-Fi subnet.
/// SSDP multicast would need Apple's multicast entitlement; a TCP sweep does not.
enum TVScanner {
    static func scan() async -> [String] {
        let hosts = subnetHosts()
        var found: [String] = []
        for start in stride(from: 0, to: hosts.count, by: 64) {
            let batch = hosts[start..<min(start + 64, hosts.count)]
            await withTaskGroup(of: String?.self) { group in
                for host in batch {
                    group.addTask { await isReachable(host) ? host : nil }
                }
                for await host in group {
                    if let host { found.append(host) }
                }
            }
        }
        return found.sorted { $0.compare($1, options: .numeric) == .orderedAscending }
    }

    static func isReachable(_ host: String) async -> Bool {
        async let secure = isPortOpen(host, port: 3001)
        async let plain = isPortOpen(host, port: 3000)
        let (secureOpen, plainOpen) = await (secure, plain)
        return secureOpen || plainOpen
    }

    private static func isPortOpen(_ host: String, port: UInt16, timeout: TimeInterval = 0.8) async -> Bool {
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else { return false }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: .tcp)
        let once = OnceFlag()
        return await withCheckedContinuation { continuation in
            let finish: @Sendable (Bool) -> Void = { isOpen in
                guard once.claim() else { return }
                connection.cancel()
                continuation.resume(returning: isOpen)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: finish(true)
                case .failed, .waiting, .cancelled: finish(false)
                default: break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(false) }
        }
    }

    private static func subnetHosts() -> [String] {
        guard let wifi = LocalNetwork.wifiInterface() else { return [] }
        let mask = max(wifi.netmask, 0xFFFF_FF00)
        let network = wifi.address & mask
        let broadcast = network | ~mask
        guard broadcast > network + 1 else { return [] }
        return (network + 1..<broadcast).filter { $0 != wifi.address }.map(LocalNetwork.format)
    }
}

private final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
