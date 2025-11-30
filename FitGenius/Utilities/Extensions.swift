// Array 安全下标扩展
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

import Foundation
extension Notification.Name {
    static let dietSummaryUpdated = Notification.Name("DietSummaryUpdated")
}
