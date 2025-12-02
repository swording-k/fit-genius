import Foundation
import SwiftData
import Combine

// MARK: - Onboarding 步骤枚举
enum OnboardingStep: Int, CaseIterable {
    case basicInfo = 0
    case goalAndEnvironment = 1
    case equipment = 2
    case notes = 3
    case generating = 4
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
    @Published var notes: String = ""  // 备注（包括伤病、额外器械等）
    
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
                // 🔧 修复：删除所有旧 profile，总是创建新的
                print("🗑️ [Onboarding] 删除所有旧 profile...")
                let descriptor = FetchDescriptor<UserProfile>()
                let existing = try? context.fetch(descriptor)
                existing?.forEach { oldProfile in
                    print("🗑️ [Onboarding] 删除旧 profile: \(oldProfile.name)")
                    context.delete(oldProfile)
                }
                
                // 创建新 profile
                print("✨ [Onboarding] 创建新 profile...")
                let profile = UserProfile(
                    name: name,
                    age: ageInt,
                    height: heightDouble,
                    weight: weightDouble,
                    goal: selectedGoal,
                    environment: selectedEnvironment,
                    availableEquipment: Array(selectedEquipment),
                    injuries: notes
                )
                context.insert(profile)
                print("✅ [Onboarding] Profile 已插入到 context")
                print("🔍 [Onboarding] ModelContext: \(context)")
                print("🔍 [Onboarding] ModelContainer: \(context.container)")
                if let url = context.container.configurations.first?.url {
                    print("🔍 [Onboarding] Container URL: \(url.path)")
                } else {
                    print("🔍 [Onboarding] Container URL: nil")
                }
                
                
                // 更新进度
                await MainActor.run {
                    generationProgress = "正在向 AI 发送请求..."
                }
                
                print("🔍 [Onboarding] 开始调用 AI 生成计划...")
                
                // 调用 AI 服务
                let plan = try await aiService.generateInitialPlan(profile: profile)
                
                print("✅ [Onboarding] AI 返回计划：\(plan.name)，共 \((plan.days ?? []).count) 天")
                
                // 更新进度
                await MainActor.run {
                    generationProgress = "正在保存训练计划..."
                }
                
                print("💾 [Onboarding] 开始保存计划到 SwiftData...")
                
                // 保存到 SwiftData（建立关系并插入计划）
                plan.userProfile = profile
                profile.workoutPlan = plan
                context.insert(plan)
                print("💾 [Onboarding] 计划已插入，准备保存...")
                
                try context.save()
                
                print("✅ [Onboarding] SwiftData 保存成功！")
                
                // 🔍 立即验证数据是否真的保存了
                print("🔍 [Onboarding] 开始验证数据...")
                let verifyDescriptor = FetchDescriptor<UserProfile>()
                let savedProfiles = try context.fetch(verifyDescriptor)
                print("🔍 [Onboarding] 查询到 \(savedProfiles.count) 个 profile")
                
                if let savedProfile = savedProfiles.first {
                    print("🔍 [Onboarding] Profile: \(savedProfile.name)")
                    print("🔍 [Onboarding] 有计划: \(savedProfile.workoutPlan != nil)")
                    if let savedPlan = savedProfile.workoutPlan {
                        print("🔍 [Onboarding] 计划名称: \(savedPlan.name)")
                        print("🔍 [Onboarding] 计划天数: \((savedPlan.days ?? []).count)")
                    } else {
                        print("❌ [Onboarding] 警告：Profile 存在但没有关联计划！")
                    }
                } else {
                    print("❌ [Onboarding] 严重错误：保存后立即查询不到 Profile！")
                }
                
                // 打印计划详情
                print("📊 [Onboarding] 计划详情：")
                print("   - 计划名称：\(plan.name)")
                print("   - 训练天数：\(plan.days?.count ?? 0)") // This line was not part of the instruction, keeping original logic
                for day in plan.days ?? [] { // This line was not part of the instruction, keeping original logic
                    print("   - Day \(day.dayNumber): \(day.focus.localizedName), 动作数：\(day.exercises.count), 休息日：\(day.isRestDay)")
                }
                
                // 完成
                await MainActor.run {
                    generationProgress = "完成！"
                    isGenerating = false
                    completion((plan.days ?? []).count > 0)
                }
                
            } catch {
                print("❌ [Onboarding] 生成计划失败：\(error)")
                print("❌ [Onboarding] 错误详情：\(error.localizedDescription)")
                
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
