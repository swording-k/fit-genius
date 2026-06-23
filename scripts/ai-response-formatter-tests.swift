import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct AIResponseFormatterTests {
    static func main() {
        let markdown = """
        # 卧推建议

        **重点问题**：手腕需要稳定
        * 收紧肩胛
        - 前臂保持接近垂直
        ```json
        {"debug":true}
        ```
        """

        let cleaned = AIResponseFormatter.displayText(from: markdown)
        expect(!cleaned.contains("#"), "Heading markers should be removed")
        expect(!cleaned.contains("**"), "Bold markers should be removed")
        expect(!cleaned.contains("```"), "Code fences should be removed")
        expect(cleaned.contains("卧推建议"), "Heading text should remain")
        expect(cleaned.contains("• 收紧肩胛"), "Asterisk list markers should become readable bullets")
        expect(cleaned.contains("• 前臂保持接近垂直"), "Dash list markers should become readable bullets")

        let compact = AIResponseFormatter.displayText(from: "第一段\n\n\n\n第二段")
        expect(!compact.contains("\n\n\n"), "Excess blank lines should be collapsed")

        print("AI response formatter tests passed")
    }
}
