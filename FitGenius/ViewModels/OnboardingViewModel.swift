import Foundation
import SwiftData
import Combine

// MARK: - Onboarding 步骤枚举
enum OnboardingStep: Int, CaseIterable {
    case basicInfo = 0
    case goalAndEnvironment = 1
    case equipment = 2
    case generating = 3
}

// MARK: - Onboarding ViewModel
@MainActor
class OnboardingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentStep: OnboardingStep = .basicInfo
    
    // 基本信息
    @Published var name: String = ""
    @Published var age: String = ""
    @Published var height: String = ""
    @Published var weight: String = ""
    @Published var injuries: String = ""
    
    // 目标和环境
    @Published var selectedGoal: FitnessGoal = .buildMuscle
    @Published var selectedEnvironment: WorkoutEnvironment = .gym
    
    // 器械选择
    @Published var selectedEquipment: Set<String> = []
    
    // 生成状态
    @Published var isGenerating = false
    @Published var generationProgress: String = "准备生成训练计划..."
    @Published var errorMessage: String?
    
    // MARK: - Services
    private let aiService = AIService()
    
    // MARK: - 常见器械列表
    let commonEquipment = [
        "哑铃", "杠铃", "卧推架", "深蹲架", "引体向上杆",
        "龙门架", "史密斯机", "腿举机", "腿弯举机", "腿屈伸机",
        "坐姿推胸机", "高位下拉机", "划船机", "蝴蝶机", "绳索",
        "壶铃", "弹力带", "瑜伽垫", "泡沫轴", "跑步机"
    ]
    
    // MARK: - 验证方法
    var canProceedFromBasicInfo: Bool {
        !name.isEmpty &&
        !age.isEmpty && Int(age) != nil &&
        !height.isEmpty && Double(height) != nil &&
        !weight.isEmpty && Double(weight) != nil
    }
    
    var canProceedFromGoalAndEnvironment: Bool {
        true // 已经有默认选择
    }
    
    var canProceedFromEquipment: Bool {
        selectedEnvironment == .home || selectedEnvironment == .outdoor || !selectedEquipment.isEmpty
    }
    
    // MARK: - 导航方法
    func nextStep() {
        guard let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = nextStep
    }
    
    func previousStep() {
        guard currentStep.rawValue > 0,
              let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previousStep
    }
    
    // MARK: - 器械选择辅助方法
    func toggleEquipment(_ equipment: String) {
        if selectedEquipment.contains(equipment) {
            selectedEquipment.remove(equipment)
        } else {
            selectedEquipment.insert(equipment)
        }
    }
    
    func selectAllEquipment() {
        selectedEquipment = Set(commonEquipment)
    }
    
    func clearAllEquipment() {
        selectedEquipment.removeAll()
    }
    
    // MARK: - 生成训练计划
    func generatePlan(context: ModelContext, completion: @escaping (Bool) -> Void) {
        guard let ageInt = Int(age),
              let heightDouble = Double(height),
              let weightDouble = Double(weight) else {
            errorMessage = "输入数据格式错误"
            completion(false)
            return
        }
        
        isGenerating = true
        errorMessage = nil
        generationProgress = "正在分析您的身体数据..."
        
        Task {
            do {
                // 创建用户资料
                let profile = UserProfile(
                    name: name,
                    age: ageInt,
                    height: heightDouble,
                    weight: weightDouble,
                    goal: selectedGoal,
                    environment: selectedEnvironment,
                    availableEquipment: Array(selectedEquipment),
                    injuries: injuries
                )
                
                // 更新进度
                await MainActor.run {
                    generationProgress = "正在向 AI 发送请求..."
                }
                
                // 调用 AI 服务
                let plan = try await aiService.generateInitialPlan(profile: profile)
                
                // 更新进度
                await MainActor.run {
                    generationProgress = "正在保存训练计划..."
                }
                
                // 保存到 SwiftData
                profile.workoutPlan = plan
                context.insert(profile)
                context.insert(plan)
                
                try context.save()
                
                // 完成
                await MainActor.run {
                    generationProgress = "完成！"
                    isGenerating = false
                    completion(true)
                }
                
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = error.localizedDescription
                    generationProgress = "生成失败"
                    completion(false)
                }
            }
        }
    }
}
