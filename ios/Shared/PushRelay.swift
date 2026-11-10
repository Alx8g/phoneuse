import CryptoKit
import Foundation

/// The push relay (docs/PUSH-RELAY.md): it holds the APNs key for PCs that don't have one. The app registers
/// its push tokens there under an id and a key derived from the pairing key, and opens the sealed parts of
/// pushes (the agent's action, a warning's text, the PC's name) with another derived key the relay never gets.
enum PushRelay {
    static let base = URL(string: "https://phoneuse-push.lxe.workers.dev")!

    private static func derive(_ key: Data, _ info: String) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: key), salt: Data(), info: Data(info.utf8),
                               outputByteCount: 32)
    }

    static func relayKey(_ pairingKey: Data) -> Data {
        derive(pairingKey, "phoneuse relay").withUnsafeBytes { Data($0) }
    }

    /// The first 16 bytes of SHA-256(relay key), hex.
    static func relayId(_ pairingKey: Data) -> String {
        CompanionCrypto.hex(SHA256.hash(data: relayKey(pairingKey)).prefix(16))
    }

    static func pushSealKey(_ pairingKey: Data) -> SymmetricKey { derive(pairingKey, "phoneuse push seal") }

    /// The pairing key, read once a minute at most: the widget decodes the activity's state on every update.
    private static var cached: (key: Data?, at: Date) = (nil, .distantPast)
    private static let lock = NSLock()
    private static func pairingKey() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        if Date().timeIntervalSince(cached.at) > 60 { cached = (PairingStore.load()?.key, Date()) }
        return cached.key
    }

    /// Opens base64 of nonce(12) | ciphertext | tag(16), with `ad` as associated data, as a JSON object. Nil when
    /// there's no pairing key here (an extension without the shared Keychain) or it doesn't open.
    static func open(_ sealed: String, ad: String, key: Data? = nil) -> [String: Any]? {
        guard let key = key ?? pairingKey(), let raw = Data(base64Encoded: sealed),
              let box = try? AES.GCM.SealedBox(combined: raw),
              let plain = try? AES.GCM.open(box, using: pushSealKey(key), authenticating: Data(ad.utf8)) else {
            return nil
        }
        return (try? JSONSerialization.jsonObject(with: plain)) as? [String: Any]
    }

    /// Registers the app's tokens (the same fields as POST /v1/push to the PC). Returns whether the relay has
    /// them. The first registration of a pairing carries the relay key, which the relay checks against the id.
    static func register(_ fields: [String: Any], pairingKey: Data) async -> Bool {
        var status = await request("PUT", fields, pairingKey: pairingKey)
        if status == 404 {
            var first = fields
            first["key"] = relayKey(pairingKey).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            status = await request("PUT", first, pairingKey: pairingKey)
        }
        return status == 200
    }

    /// Asks the relay to forget this pairing's tokens (on unpair; they expire after 30 days anyway).
    static func unregister(pairingKey: Data) async {
        _ = await request("DELETE", nil, pairingKey: pairingKey)
    }

    private static func request(_ method: String, _ json: [String: Any]?, pairingKey: Data) async -> Int {
        let path = "/v1/phones/\(relayId(pairingKey))"
        let body = (json.flatMap { try? JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys]) }) ?? Data()
        let time = String(Int(Date().timeIntervalSince1970)), nonce = CompanionCrypto.randomNonceHex()
        guard let url = URL(string: base.absoluteString + path) else { return 0 }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = method
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(time, forHTTPHeaderField: "X-PU-Time")
        req.setValue(nonce, forHTTPHeaderField: "X-PU-Nonce")
        req.setValue(CompanionCrypto.signature(key: relayKey(pairingKey), method: method, path: path, time: time,
                                               nonce: nonce, body: body), forHTTPHeaderField: "X-PU-Sig")
        guard let (_, response) = try? await URLSession.shared.data(for: req) else { return 0 }
        return (response as? HTTPURLResponse)?.statusCode ?? 0
    }
}
