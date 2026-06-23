import Foundation

enum AIResponseFormatter {
    static func displayText(from rawText: String) -> String {
        var lines = rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        lines = lines.compactMap { line in
            var text = line.trimmingCharacters(in: .whitespaces)
            if text.hasPrefix("```") {
                return nil
            }

            while text.hasPrefix("#") {
                text.removeFirst()
                text = text.trimmingCharacters(in: .whitespaces)
            }

            if text.hasPrefix("- ") || text.hasPrefix("* ") {
                text = "• " + text.dropFirst(2)
            }

            text = text
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "__", with: "")
                .replacingOccurrences(of: "`", with: "")

            return text
        }

        return collapseBlankLines(lines.joined(separator: "\n"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func collapseBlankLines(_ text: String) -> String {
        var output: [String] = []
        var previousWasBlank = false

        for line in text.components(separatedBy: "\n") {
            let isBlank = line.trimmingCharacters(in: .whitespaces).isEmpty
            if isBlank && previousWasBlank {
                continue
            }
            output.append(line)
            previousWasBlank = isBlank
        }

        return output.joined(separator: "\n")
    }
}
