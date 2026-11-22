import Foundation

enum WakeOnLANError: LocalizedError {
    case invalidMAC
    case socket(String)

    var errorDescription: String? {
        switch self {
        case .invalidMAC: return String(localized: "MAC 주소 형식이 올바르지 않습니다. 예: A1:B2:C3:D4:E5:F6")
        case .socket(let reason): return String(localized: "켜기 신호 전송 실패: \(reason)")
        }
    }
}

enum WakeOnLAN {
    static func isValidMAC(_ mac: String) -> Bool {
        parse(mac) != nil
    }

    /// Sends the magic packet several times to every address that can reach the TV:
    /// the limited and subnet broadcasts, plus the TV's last known IP, because iOS
    /// may block broadcasts without the multicast entitlement while unicast still goes out.
    static func wake(macs: [String], lastKnownHost: String?) async throws {
        let packets = macs.compactMap(parse).map { mac in
            [UInt8](repeating: 0xFF, count: 6) + Array(repeating: mac, count: 16).flatMap { $0 }
        }
        guard !packets.isEmpty else { throw WakeOnLANError.invalidMAC }

        var destinations: [UInt32] = [0xFFFF_FFFF]
        if let wifi = LocalNetwork.wifiInterface() { destinations.append(wifi.broadcast) }
        if let host = lastKnownHost, let ip = LocalNetwork.parseIPv4(host) { destinations.append(ip) }

        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { throw WakeOnLANError.socket(String(cString: strerror(errno))) }
        defer { close(fd) }

        var enable: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &enable, socklen_t(MemoryLayout<Int32>.size))

        var delivered = 0
        var lastError = ""
        for round in 0..<3 {
            if round > 0 { try await Task.sleep(for: .milliseconds(150)) }
            for packet in packets {
                for address in destinations {
                    for port: UInt16 in [9, 7] {
                        if send(packet, from: fd, to: address, port: port) {
                            delivered += 1
                        } else {
                            lastError = String(cString: strerror(errno))
                        }
                    }
                }
            }
        }
        guard delivered > 0 else { throw WakeOnLANError.socket(lastError) }
    }

    private static func send(_ packet: [UInt8], from fd: Int32, to ip: UInt32, port: UInt16) -> Bool {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr.s_addr = ip.bigEndian

        let sent = packet.withUnsafeBytes { buffer in
            withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(fd, buffer.baseAddress, buffer.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        return sent == packet.count
    }

    private static func parse(_ mac: String) -> [UInt8]? {
        let parts = mac.split(whereSeparator: { $0 == ":" || $0 == "-" })
        guard parts.count == 6 else { return nil }
        let bytes = parts.compactMap { UInt8($0, radix: 16) }
        return bytes.count == 6 ? bytes : nil
    }
}
