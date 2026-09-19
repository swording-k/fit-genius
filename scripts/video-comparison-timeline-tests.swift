import Foundation

@main
struct VideoComparisonTimelineTests {
    static func main() {
        let timeline = VideoComparisonTimeline(
            referenceDuration: 12,
            userDuration: 10,
            referenceOffset: 2,
            userOffset: 1
        )

        require(timeline.commonDuration == 9, "the shorter remaining segment should define the shared timeline")
        require(timeline.referenceTime(progress: 0.5) == 6.5, "reference time should include its offset")
        require(timeline.userTime(progress: 0.5) == 5.5, "user time should include its offset")
        require(timeline.referenceTime(progress: -1) == 2, "negative progress should clamp to the reference start")
        require(timeline.userTime(progress: 2) == 10, "progress above one should clamp to the user end")
        require(timeline.clampedRate(0.4) == 0.5, "rate should snap to the nearest supported value")
        require(timeline.clampedRate(2) == 1, "rate must not exceed the supported maximum")

        let exhausted = VideoComparisonTimeline(
            referenceDuration: 3,
            userDuration: 4,
            referenceOffset: 5,
            userOffset: 0
        )
        require(exhausted.commonDuration == 0, "an offset beyond the video must produce an empty timeline")
        require(exhausted.referenceTime(progress: 0.5) == 3, "an excessive offset must clamp to the asset duration")

        print("video-comparison-timeline-tests: PASS")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError("FAIL: \(message)") }
    }
}
