import Foundation
import ComposableArchitecture

@DependencyClient
struct NotificationClient {
    var requestAuthorization: @Sendable () async throws -> Bool = { true }
    var scheduleRitualReminder: @Sendable (Date) async throws -> Void
}

extension NotificationClient: DependencyKey {
    static let liveValue = NotificationClient(
        requestAuthorization: {
            try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        },
        scheduleRitualReminder: { date in
            let content = UNMutableNotificationContent()
            content.title = "Time for your ritual"
            content.body = "Breathe, hydrate, and reflect."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: date.timeIntervalSinceNow, repeats: false
            )
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            try await UNUserNotificationCenter.current().add(request)
        }
    )
}

import UserNotifications

extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
