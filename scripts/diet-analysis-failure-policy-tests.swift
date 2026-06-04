import Foundation

@main
struct DietAnalysisFailurePolicyTests {
    static func main() {
        precondition(
            DietAnalysisFailurePolicy.classify(isMissingSession: true) == .reconnectRequired,
            "A missing backend session must ask the user to reconnect instead of claiming AI is unavailable"
        )
        precondition(
            DietAnalysisFailurePolicy.classify(isMissingSession: false) == .fallbackSummary,
            "Other failures may preserve a local summary"
        )
        print("Diet analysis failure policy tests passed")
    }
}
