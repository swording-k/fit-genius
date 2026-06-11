import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct HybridAIRoutingTests {
    static func main() {
        require(
            AIModelRouting.dietImageModel == AIModelRouting.textModel,
            "Diet image analysis should use the fast stable multimodal text model instead of the heavy VL model"
        )
        require(
            AIModelRouting.formSkeletonVisionModel == "qwen-vl-max",
            "Form skeleton enrichment should keep using qwen-vl-max"
        )

        let realFrame = Data([1, 2, 3])
        let skeletonFrame = Data([9, 9, 9])
        let presented = FormAnalysisChatPresentation.primaryFeedbackImageData(
            localFrameImageData: realFrame,
            enrichmentAnnotatedImageData: [skeletonFrame]
        )
        require(
            presented == realFrame,
            "AI Assistant should present the real video-frame feedback image, not skeleton-only enrichment images"
        )

        print("hybrid-ai-routing-tests: PASS")
    }
}
