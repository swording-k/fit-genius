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
            AIModelRouting.textModel == "fitgenius-text",
            "Text requests should use the provider-neutral backend alias"
        )
        require(
            AIModelRouting.dietImageModel == "fitgenius-vision",
            "Diet image analysis should use the provider-neutral vision alias"
        )
        require(
            AIModelRouting.fitnessImageModel == "fitgenius-vision",
            "Fitness images should use the provider-neutral vision alias"
        )
        require(
            AIModelRouting.fitnessVideoModel == "fitgenius-video",
            "Fitness videos should use the provider-neutral video alias"
        )
        require(
            AIModelRouting.formSkeletonVisionModel == "fitgenius-vision",
            "Form skeleton enrichment should use the provider-neutral vision alias"
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
