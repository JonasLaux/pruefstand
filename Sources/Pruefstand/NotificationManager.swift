import Foundation
import UserNotifications
import AppKit

/// Posts native notifications for newly-appeared review-needed PRs.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Diff `current` against the persisted seen-set, notify on new ids, then
    /// update the seen-set. Notifications are gated by the pause flag; the
    /// seen-set updates regardless so resuming never floods.
    @MainActor
    func process(current: [PullRequest], settings: Settings) {
        let currentIds = Set(current.map(\.id))
        let newIds = currentIds.subtracting(settings.seenPRIds)

        if settings.notificationsEnabled && !settings.notificationsPaused {
            for pr in current where newIds.contains(pr.id) {
                post(pr)
            }
        }
        settings.seenPRIds = currentIds
    }

    private func post(_ pr: PullRequest) {
        let content = UNMutableNotificationContent()
        content.title = "New PR to review"
        content.body = "\(pr.repo) #\(pr.number): \(pr.title)"
        content.sound = .default
        content.userInfo = ["url": pr.url]

        let request = UNNotificationRequest(
            identifier: pr.id,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // Show notifications even when the app is frontmost.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // Open the PR when the notification is clicked.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let urlString = response.notification.request.content.userInfo["url"] as? String,
           let url = URL(string: urlString) {
            DispatchQueue.main.async { NSWorkspace.shared.open(url) }
        }
        completionHandler()
    }
}
