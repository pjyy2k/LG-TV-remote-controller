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

    /// The name a TV reports about itself, read without pairing from a unicast SSDP search (unicast needs no
    /// multicast entitlement): a name header in the reply, else the device description it points to,
    /// else the router's reverse DNS name.
    static func name(of host: String) async -> String? {
        let reply = await ssdpSearch(host)
        if let name = reply.name { return name }
        if let location = reply.location, let name = await descriptionFriendlyName(location) { return name }
        return await reverseDNSName(host)
    }

    // The TV answers from an ephemeral port rather than 1900, which a connected NWConnection would drop,
    // so this uses an unconnected socket and accepts any reply from the TV's address.
    private static func ssdpSearch(_ host: String, timeout: TimeInterval = 1.5) async -> (name: String?, location: URL?) {
        await Task.detached {
            var target = sockaddr_in()
            target.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            target.sin_family = sa_family_t(AF_INET)
            target.sin_port = in_port_t(1900).bigEndian
            guard inet_pton(AF_INET, host, &target.sin_addr) == 1 else { return (nil, nil) }
            let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
            guard fd >= 0 else { return (nil, nil) }
            defer { close(fd) }
            var slice = timeval(tv_sec: 0, tv_usec: 250_000)
            setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &slice, socklen_t(MemoryLayout<timeval>.size))

            let search = Array("M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 1\r\nST: ssdp:all\r\n\r\n".utf8)
            let sent = withUnsafePointer(to: &target) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(fd, search, search.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            guard sent == search.count else { return (nil, nil) }

            let deadline = Date().addingTimeInterval(timeout)
            var buffer = [UInt8](repeating: 0, count: 4096)
            var location: URL?
            while Date() < deadline {
                var from = sockaddr_in()
                var fromLength = socklen_t(MemoryLayout<sockaddr_in>.size)
                let count = withUnsafeMutablePointer(to: &from) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        recvfrom(fd, &buffer, buffer.count, 0, $0, &fromLength)
                    }
                }
                guard count > 0, from.sin_addr.s_addr == target.sin_addr.s_addr else { continue }
                let headers = ssdpHeaders(Data(buffer[0..<count]))
                if let name = headerName(headers) { return (name, nil) }
                location = location ?? headers["location"].flatMap(URL.init(string:))
            }
            return (nil, location)
        }.value
    }

    private static func ssdpHeaders(_ response: Data) -> [String: String] {
        var headers: [String: String] = [:]
        for line in String(decoding: response, as: UTF8.self).split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            headers[parts[0].trimmingCharacters(in: .whitespaces).lowercased()] = parts[1].trimmingCharacters(in: .whitespaces)
        }
        return headers
    }

    // webOS services name themselves differently: the DLNA renderer URL-encodes the name,
    // the Netflix discovery service base64-encodes it.
    private static func headerName(_ headers: [String: String]) -> String? {
        if let value = headers["dlnadevicename.lge.com"]?.removingPercentEncoding, !value.isEmpty {
            return value
        }
        if let value = headers["x-friendly-name"], !value.isEmpty {
            return Data(base64Encoded: value).flatMap { String(data: $0, encoding: .utf8) } ?? value
        }
        return nil
    }

    private static func descriptionFriendlyName(_ location: URL) async -> String? {
        var request = URLRequest(url: location)
        request.timeoutInterval = 2
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        let xml = String(decoding: data, as: UTF8.self)
        guard let start = xml.range(of: "<friendlyName>"),
              let end = xml.range(of: "</friendlyName>", range: start.upperBound..<xml.endIndex) else { return nil }
        let name = xml[start.upperBound..<end.lowerBound].trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    private static func reverseDNSName(_ host: String) async -> String? {
        await Task.detached {
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else { return nil }
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    getnameinfo($0, socklen_t(MemoryLayout<sockaddr_in>.size), &buffer, socklen_t(buffer.count), nil, 0, NI_NAMEREQD)
                }
            }
            return result == 0 ? String(cString: buffer) : nil
        }.value
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
