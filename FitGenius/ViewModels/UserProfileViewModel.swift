import Foundation
import SwiftData
import Combine

// MARK: - 用户资料 ViewModel
@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var isGenerating = false
    @Published var errorMessage: String?
    
    private let aiService = AIService()
    
    // 生成训练计划
    func generatePlan(for profile: UserProfile, context: ModelContext) async {
        isGenerating = true
        errorMessage = nil
        
        do {
            // 调用 AI 服务生成计划
            let plan = try await aiService.generateInitialPlan(profile: profile)
            
            // 保存到 SwiftData
            profile.workoutPlan = plan
            context.insert(plan)
            
            try context.save()
            
            isGenerating = false
        } catch {
            isGenerating = false
            errorMessage = error.localizedDescription
        }
    }
}
