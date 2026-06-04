import Foundation

enum WatchPreparationState: Equatable {
    case unsupported
    case notPaired
    case appNotInstalled
    case ready
    case sent
    case unavailable

    var titleKey: String {
        switch self {
        case .unsupported, .notPaired:
            return "watch_companion_discover_title"
        case .appNotInstalled:
            return "watch_companion_install_title"
        case .ready:
            return "watch_companion_start_title"
        case .sent:
            return "watch_companion_sent_title"
        case .unavailable:
            return "watch_companion_unavailable_title"
        }
    }

    var detailKey: String {
        switch self {
        case .unsupported:
            return "watch_companion_unsupported_detail"
        case .notPaired:
            return "watch_companion_not_paired_detail"
        case .appNotInstalled:
            return "watch_companion_install_detail"
        case .ready:
            return "watch_companion_ready_detail"
        case .sent:
            return "watch_companion_sent_detail"
        case .unavailable:
            return "watch_companion_unavailable_detail"
        }
    }

    var symbolName: String {
        switch self {
        case .sent:
            return "checkmark.circle.fill"
        case .appNotInstalled, .notPaired, .unsupported:
            return "applewatch"
        case .ready, .unavailable:
            return "applewatch.and.arrow.forward"
        }
    }

    var canPrepareWorkout: Bool {
        self == .ready || self == .unavailable
    }
}
