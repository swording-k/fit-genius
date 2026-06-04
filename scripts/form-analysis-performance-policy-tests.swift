import Foundation

@main
struct FormAnalysisPerformancePolicyTests {
    static func main() {
        guard FormAnalysisPerformancePolicy.extractionMaxDimension <= 720 else {
            fputs("FAIL: pose extraction should not decode full-resolution 4K frames\n", stderr)
            exit(1)
        }
        guard FormAnalysisPerformancePolicy.feedbackMaxDimension <= 1600 else {
            fputs("FAIL: annotated feedback should be bounded for chat rendering\n", stderr)
            exit(1)
        }
        print("form-analysis-performance-policy-tests: PASS")
    }
}
