import Foundation

/// Deterministic matching between a free-form plan exercise name and the
/// exercise-library catalog. It deliberately rejects ambiguous partial matches.
enum ExerciseTemplateResolver {
    struct Candidate: Hashable {
        let id: String
        let names: [String]
    }

    private static let reviewedAliases: [String: [String]] = [
        normalize("卧推"): ["barbell bench press", "杠铃卧推"],
        normalize("深蹲"): ["barbell squat", "杠铃深蹲"],
        normalize("硬拉"): ["barbell deadlift", "杠铃硬拉"],
        normalize("推举"): ["barbell standing military press", "standing overhead press", "站姿推举"],
        normalize("俯卧撑"): ["push-up", "push up", "俯卧撑"],
        normalize("引体向上"): ["pull-up", "pull up", "引体向上"]
    ]

    static func resolve(_ rawName: String, in candidates: [Candidate]) -> String? {
        let target = normalize(rawName)
        guard !target.isEmpty else { return nil }

        let exact = candidates.filter { candidate in
            candidate.names.contains { normalize($0) == target }
        }
        if exact.count == 1 { return exact[0].id }
        if exact.count > 1 { return nil }

        if let aliases = reviewedAliases[target] {
            let normalizedAliases = Set(aliases.map(normalize))
            let aliasMatches = candidates.filter { candidate in
                candidate.names.contains { normalizedAliases.contains(normalize($0)) }
            }
            if aliasMatches.count == 1 { return aliasMatches[0].id }
            if aliasMatches.count > 1 { return nil }
        }

        let partial = candidates.filter { candidate in
            candidate.names.contains { name in
                let normalizedName = normalize(name)
                return normalizedName.contains(target) || target.contains(normalizedName)
            }
        }
        return partial.count == 1 ? partial[0].id : nil
    }

    static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
            .lowercased()
    }
}
