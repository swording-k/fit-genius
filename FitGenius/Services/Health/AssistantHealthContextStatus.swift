import Foundation

enum AssistantHealthContextStatus: Equatable {
    case disabled
    case needsRefresh
    case ready

    static func resolve(aiAccessEnabled: Bool, hasStoredHealthSummary: Bool) -> AssistantHealthContextStatus {
        guard aiAccessEnabled else { return .disabled }
        return hasStoredHealthSummary ? .ready : .needsRefresh
    }
}
