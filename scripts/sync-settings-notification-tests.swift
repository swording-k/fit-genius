import Foundation

@main
struct SyncSettingsNotificationTests {
    static func main() {
        let suite = "SyncSettingsNotificationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SyncSettings(defaults: defaults)
        var notifications = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .backendSessionChanged,
            object: nil,
            queue: nil
        ) { _ in
            notifications += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        settings.setSessionToken("token", userId: "user")
        settings.setSessionToken(nil, userId: nil)

        guard notifications == 2 else {
            fputs("FAIL: session changes should notify observers\n", stderr)
            exit(1)
        }
        print("sync-settings-notification-tests: PASS")
    }
}
