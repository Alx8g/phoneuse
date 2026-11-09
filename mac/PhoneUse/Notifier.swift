import Foundation
import UserNotifications

/// Agent requests as Mac notifications with their answers as buttons, like the Linux app's desktop
/// notifications (notify-send there). An answer goes back through the same routes the browser page uses.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()
    private let center = UNUserNotificationCenter.current()
    private var shown: Set<String> = []   // notification ids on screen

    func setUp() {
        center.delegate = self
        let allow = UNNotificationAction(identifier: "allow", title: "Allow", options: [])
        let deny = UNNotificationAction(identifier: "deny", title: "Deny", options: [.destructive])
        let allowNow = UNNotificationAction(identifier: "allow", title: "Allow now", options: [])
        let cancel = UNNotificationAction(identifier: "deny", title: "Cancel", options: [.destructive])
        let unlock = UNNotificationAction(identifier: "allow", title: "Unlock", options: [.authenticationRequired])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: "session", actions: [allow, deny], intentIdentifiers: []),
            UNNotificationCategory(identifier: "countdown", actions: [allowNow, cancel], intentIdentifiers: []),
            UNNotificationCategory(identifier: "unlock", actions: [unlock, deny], intentIdentifiers: []),
        ])
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Shows each new request once and removes the ones that are over.
    @MainActor func show(_ r: Requests?) {
        var now: Set<String> = []
        if let s = r?.session {
            let id = "session-\(s.id)"
            now.insert(id)
            if !shown.contains(id) {
                let c = UNMutableNotificationContent()
                if let d = s.deadline {
                    c.title = "Agent taking control in \(max(0, Int((d - Date().timeIntervalSince1970).rounded()))) s"
                    c.categoryIdentifier = "countdown"
                } else {
                    c.title = "Agent requests control"
                    c.categoryIdentifier = "session"
                }
                c.body = s.action?.isEmpty == false ? s.action! : "Using the phone"
                c.sound = .default
                c.interruptionLevel = .timeSensitive
                c.userInfo = ["kind": "session", "id": s.id]
                center.add(UNNotificationRequest(identifier: id, content: c, trigger: nil))
            }
        }
        if let u = r?.unlock {
            let id = "unlock-\(u.id)"
            now.insert(id)
            if !shown.contains(id) {
                let c = UNMutableNotificationContent()
                c.title = "Unlock the iPhone?"
                c.body = "An agent asks to enter your saved passcode."
                c.categoryIdentifier = "unlock"
                c.sound = .default
                c.interruptionLevel = .timeSensitive
                c.userInfo = ["kind": "unlock", "id": u.id]
                center.add(UNNotificationRequest(identifier: id, content: c, trigger: nil))
            }
        }
        let over = shown.subtracting(now)
        if !over.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: Array(over))
            center.removePendingNotificationRequests(withIdentifiers: Array(over))
        }
        shown = now
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done([.banner, .sound, .list])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler done: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        guard let kind = info["kind"] as? String, let id = info["id"] as? String,
              ["allow", "deny"].contains(response.actionIdentifier) else {
            done()
            return
        }
        let approve = response.actionIdentifier == "allow"
        Task { @MainActor in
            try? await Core.shared.send(kind == "unlock" ? "/api/unlock/answer" : "/api/session/answer",
                                        ["id": id, "approve": approve])
            await Core.shared.refresh()
            done()
        }
    }
}
