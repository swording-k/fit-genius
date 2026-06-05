import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct AppLanguagePolicyTests {
    static func main() {
        let chinese = AppLanguagePolicy(preferredLanguageIdentifier: "zh-Hans-CN")
        expect(chinese.prefersSimplifiedChinese, "Simplified Chinese should be detected")
        expect(chinese.speechLocaleIdentifier == "zh-CN", "Chinese speech recognition should use zh-CN")
        expect(chinese.responseLanguageInstruction.contains("简体中文"), "Chinese AI instruction should request Simplified Chinese")

        let english = AppLanguagePolicy(preferredLanguageIdentifier: "en-US")
        expect(!english.prefersSimplifiedChinese, "English should not be detected as Simplified Chinese")
        expect(english.speechLocaleIdentifier == "en-US", "English speech recognition should use en-US")
        expect(english.responseLanguageInstruction.contains("English"), "English AI instruction should request English")
        expect(english.responseLanguageInstruction.contains("Do not use Chinese"), "English AI instruction should explicitly ban Chinese visible text")
        expect(english.planContentInstruction.contains("name"), "English plan instruction should mention visible JSON fields")
        expect(english.planContentInstruction.contains("focus field is an internal contract"), "English plan instruction should keep focus as an internal enum")
        expect(english.workoutPlanJSONExample.contains("Barbell Bench Press"), "English plan example should use English exercise names")
        expect(!english.workoutPlanJSONExample.contains("杠铃卧推"), "English plan example should not contain Chinese exercise names")
        expect(english.dietAnalyzeSystemPrompt.contains("Return raw JSON only"), "English diet analysis prompt should be English")
        expect(!english.dietAnalyzeSystemPrompt.contains("你是一个专业"), "English diet analysis prompt should not start from Chinese role text")
        expect(english.fitnessMediaSystemPrompt.contains("professional personal trainer"), "English media prompt should be English")

        let traditionalChinese = AppLanguagePolicy(preferredLanguageIdentifier: "zh-Hant-TW")
        expect(!traditionalChinese.prefersSimplifiedChinese, "Traditional Chinese should currently use the English fallback")

        print("App language policy tests passed")
    }
}
