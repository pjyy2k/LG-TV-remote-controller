import Foundation

enum TVPowerState {
    static let uri = "ssap://com.webos.service.tvpower/power/getPowerState"

    static func isStandby(_ payload: [String: Any]) -> Bool {
        if let processing = payload["processing"] as? String, processing.localizedCaseInsensitiveContains("power off") {
            return true
        }
        guard let state = payload["state"] as? String else { return false }
        return ["Active Standby", "Suspend", "Power Off"].contains(state)
    }

    static func isOn(_ payload: [String: Any]) -> Bool {
        guard !isStandby(payload), let state = payload["state"] as? String else { return false }
        return ["Active", "Screen Off"].contains(state)
    }
}
