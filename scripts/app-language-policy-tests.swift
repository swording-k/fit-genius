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

        let traditionalChinese = AppLanguagePolicy(preferredLanguageIdentifier: "zh-Hant-TW")
        expect(!traditionalChinese.prefersSimplifiedChinese, "Traditional Chinese should currently use the English fallback")

        print("App language policy tests passed")
    }
}
