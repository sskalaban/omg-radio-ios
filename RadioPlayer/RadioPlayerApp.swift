import SwiftUI
import UserNotifications

@main
struct RadioPlayerApp: App {
    private let alarmDelegate = AlarmNotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = alarmDelegate
        Task {
            await AlarmStore.shared.requestPermissionIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            StationListView()
                .preferredColorScheme(.dark)
        }
    }
}
