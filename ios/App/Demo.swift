import Foundation

/// "See a Demo" on the Not Paired screen: the app with a simulated computer, so anyone (App Review included) can try
/// every screen without Phone Use on a computer, a bridge or Screen Mirroring. Nothing goes over the network; each
/// change updates this sample state the way the computer would.
enum Demo {
    static let pcName = "Studio Mac"

    /// App Store screenshots (debug builds launched with -screenshots YES): the demo without its demo labels.
    static var forScreenshots: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "screenshots")
        #else
        false
        #endif
    }

    static let pairing = Pairing(id: "demo", name: pcName, host: "demo", port: 0, key: Data(count: 32))

    static var state: PCState {
        let json = """
        {"pc": {"id": "demo", "name": "\(pcName)", "receiver": "Phone Use on \(pcName)", "version": "demo"},
         "mirroring": true, "phone": "iPhone",
         "bluetooth": {"connected": true, "via": "bridge"},
         "agent": {"state": "driving", "action": "Checking the weather", "since": \(Int(Date().timeIntervalSince1970) - 40),
                   "steps": 3, "phase": "acting"},
         "awake": true,
         "audio": {"on": true, "needs_remirror": false},
         "session": {"ask": false, "mode": "countdown", "seconds": 10, "pending": null},
         "unlock": {"passcode_saved": false, "pending": null, "enabled": false},
         "bridge": {"saved": true, "id": "a1b2c3d47f2e", "ip": "192.168.1.42", "ssid": "Home", "use": true,
                    "online": true, "connected": true, "phone": "iPhone", "rtt_ms": 12,
                    "signal": {"wifi": "good", "phone": "good"}, "warning": null},
         "pc_bluetooth": {"on": false}}
        """
        return try! JSONDecoder().decode(PCState.self, from: Data(json.utf8))
    }

    static let networks = [BridgeNetwork(ssid: "Home", rssi: -48, secure: true),
                           BridgeNetwork(ssid: "Home Guest", rssi: -61, secure: true),
                           BridgeNetwork(ssid: "Café", rssi: -74, secure: false)]

    /// What the computer would do with one request: the new state, and its answer.
    static func apply(_ method: String, _ path: String, _ json: [String: Any]?, to s: inout PCState) -> [String: Any] {
        let on = json?["on"] as? Bool
        switch (method, path) {
        case ("POST", "/v1/awake"): s.awake = on ?? s.awake
        case ("POST", "/v1/mirror/audio"): s.audio.on = on ?? s.audio.on
        case ("POST", "/v1/bridge/use"):
            s.bridge?.use = on ?? true
            s.bluetooth.via = (on ?? true) ? "bridge" : "pc"
        case ("POST", "/v1/bridge/network"):
            if let ssid = json?["ssid"] as? String { s.bridge?.ssid = ssid }
        case ("DELETE", "/v1/bridge"):
            s.bridge = nil
            s.bluetooth = .init(connected: false, via: "pc")
            return ["saved": NSNull(), "reset": true]
        case ("POST", "/v1/agent/takeover"): s.agent.state = "paused"
        case ("POST", "/v1/agent/resume"): s.agent.state = "driving"
        case ("POST", "/v1/session/ask"):
            if let mode = json?["mode"] as? String { s.session?.mode = mode; s.session?.ask = mode == "ask" }
            if let seconds = json?["seconds"] as? Int { s.session?.seconds = seconds }
        case ("POST", "/v1/session/answer"):
            if json?["approve"] as? Bool == true { s.agent.state = "driving" }
            s.session?.pending = nil
        default: break  // the keyboard, push tokens: nothing to show
        }
        return ["ok": true]
    }
}
