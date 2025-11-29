import Foundation
import SwiftData
import Combine

// MARK: - AI 助手 ViewModel
@MainActor
class AIAssistantViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showPlanRegenerationAlert: Bool = false
    @Published var pendingUserMessage: String = ""
    @Published var suggestionOnly: Bool = true
    
    private let aiService = AIService()
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // 添加欢迎消息
        let welcomeMessage = ChatMessage(
            content: "你好！我是你的 AI 健身助手。你可以向我咨询健身建议，或者让我帮你调整训练计划。例如：\n\n• \"我膝盖疼，能把深蹲换掉吗？\"\n• \"增加一个练背的动作\"\n• \"第三天太累了，删掉一个动作\"",
            isUser: false
        )
        messages.append(welcomeMessage)
    }
    
    // MARK: - 检测修改类型
    private func detectModificationType(userMessage: String) -> Bool {
        // 计划级别修改的关键词
        let planLevelKeywords = [
            "分化", "循环", "天数", "改为.*天", "删除.*天", "增加.*天",
            "变成.*天", "调整.*天", ".*分化.*改.*分化"
        ]
        
        for keyword in planLevelKeywords {
            if userMessage.range(of: keyword, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - 发送消息
    func sendMessage(profile: UserProfile, plan: WorkoutPlan) async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = inputText
        inputText = ""
        
        // 添加用户消息
        let userChatMessage = ChatMessage(content: userMessage, isUser: true)
        messages.append(userChatMessage)
        
        // 检测是否是计划级别修改
        if detectModificationType(userMessage: userMessage) {
            if suggestionOnly {
                // 建议模式：提供文字建议，不进行计划改动
                await provideSuggestionOnly(userMessage: userMessage, profile: profile, plan: plan)
                return
            } else {
                // 编辑模式：显示确认对话框并可能重生成
                pendingUserMessage = userMessage
                showPlanRegenerationAlert = true
                return
            }
        }
        
        // 动作级别修改
        await processExerciseLevelModification(userMessage: userMessage, profile: profile, plan: plan)
    }
    
    // MARK: - 建议模式：仅提供文字建议
    private func provideSuggestionOnly(userMessage: String, profile: UserProfile, plan: WorkoutPlan) async {
        isLoading = true
        errorMessage = nil
        do {
            let (response, _) = try await aiService.chat(
                userMessage: "【请只提供建议，不要返回任何 JSON 指令或修改计划】\n" + userMessage,
                profile: profile,
                plan: plan
            )
            let tip = ChatMessage(content: "已启用建议模式：我只会给出文字建议，你可在训练页自行调整。", isUser: false, isSystemAction: true)
            messages.append(tip)
            if !response.isEmpty {
                let aiMessage = ChatMessage(content: response, isUser: false)
                messages.append(aiMessage)
            }
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            let errMsg = ChatMessage(content: "抱歉，生成建议失败：\(error.localizedDescription)", isUser: false)
            messages.append(errMsg)
        }
    }
    // MARK: - 处理动作级别修改
    private func processExerciseLevelModification(userMessage: String, profile: UserProfile, plan: WorkoutPlan) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 调用 AI 服务
            let (response, command) = try await aiService.chat(
                userMessage: userMessage,
                profile: profile,
                plan: plan
            )
            
            // 如果有操作指令，执行它
            if let command = command {
                let feedbackMessage = try executeCommand(command, plan: plan)
                
                // 添加系统反馈消息
                let systemMessage = ChatMessage(
                    content: feedbackMessage,
                    isUser: false,
                    isSystemAction: true
                )
                messages.append(systemMessage)
            } else if !response.isEmpty {
                // 普通文本回复
                let aiMessage = ChatMessage(content: response, isUser: false)
                messages.append(aiMessage)
            }
            
            isLoading = false
            
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            
            let errorChatMessage = ChatMessage(
                content: "抱歉，出现了错误：\(error.localizedDescription)",
                isUser: false
            )
            messages.append(errorChatMessage)
        }
    }
    
    // MARK: - 重新生成计划
    func regeneratePlan(profile: UserProfile) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 调用 AI 服务重新生成计划
            let newPlan = try await aiService.regeneratePlan(
                profile: profile,
                userRequest: pendingUserMessage
            )
            
            // 先持久化新计划，不改变现有链接，避免空状态闪断
            modelContext.insert(newPlan)
            try modelContext.save()
            
            // 验证新计划有效后再切换链接
            let oldPlan = profile.workoutPlan
            guard !newPlan.days.isEmpty else {
                throw NSError(domain: "AIAssistant", code: -1, userInfo: [NSLocalizedDescriptionKey: "生成的计划为空，请稍后重试"])
            }
            profile.workoutPlan = newPlan
            try modelContext.save()
            
            // 不删除旧计划，保留为备份
            
            // 添加成功消息
            let successMessage = ChatMessage(
                content: "✅ 已根据您的要求重新生成训练计划！新计划已应用。",
                isUser: false,
                isSystemAction: true
            )
            messages.append(successMessage)
            
            isLoading = false
            
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            
            let errorChatMessage = ChatMessage(
                content: "抱歉，重新生成计划失败：\(error.localizedDescription)",
                isUser: false
            )
            messages.append(errorChatMessage)
        }
    }
    
    // MARK: - 执行 AI 操作指令
    private func executeCommand(_ command: AIActionCommand, plan: WorkoutPlan) throws -> String {
        var feedbackMessages: [String] = []
        
        for action in command.actions {
            switch command.type {
            case "update_plan":
                if let feedback = updateExercise(action: action, plan: plan) {
                    feedbackMessages.append(feedback)
                }
                
            case "add_exercise":
                if let feedback = addExercise(action: action, plan: plan) {
                    feedbackMessages.append(feedback)
                }
                
            case "remove_exercise":
                if let feedback = removeExercise(action: action, plan: plan) {
                    feedbackMessages.append(feedback)
                }
                
            default:
                feedbackMessages.append("未知的操作类型：\(command.type)")
            }
        }
        
        // 保存修改
        try modelContext.save()
        
        return feedbackMessages.isEmpty ? "操作完成" : feedbackMessages.joined(separator: "\n")
    }
    
    // MARK: - 更新动作
    private func updateExercise(action: AIActionCommand.Action, plan: WorkoutPlan) -> String? {
        guard let dayNumber = action.day,
              let oldName = action.oldExercise,
              let newName = action.newExercise else {
            return nil
        }
        
        // 找到对应的训练日
        guard let day = plan.days.first(where: { $0.dayNumber == dayNumber }) else {
            return "❌ 未找到第 \(dayNumber) 天的训练"
        }
        
        // 找到要替换的动作（优先精确匹配，失败时仅在唯一近似匹配时回退）
        let exactMatches = day.exercises.filter { $0.name.caseInsensitiveCompare(oldName) == .orderedSame }
        let targetExercise: Exercise?
        if exactMatches.count == 1 {
            targetExercise = exactMatches.first
        } else {
            let fuzzyMatches = day.exercises.filter { $0.name.localizedCaseInsensitiveContains(oldName) || oldName.localizedCaseInsensitiveContains($0.name) }
            targetExercise = (fuzzyMatches.count == 1) ? fuzzyMatches.first : nil
        }
        guard let exercise = targetExercise else {
            return "❌ 在第 \(dayNumber) 天未找到唯一匹配的动作：\(oldName)，请提供更精确的名称"
        }
        
        // 更新动作信息
        exercise.name = newName
        if let sets = action.sets {
            exercise.sets = sets
        }
        if let reps = action.reps {
            exercise.reps = reps
        }
        if let weight = action.weight {
            exercise.weight = weight
        }
        
        let reason = action.reason ?? "根据您的需求调整"
        return "✅ 已将第 \(dayNumber) 天的「\(oldName)」替换为「\(newName)」\n原因：\(reason)"
    }
    
    // MARK: - 添加动作
    private func addExercise(action: AIActionCommand.Action, plan: WorkoutPlan) -> String? {
        guard let dayNumber = action.day,
              let exerciseName = action.newExercise ?? action.exerciseName else {
            return nil
        }
        
        // 找到对应的训练日
        guard let day = plan.days.first(where: { $0.dayNumber == dayNumber }) else {
            return "❌ 未找到第 \(dayNumber) 天的训练"
        }
        
        // 创建新动作
        let newExercise = Exercise(
            name: exerciseName,
            sets: action.sets ?? 3,
            reps: action.reps ?? "8-12",
            weight: action.weight ?? 0
        )
        newExercise.workoutDay = day
        day.exercises.append(newExercise)
        modelContext.insert(newExercise)
        
        let reason = action.reason ?? "根据您的需求添加"
        return "✅ 已在第 \(dayNumber) 天添加动作「\(exerciseName)」\n原因：\(reason)"
    }
    
    // MARK: - 删除动作
    private func removeExercise(action: AIActionCommand.Action, plan: WorkoutPlan) -> String? {
        guard let dayNumber = action.day,
              let exerciseName = action.exerciseName ?? action.oldExercise else {
            return nil
        }
        
        // 找到对应的训练日
        guard let day = plan.days.first(where: { $0.dayNumber == dayNumber }) else {
            return "❌ 未找到第 \(dayNumber) 天的训练"
        }
        
        // 找到要删除的动作（优先精确匹配，失败时仅在唯一近似匹配时回退）
        let exactIndexes = day.exercises.enumerated().compactMap { idx, ex in
            ex.name.caseInsensitiveCompare(exerciseName) == .orderedSame ? idx : nil
        }
        var index: Int?
        if exactIndexes.count == 1 {
            index = exactIndexes.first
        } else {
            let fuzzyIndexes = day.exercises.enumerated().compactMap { idx, ex in
                (ex.name.localizedCaseInsensitiveContains(exerciseName) || exerciseName.localizedCaseInsensitiveContains(ex.name)) ? idx : nil
            }
            index = (fuzzyIndexes.count == 1) ? fuzzyIndexes.first : nil
        }
        guard let index = index else {
            return "❌ 在第 \(dayNumber) 天未找到唯一匹配的动作：\(exerciseName)，请提供更精确的名称"
        }
        
        let exercise = day.exercises[index]
        day.exercises.remove(at: index)
        modelContext.delete(exercise)
        
        let reason = action.reason ?? "根据您的需求删除"
        return "✅ 已从第 \(dayNumber) 天删除动作「\(exerciseName)」\n原因：\(reason)"
    }
}
