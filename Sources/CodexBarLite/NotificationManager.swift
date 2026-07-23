import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private struct WindowState: Codable {
        let usedPercent: Int
        let resetAt: Int
    }

    private let center = UNUserNotificationCenter.current()
    private let settings: SettingsStore
    private let defaults = UserDefaults.standard

    init(settings: SettingsStore) {
        self.settings = settings
        super.init()
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() {
        guard settings.notificationsEnabled else { return }
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func evaluate(_ usage: CodexUsage) {
        evaluate(usage.rateLimit.primaryWindow, name: "Primary", key: "primary")
        if let secondary = usage.rateLimit.secondaryWindow {
            evaluate(secondary, name: "Secondary", key: "secondary")
        }
    }

    private func evaluate(_ window: UsageWindow, name: String, key: String) {
        let stateKey = "notificationState.\(key)"
        let previous = defaults.data(forKey: stateKey).flatMap { try? JSONDecoder().decode(WindowState.self, from: $0) }
        let current = WindowState(usedPercent: window.usedPercent, resetAt: window.resetAt)

        if let previous {
            if settings.notifyWhenReset, window.resetAt != previous.resetAt, window.usedPercent < previous.usedPercent {
                send(title: "\(name) credits reset", body: "Codex usage is back to \(100 - window.usedPercent)% remaining.", id: "\(key)-reset-\(window.resetAt)")
            } else {
                notifyThreshold(80, previous: previous.usedPercent, current: window.usedPercent, name: name, key: key, enabled: settings.notifyAt80)
                notifyThreshold(90, previous: previous.usedPercent, current: window.usedPercent, name: name, key: key, enabled: settings.notifyAt90)
                notifyThreshold(100, previous: previous.usedPercent, current: window.usedPercent, name: name, key: key, enabled: settings.notifyWhenExhausted)
            }
        }

        if let data = try? JSONEncoder().encode(current) {
            defaults.set(data, forKey: stateKey)
        }
    }

    private func notifyThreshold(_ threshold: Int, previous: Int, current: Int, name: String, key: String, enabled: Bool) {
        guard enabled, previous < threshold, current >= threshold else { return }
        let title = threshold == 100 ? "\(name) credits exhausted" : "\(name) usage reached \(threshold)%"
        let body = threshold == 100 ? "Codex has no remaining credits in this window." : "\(100 - current)% remains in this Codex window."
        send(title: title, body: body, id: "\(key)-\(threshold)-\(Date().timeIntervalSince1970)")
    }

    private func send(title: String, body: String, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
