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
    
    // 目标（v1.5 多选）和环境
    @Published var selectedGoals: [FitnessGoal] = [.buildMuscle]
    @Published var selectedEnvironment: WorkoutEnvironment = .gym

    // v1.5 能力基线（可选，性别可空/不愿透露）
    @Published var selectedBiologicalSex: BiologicalSex? = nil
    @Published var selectedExperienceLevel: ExperienceLevel? = nil
    
    // 器械选择
    @Published var selectedEquipment: Set<String> = []
    
    // 生成状态
    @Published var isGenerating = false
    @Published var generationProgress: String = "准备生成训练计划..."
    @Published var errorMessage: String?
    @Published private(set) var pendingGeneratedPlan: WorkoutPlan?
    @Published private(set) var pendingGeneratedPlanErrors: [String] = []
    
    // MARK: - Services
    private let aiService = AIService()
    private var pendingGeneratedProfile: UserProfile?
    
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
        !selectedGoals.isEmpty // v1.5 至少选一个目标
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
                let descriptor = FetchDescriptor<UserProfile>()
                let existingProfiles = try context.fetch(descriptor)
                let currentPlan = try CurrentWorkoutPlanStore.ensureCurrentPlan(in: context)
                let profile = existingProfiles.first(where: { $0.workoutPlan === currentPlan })
                    ?? existingProfiles.first
                    ?? UserProfile(
                        name: name,
                        age: ageInt,
                        height: heightDouble,
                        weight: weightDouble,
                        goal: selectedGoals.first ?? .generalHealth,
                        environment: selectedEnvironment,
                        availableEquipment: Array(selectedEquipment),
                        injuries: notes
                    )

                profile.name = name
                profile.age = ageInt
                profile.height = heightDouble
                profile.weight = weightDouble
                profile.goal = selectedGoals.first ?? .generalHealth
                profile.environment = selectedEnvironment
                profile.availableEquipment = Array(selectedEquipment)
                profile.injuries = notes
                // v1.5 能力基线字段（纯加法，兼容旧单值 goal）
                profile.goals = selectedGoals
                profile.biologicalSex = selectedBiologicalSex
                profile.experienceLevel = selectedExperienceLevel
                if !existingProfiles.contains(where: { $0 === profile }) {
                    context.insert(profile)
                }

                // 先把真实资料与现有草稿关联并保存。AI 失败也绝不能删除手动计划。
                currentPlan.userProfile = profile
                profile.workoutPlan = currentPlan
                try context.save()

                // 更新进度
                await MainActor.run {
                    generationProgress = "正在向 AI 发送请求..."
                }

                print("🔍 [Onboarding] 开始调用 AI 生成计划...")
                
                // 按用户环境/器械筛选动作库，供 AI 生成计划时同源取用
                let catalog = ExerciseTemplate.catalog(for: profile, in: context)
                print("📚 [Onboarding] 注入动作库候选 \(catalog.count) 个")
                
                // 已有手动内容时，必须把它作为重构上下文；空草稿才从资料生成。
                let plan: WorkoutPlan
                if !(currentPlan.days ?? []).isEmpty {
                    plan = try await aiService.regeneratePlan(
                        profile: profile,
                        userRequest: "请根据最新用户资料优化计划，同时保留仍适用的手动训练日和动作。",
                        catalog: catalog
                    )
                } else {
                    plan = try await aiService.generateInitialPlan(profile: profile, catalog: catalog)
                }

                print("✅ [Onboarding] AI 返回计划：\(plan.name)，共 \((plan.days ?? []).count) 天")

                let validation = validateGeneratedPlan(plan)
                pendingGeneratedPlan = plan
                pendingGeneratedProfile = profile
                pendingGeneratedPlanErrors = validation.errors

                await MainActor.run {
                    generationProgress = validation.isValid
                        ? "plan_replacement_proposal_ready".localized
                        : "plan_edit_proposal_invalid".localized
                    isGenerating = false
                    completion(validation.isValid)
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

    func applyGeneratedPlan(context: ModelContext) throws {
        guard let plan = pendingGeneratedPlan,
              let profile = pendingGeneratedProfile else {
            throw NSError(
                domain: "Onboarding",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "plan_edit_proposal_invalid".localized]
            )
        }
        let validation = validateGeneratedPlan(plan)
        pendingGeneratedPlanErrors = validation.errors
        guard validation.isValid else {
            throw NSError(
                domain: "Onboarding",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "plan_edit_proposal_invalid".localized]
            )
        }

        context.insert(plan)
        plan.userProfile = profile
        profile.workoutPlan = plan
        try context.save()
        pendingGeneratedPlan = nil
        pendingGeneratedProfile = nil
        pendingGeneratedPlanErrors = []
    }

    func discardGeneratedPlan() {
        pendingGeneratedPlan = nil
        pendingGeneratedProfile = nil
        pendingGeneratedPlanErrors = []
        currentStep = .notes
    }

    private func validateGeneratedPlan(_ plan: WorkoutPlan) -> PlanEditValidationResult {
        let snapshot = PlanEditSnapshot(days: (plan.days ?? []).map { day in
            .init(
                dayNumber: day.dayNumber,
                isRestDay: day.isRestDay,
                exerciseNames: (day.exercises ?? []).map(\.name)
            )
        })
        var errors = PlanEditValidationPolicy.validateReplacement(snapshot).errors
        for exercise in (plan.days ?? []).flatMap({ $0.exercises ?? [] }) {
            if !(1...20).contains(exercise.sets) {
                errors.append("plan_edit_error_sets_range")
            }
            if exercise.weight < 0 {
                errors.append("plan_edit_error_weight_negative")
            }
            if exercise.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("plan_edit_error_reps_empty")
            }
        }
        return PlanEditValidationResult(errors: errors)
    }
}
