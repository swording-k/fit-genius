import Foundation

/// Pure session-display rules kept outside SwiftData so the chat views can be
/// tested without a persistent store.
enum ChatSessionPolicy {
    struct Entry {
        let id: UUID?
        let latestTimestamp: Date
    }

    static func title(firstUserMessage: String?, fallback: String, maxLength: Int = 32) -> String {
        let trimmed = firstUserMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return fallback }
        guard trimmed.count > maxLength, maxLength > 3 else { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: maxLength - 3)
        return String(trimmed[..<end]) + "..."
    }

    static func orderedSessionIDs(entries: [Entry], activeID: UUID?) -> [UUID?] {
        entries.sorted { lhs, rhs in
            if lhs.id == activeID { return rhs.id != activeID }
            if rhs.id == activeID { return false }
            return lhs.latestTimestamp > rhs.latestTimestamp
        }.map(\.id)
    }
}

struct ChatConversationSummary: Identifiable {
    let sessionID: UUID?
    let title: String
    let updatedAt: Date

    var id: String { sessionID?.uuidString ?? "legacy" }
}
