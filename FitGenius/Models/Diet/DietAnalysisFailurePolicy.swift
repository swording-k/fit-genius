import Foundation

enum DietAnalysisFailureKind: Equatable {
    case reconnectRequired
    case fallbackSummary
}

enum DietAnalysisFailurePolicy {
    static func classify(isMissingSession: Bool) -> DietAnalysisFailureKind {
        isMissingSession ? .reconnectRequired : .fallbackSummary
    }
}
