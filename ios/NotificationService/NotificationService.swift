import UserNotifications

/// Opens the sealed text of session and unlock requests that come through the push relay (docs/PUSH-RELAY.md):
/// the relay sends a fixed title and body, and the PC's own ("Agent taking control in 10 s", the agent's action)
/// is in "sealed". The request ids are plain, so the Allow, Deny and Unlock actions work either way; without the
/// pairing key here (a build without the shared Keychain), the owner sees the fixed text.
final class NotificationService: UNNotificationServiceExtension {
    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler done: @escaping (UNNotificationContent) -> Void) {
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            return done(request.content)
        }
        if let sealed = content.userInfo["sealed"] as? String, let alert = PushRelay.open(sealed, ad: "alert") {
            if let title = alert["title"] as? String, !title.isEmpty { content.title = title }
            if let body = alert["body"] as? String, !body.isEmpty { content.body = body }
        }
        done(content)
    }
}
