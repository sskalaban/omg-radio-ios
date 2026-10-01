import Foundation
import UserNotifications

/// Конфиг будильника (зеркало Android AlarmConfig).
struct AlarmConfig: Codable {
    var enabled: Bool = false
    var minutesOfDay: Int = 7 * 60        // 07:00
    var days: Set<Int> = [1, 2, 3, 4, 5, 6, 7]  // 1=Пн .. 7=Вс
    var stationNid: String = ""
    var volume: Float = 0.7               // 0..1
    var fadeIn: Bool = true

    var timeLabel: String {
        String(format: "%02d:%02d", minutesOfDay / 60, minutesOfDay % 60)
    }

    /// Сегодняшний день выбран, но заданное время уже прошло:
    /// в этом случае будильник срабатывает сразу после установки, а не завтра
    /// (зеркало Android AlarmConfig.isTodaySelectedButPassed).
    var isTodaySelectedButPassed: Bool {
        guard !days.isEmpty else { return false }
        let now = Date()
        let cal = Calendar.current
        // Apple weekday: 1=Вс, 2=Пн..7=Сб → наши 1=Пн..7=Вс
        let appleWeekday = cal.component(.weekday, from: now)
        let mappedToday = appleWeekday == 1 ? 7 : appleWeekday - 1
        guard days.contains(mappedToday) else { return false }
        let nowMinutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        return minutesOfDay <= nowMinutes
    }
}

/// Хранение конфига и планирование локальных уведомлений.
/// На iOS приложение не может само включить звук из фона —
/// в назначенное время приходит уведомление, по тапу запускается станция.
final class AlarmStore: ObservableObject {
    static let shared = AlarmStore()

    @Published private(set) var config: AlarmConfig

    private let key = "omg_alarm_config"
    private let center = UNUserNotificationCenter.current()

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AlarmConfig.self, from: data) {
            config = decoded
        } else {
            config = AlarmConfig()
        }
    }

    func saveAndSchedule(_ newConfig: AlarmConfig) {
        config = newConfig
        if let data = try? JSONEncoder().encode(newConfig) {
            UserDefaults.standard.set(data, forKey: key)
        }
        Task { await reschedule() }
    }

    func requestPermissionIfNeeded() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    private func reschedule() async {
        center.removeAllPendingNotificationRequests()
        guard config.enabled, !config.days.isEmpty else { return }

        // Время сегодня уже прошло, но день выбран — разовое срабатывание
        // через минуту (не переносим на следующий день, как просил заказчик)
        if config.isTodaySelectedButPassed {
            let content = makeContent()
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
            let request = UNNotificationRequest(
                identifier: "omg-alarm-now",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }

        for day in config.days {
            let content = makeContent()

            var comps = DateComponents()
            comps.hour = config.minutesOfDay / 60
            comps.minute = config.minutesOfDay % 60
            // Наши дни 1=Пн..7=Вс → Apple weekday 1=Вс, 2=Пн..7=Сб
            comps.weekday = day == 7 ? 1 : day + 1

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(
                identifier: "omg-alarm-\(day)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private func makeContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "OMG Radio"
        content.body = "Будильник \(config.timeLabel). Нажмите, чтобы включить радио"
        content.sound = .default
        content.userInfo = [
            "stationNid": config.stationNid,
            "volume": config.volume,
            "fadeIn": config.fadeIn,
        ]
        return content
    }
}

/// Обработка тапа по уведомлению будильника.
final class AlarmNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let nid = info["stationNid"] as? String ?? ""
        let volume = (info["volume"] as? NSNumber)?.floatValue ?? 0.7
        let fade = (info["fadeIn"] as? NSNumber)?.boolValue ?? true
        await MainActor.run {
            PlayerManager.shared.playAlarm(stationNid: nid, volume: volume, fadeIn: fade)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
