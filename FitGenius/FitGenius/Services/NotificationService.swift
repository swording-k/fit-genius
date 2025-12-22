import Foundation
import UserNotifications

final class NotificationService {
    static let center = UNUserNotificationCenter.current()

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                cont.resume(returning: granted)
            }
        }
    }

    static func scheduleTrainingReminders(plan: WorkoutPlan, hour: Int = 19) {
        center.removeAllPendingNotificationRequests()
        let days = (plan.days ?? []).sorted { $0.dayNumber < $1.dayNumber }
        for day in days {
            if day.isRestDay { continue }
            let date = plan.getDateForDay(dayNumber: day.dayNumber)
            var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            comps.hour = hour
            comps.minute = 0
            guard let y = comps.year, let m = comps.month, let d = comps.day else { continue }
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let content = UNMutableNotificationContent()
            content.title = "今日训练：\(day.focus.localizedName)"
            let count = (day.exercises ?? []).count
            content.body = count > 0 ? "共有 \(count) 个动作，记得按时训练" : "记得训练"
            content.sound = .default
            let id = "training-\(y)-\(m)-\(d)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(request)
        }
    }

    static func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}