import Foundation

@main
struct WatchPreparationStateTests {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() {
        expect(WatchPreparationState.ready.canPrepareWorkout, "ready Watch should allow preparation")
        expect(WatchPreparationState.unavailable.canPrepareWorkout, "installed but unreachable Watch should allow queued preparation")
        expect(!WatchPreparationState.appNotInstalled.canPrepareWorkout, "missing Watch app should not allow preparation")
        expect(WatchPreparationState.appNotInstalled.titleKey == "watch_companion_install_title", "missing app should expose install guidance")
        expect(WatchPreparationState.sent.symbolName == "checkmark.circle.fill", "sent state should expose success feedback")
        print("Watch preparation state tests passed")
    }
}
