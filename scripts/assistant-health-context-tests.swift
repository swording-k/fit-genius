import Foundation

@main
struct AssistantHealthContextTests {
    static func main() throws {
        require(
            AssistantHealthContextStatus.resolve(aiAccessEnabled: false, hasStoredHealthSummary: true) == .disabled,
            "privacy switch must take precedence over stored data"
        )
        require(
            AssistantHealthContextStatus.resolve(aiAccessEnabled: true, hasStoredHealthSummary: false) == .needsRefresh,
            "enabled AI without a report must explain that a refresh is needed"
        )
        require(
            AssistantHealthContextStatus.resolve(aiAccessEnabled: true, hasStoredHealthSummary: true) == .ready,
            "AI may use health context only after an authorized summary exists"
        )

        for path in [
            "FitGenius/Views/Assistant/AIAssistantView.swift",
            "FitGenius/Views/Diet/DietAIAssistantView.swift"
        ] {
            let source = try String(contentsOfFile: path, encoding: .utf8)
            require(!source.contains(".hidesGlobalModeToggle()"), "\(path) must keep the global mode toggle available")
            let duplicateTitle = path.contains("Diet") ? ".navigationTitle(\"diet_ai_assistant\")" : ".navigationTitle(\"ai_assistant\")"
            require(!source.contains(duplicateTitle), "\(path) must not add a second title above the mode switcher")
        }

        print("assistant-health-context-tests: PASS")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError("FAIL: \(message)") }
    }
}
