import Foundation

@main
struct ChatSessionPolicyTests {
    static func main() {
        let title = ChatSessionPolicy.title(
            firstUserMessage: "  Please review my bench press setup and elbow path.  ",
            fallback: "Earlier conversation",
            maxLength: 25
        )
        require(title == "Please review my bench...", "titles should be compact and trimmed")

        let blankTitle = ChatSessionPolicy.title(
            firstUserMessage: nil,
            fallback: "Earlier conversation",
            maxLength: 25
        )
        require(blankTitle == "Earlier conversation", "assistant-only sessions need a safe fallback title")

        let active = UUID()
        let older = UUID()
        let sessions = ChatSessionPolicy.orderedSessionIDs(
            entries: [
                .init(id: older, latestTimestamp: Date(timeIntervalSince1970: 100)),
                .init(id: nil, latestTimestamp: Date(timeIntervalSince1970: 200)),
                .init(id: active, latestTimestamp: Date(timeIntervalSince1970: 300))
            ],
            activeID: active
        )
        require(sessions == [active, nil, older], "active session should remain first, then history by recency")

        print("chat-session-policy-tests: PASS")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fatalError("FAIL: \(message)")
        }
    }
}
