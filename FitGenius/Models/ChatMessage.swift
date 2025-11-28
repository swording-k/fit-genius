import Foundation
import SwiftData

// MARK: - 聊天消息模型
@Model
final class ChatMessage {
    var id: UUID
    var content: String
    var isUser: Bool
    var timestamp: Date
    var isSystemAction: Bool // 是否是系统操作反馈
    
    init(content: String, isUser: Bool, isSystemAction: Bool = false) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
        self.isSystemAction = isSystemAction
    }
}

// MARK: - AI 操作指令模型
struct AIActionCommand: Codable {
    let type: String // "update_plan", "add_exercise", "remove_exercise"
    let actions: [Action]
    
    struct Action: Codable {
        let day: Int?
        let oldExercise: String?
        let newExercise: String?
        let exerciseName: String?
        let sets: Int?
        let reps: String?
        let weight: Double?
        let reason: String?
        
        enum CodingKeys: String, CodingKey {
            case day
            case oldExercise = "old_exercise"
            case newExercise = "new_exercise"
            case exerciseName = "exercise_name"
            case sets
            case reps
            case weight
            case reason
        }
    }
}
