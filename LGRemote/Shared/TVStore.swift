import Foundation

struct SavedTV: Codable, Equatable {
    var host: String
    var name: String
    var clientKey: String?
    var mac: String?
    var wiredMAC: String?
    var wifiMAC: String?

    var wakeMACs: [String] {
        var seen = Set<String>()
        return [mac, wiredMAC, wifiMAC].compactMap { $0 }.filter { seen.insert($0).inserted }
    }
}

enum TVStore {
    static let appGroup = "group.com.jinyoung.lgremote"
    private static let key = "savedTV"
    private static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    static func load() -> SavedTV? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SavedTV.self, from: data)
    }

    static func save(_ tv: SavedTV) {
        guard let data = try? JSONEncoder().encode(tv) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear() {
        defaults.removeObject(forKey: key)
    }
}
