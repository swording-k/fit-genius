import Foundation

extension String {
    func truncatedForAIContext(maxLength: Int) -> String {
        guard count > maxLength else { return self }
        let end = index(startIndex, offsetBy: maxLength)
        return String(self[..<end]) + "..."
    }
}
