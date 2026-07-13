import Foundation
import SwiftData
import Combine
import PhotosUI
import SwiftUI
import AVFoundation

// MARK: - AI 助手 ViewModel
@MainActor
class AIAssistantViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var loadingText: String = "assistant_thinking".localized
    @Published var errorMessage: String?
    @Published var mediaErrorMessage: String?
    @Published var showPlanRegenerationAlert: Bool = false
    @Published var showClearHistoryAlert: Bool = false
    @Published var pendingUserMessage: String = ""
    @Published var suggestionOnly: Bool = false
    
    // 待发送的媒体
    @Published var pendingMediaData: Data?
    @Published var pendingMediaType: String? // "image" or "video"
    @Published var pendingThumbnail: UIImage?
    @Published var pendingFormExerciseType: FormExerciseType?
    @Published var isPreparingMedia: Bool = false
    
    private let aiService = AIService()
    private let modelContext: ModelContext
    private var languagePolicy: AppLanguagePolicy { AppLanguagePolicy.current }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        // 只加载健身相关的聊天记录
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.topic == "fitness" },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        if let stored = try? modelContext.fetch(descriptor), !stored.isEmpty {
            messages = stored
        } else {
            let welcomeMessage = ChatMessage(
                content: "fitness_assistant_welcome".localized,
                isUser: false,
                topic: "fitness"
            )
            modelContext.insert(welcomeMessage)
            messages.append(welcomeMessage)
        }
    }
    
    // MARK: - 清空历史记录
    func clearHistory() {
        do {
            let descriptor = FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.topic == "fitness" })
            let items = try modelContext.fetch(descriptor)
            for item in items {
                modelContext.delete(item)
            }
            messages.removeAll()
            
            // 重新添加欢迎语
            let welcomeMessage = ChatMessage(
                content: "fitness_assistant_welcome_short".localized,
                isUser: false,
                topic: "fitness"
            )
            modelContext.insert(welcomeMessage)
            messages.append(welcomeMessage)
        } catch {
            print("Failed to clear fitness chat history: \(error)")
        }
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
    
    // MARK: - 媒体处理
    func handleMediaSelection(item: PhotosPickerItem) {
        Task {
            isPreparingMedia = true
            mediaErrorMessage = nil
            defer { isPreparingMedia = false }

            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw MediaImagePreprocessorError.unreadableImage
                }

                if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                    pendingMediaData = data
                    pendingMediaType = "video"
                    pendingThumbnail = nil

                    let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
                    try? data.write(to: tempFile)
                    defer { try? FileManager.default.removeItem(at: tempFile) }

                    let asset = AVAsset(url: tempFile)
                    let generator = AVAssetImageGenerator(asset: asset)
                    generator.appliesPreferredTrackTransform = true
                    if let imageRef = try? await generator.image(at: .zero).image {
                        pendingThumbnail = UIImage(cgImage: imageRef)
                    }
                } else {
                    let normalized = try MediaImagePreprocessor.normalizedJPEG(from: data)
                    pendingMediaData = normalized
                    pendingMediaType = "image"
                    pendingThumbnail = UIImage(data: normalized)
                }
            } catch {
                mediaErrorMessage = error.localizedDescription
            }
        }
    }
    
    func clearPendingMedia() {
        pendingMediaData = nil
        pendingMediaType = nil
        pendingThumbnail = nil
        pendingFormExerciseType = nil
        mediaErrorMessage = nil
    }

    #if DEBUG
    func loadDebugLaunchVideoIfNeeded() {
        guard pendingMediaData == nil,
              let url = DebugFormAnalysisVideoProvider.launchVideoURL,
              let data = try? Data(contentsOf: url) else { return }
        pendingMediaData = data
        pendingMediaType = "video"
        pendingFormExerciseType = nil

        Task {
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            if let imageRef = try? await generator.image(at: .zero).image {
                pendingThumbnail = UIImage(cgImage: imageRef)
            }
        }
    }
    #endif

    // MARK: - 发送消息
    func sendMessage(profile: UserProfile, plan: WorkoutPlan) async {
        // 1. 检查是否有待发送的媒体
        if let mediaData = pendingMediaData, let type = pendingMediaType {
            let isVideo = (type == "video")
            await sendMediaMessage(profile: profile, plan: plan, mediaData: mediaData, isVideo: isVideo, userText: inputText)
            clearPendingMedia()
            return
        }
        
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = inputText
        inputText = ""
        
		let userChatMessage = ChatMessage(content: userMessage, isUser: true)
		modelContext.insert(userChatMessage)
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
	func provideSuggestionOnly(userMessage: String, profile: UserProfile, plan: WorkoutPlan) async {
        storeUserMessageIfNeeded(userMessage)
        isLoading = true
        errorMessage = nil
		do {
			let (response, _) = try await aiService.chat(
                userMessage: messageWithRecentFormContext(
                    messageWithRecentConversationContext(suggestionOnlyPromptPrefix + userMessage)
                ),
                profile: profile,
                plan: plan
            )
			let tip = ChatMessage(content: suggestionOnlyEnabledMessage, isUser: false, isSystemAction: true)
			modelContext.insert(tip)
			messages.append(tip)
			if !response.isEmpty {
				let aiMessage = ChatMessage(content: AIResponseFormatter.displayText(from: response), isUser: false)
				modelContext.insert(aiMessage)
				messages.append(aiMessage)
            }
            isLoading = false
		} catch {
			isLoading = false
			errorMessage = error.localizedDescription
			let errMsg = ChatMessage(content: localizedFailure(prefixChinese: "抱歉，生成建议失败", prefixEnglish: "Sorry, generating advice failed", error: error), isUser: false)
			modelContext.insert(errMsg)
			messages.append(errMsg)
		}
    }

	func sendMediaMessage(
        profile: UserProfile,
        plan: WorkoutPlan?,
        mediaData: Data,
        isVideo: Bool,
        userText: String,
        userId: String? = nil,
        bearerToken: String? = nil
    ) async {
		let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
		let contentText: String
		if trimmed.isEmpty {
			contentText = isVideo ? "assistant_analyze_training_video".localized : "assistant_analyze_physique_photo".localized
		} else {
			contentText = trimmed
		}
		let mediaType = isVideo ? "video" : "image"
        let storedMediaData = isVideo
            ? pendingThumbnail?.jpegData(compressionQuality: 0.7)
            : mediaData
        let storedMediaType = isVideo ? "image" : mediaType
		let userMessage = ChatMessage(
            content: contentText,
            isUser: true,
            isSystemAction: false,
            mediaData: storedMediaData,
            mediaType: storedMediaType,
            topic: "fitness"
        )
		modelContext.insert(userMessage)
		messages.append(userMessage)
        inputText = ""

        if isVideo {
            await analyzeFormVideo(
                mediaData,
                preferredExercise: pendingFormExerciseType,
                userId: userId,
                bearerToken: bearerToken
            )
            return
        }
        
        isLoading = true
        loadingText = NSLocalizedString("assistant_analyzing_image", comment: "")
        errorMessage = nil
        
		do {
			let response = try await aiService.analyzeFitnessMedia(
                userMessage: contentText,
                profile: profile,
                plan: plan,
                images: isVideo ? [] : [mediaData],
                videos: isVideo ? [mediaData] : []
            )
			let aiMessage = ChatMessage(content: AIResponseFormatter.displayText(from: response), isUser: false)
			modelContext.insert(aiMessage)
			messages.append(aiMessage)
            isLoading = false
            loadingText = "assistant_thinking".localized
		} catch {
			isLoading = false
            loadingText = "assistant_thinking".localized
			errorMessage = error.localizedDescription
			let errMsg = ChatMessage(content: localizedFailure(prefixChinese: "抱歉，分析失败", prefixEnglish: "Sorry, analysis failed", error: error), isUser: false)
			modelContext.insert(errMsg)
			messages.append(errMsg)
		}
	}

    private func analyzeFormVideo(
        _ videoData: Data,
        preferredExercise: FormExerciseType?,
        userId: String?,
        bearerToken: String?
    ) async {
        isLoading = true
        loadingText = NSLocalizedString("assistant_analyzing_form_video", comment: "")
        errorMessage = nil

        do {
            let artifact = try await LocalFormAnalysisPipeline().analyze(
                videoData: videoData,
                preferredExercise: preferredExercise
            )
            let content = formAnalysisMessage(for: artifact)
            let response = ChatMessage(
                content: content,
                isUser: false,
                mediaData: FormAnalysisChatPresentation.primaryFeedbackImageData(
                    localFrameImageData: artifact.feedbackImageData,
                    enrichmentAnnotatedImageData: artifact.enrichment?.annotatedImageData ?? []
                ),
                mediaType: "image",
                topic: "fitness"
            )
            modelContext.insert(response)
            messages.append(response)

            let record = FormAnalysisRecord(
                exerciseName: artifact.summary.exerciseType.displayName,
                exerciseType: artifact.summary.exerciseType,
                score: artifact.summary.score,
                issuesJSON: encodeJSONString(artifact.summary.issues),
                metricsJSON: encodeJSONString(artifact.summary.metrics),
                recommendation: artifact.summary.recommendation,
                videoDuration: artifact.duration
            )
            modelContext.insert(record)
            try? modelContext.save()
            await FormAnalysisSyncCoordinator.shared.syncOneRecord(
                record,
                context: modelContext,
                userId: userId,
                bearerToken: bearerToken
            )
        } catch {
            errorMessage = error.localizedDescription
            let message = ChatMessage(
                content: String(
                    format: NSLocalizedString("assistant_form_analysis_failed", comment: ""),
                    error.localizedDescription
                ),
                isUser: false
            )
            modelContext.insert(message)
            messages.append(message)
        }

        isLoading = false
        loadingText = NSLocalizedString("assistant_thinking", comment: "")
    }

    private func formAnalysisMessage(for artifact: LocalFormAnalysisArtifact) -> String {
        let metrics = artifact.summary.metrics
            .filter { $0.key != "detected_frames" || $0.value > 0 }
            .prefix(5)
            .map { metric in
                let value = metric.unit == "degrees"
                    ? String(format: "%.0f°", metric.value)
                    : String(format: "%.2f", metric.value)
                return "• \(metric.label)：\(value)"
            }
            .joined(separator: "\n")
        let confidenceNote = artifact.classification.confidence < 0.65
            ? "\n\n" + NSLocalizedString("assistant_form_detection_low_confidence", comment: "")
            : ""
        let coaching = FormCoachFeedbackBuilder().build(
            summary: artifact.summary,
            feedbackTimestamp: artifact.feedbackTimestamp,
            classificationConfidence: artifact.classification.confidence,
            usedAutomaticDetection: artifact.usedAutomaticDetection,
            enrichmentCues: artifact.enrichment?.cues ?? []
        )
        let enrichmentNote: String
        if let coachNote = artifact.enrichment?.coachNote, !coachNote.isEmpty {
            enrichmentNote = String(
                format: NSLocalizedString("assistant_form_ai_coach_note_format", comment: ""),
                coachNote
            )
        } else if artifact.enrichmentAttempted {
            enrichmentNote = NSLocalizedString("assistant_form_ai_coach_fallback", comment: "")
        } else {
            enrichmentNote = ""
        }
        let detectionReason = NSLocalizedString(artifact.classification.reasonKey, comment: "")
        let metricsSection = String(
            format: NSLocalizedString("assistant_form_analysis_metrics_format", comment: ""),
            metrics.isEmpty ? NSLocalizedString("form_analysis_stable", comment: "") : metrics
        )
        return [detectionReason + confidenceNote, enrichmentNote, coaching.assistantText, metricsSection]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    // MARK: - 处理动作级别修改
    private func processExerciseLevelModification(userMessage: String, profile: UserProfile, plan: WorkoutPlan) async {
        isLoading = true
        errorMessage = nil
        
        // 动作库目录：供 AI 同源取动作名，并供本地把 AI 返回的名字解析回连 ExerciseTemplate。
        let catalog = ExerciseTemplate.catalog(for: profile, in: modelContext)
        
        do {
            // 调用 AI 服务
            let (response, command) = try await aiService.chat(
                userMessage: messageWithRecentFormContext(messageWithRecentConversationContext(userMessage)),
                profile: profile,
                plan: plan,
                catalog: catalog
            )
            
            // 如果有操作指令，执行它
            if let command = command {
                let feedbackMessage = try executeCommand(command, plan: plan, catalog: catalog)

                // 添加系统反馈消息
                let systemMessage = ChatMessage(
                    content: feedbackMessage,
                    isUser: false,
                    isSystemAction: true
                )
                modelContext.insert(systemMessage)
                messages.append(systemMessage)
            } else if !response.isEmpty {
                // 普通文本回复
                let aiMessage = ChatMessage(content: AIResponseFormatter.displayText(from: response), isUser: false)
                modelContext.insert(aiMessage)
                messages.append(aiMessage)
            } else {
                // 既没有可执行的指令，也没有可显示的文本（通常是 AI 返回了空内容或
                // 无法解析为动作指令）。给一句明确的中文/英文引导，而不是什么都不显示，
                // 让用户知道怎么表达才能触发计划修改。
                let hint = languagePolicy.prefersSimplifiedChinese
                    ? "我没有理解成具体的动作修改。请更明确一些，例如：\n• 把第1天的杠铃卧推换成哑铃飞鸟\n• 第2天加一个高位下拉\n• 把第1天的卧推改成5组\n• 删除第3天的绳索下压"
                    : "I couldn't interpret that as a specific plan edit. Try being explicit, e.g.:\n• Replace barbell bench press with dumbbell fly on day 1\n• Add lat pulldown to day 2\n• Change day 1 bench press to 5 sets\n• Remove cable pushdown from day 3"
                let hintMessage = ChatMessage(content: hint, isUser: false, isSystemAction: true)
                modelContext.insert(hintMessage)
                messages.append(hintMessage)
            }
            
            isLoading = false
            
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription

            // 针对“AI 返回空内容”给出更友好的重试/改法引导，而不是只显示原始错误。
            let message: String
            if case .emptyContent = error as? AIServiceError {
                message = languagePolicy.prefersSimplifiedChinese
                    ? "AI 暂时没有返回有效内容，请稍后再试；或换一种更明确的改法，例如：「把第1天的杠铃卧推换成哑铃飞鸟」。"
                    : "The AI didn't return usable content. Please retry, or rephrase the edit, e.g. \"Replace barbell bench press with dumbbell fly on day 1\"."
            } else {
                message = localizedFailure(prefixChinese: "抱歉，出现了错误", prefixEnglish: "Sorry, something went wrong", error: error)
            }

            let errorChatMessage = ChatMessage(content: message, isUser: false)
            modelContext.insert(errorChatMessage)
            messages.append(errorChatMessage)
        }
    }

    private func messageWithRecentFormContext(_ userMessage: String) -> String {
        let descriptor = FetchDescriptor<FormAnalysisRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let record = try? modelContext.fetch(descriptor).first else {
            return userMessage
        }

        let issues = record.issues.isEmpty
            ? NSLocalizedString("form_analysis_stable", comment: "")
            : record.issues.map { "\($0.title): \($0.detail)" }.joined(separator: "\n")
        if languagePolicy.prefersSimplifiedChinese {
            return """
            下面包含最近一次确定性的设备端动作分析。只有在和用户问题相关时才使用它。不要否定或替换本地分数和检测到的问题。
            动作：\(record.exerciseType.displayName)
            分数：\(record.score)
            检测到的问题：
            \(issues)
            建议：\(record.recommendation)

            用户消息：
            \(userMessage)
            """
        }
        return """
        Recent deterministic on-device form analysis is included below. Use it only when relevant to the user's question. Do not contradict or replace the local score and detected issues.
        Exercise: \(record.exerciseType.displayName)
        Score: \(record.score)
        Detected issues:
        \(issues)
        Recommendation: \(record.recommendation)

        User message:
        \(userMessage)
        """
    }

    private func messageWithRecentConversationContext(_ userMessage: String) -> String {
        let recent = messages
            .dropLast()
            .filter { !$0.isSystemAction && $0.mediaData == nil && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .suffix(6)

        guard !recent.isEmpty else { return userMessage }

        let transcript = recent.map { message in
            let role = message.isUser
                ? (languagePolicy.prefersSimplifiedChinese ? "用户" : "User")
                : (languagePolicy.prefersSimplifiedChinese ? "教练" : "Coach")
            return "\(role)：\(message.content.truncatedForAIContext(maxLength: 420))"
        }.joined(separator: "\n")

        if languagePolicy.prefersSimplifiedChinese {
            return """
            最近对话上下文（只在相关时使用，不要逐字复述）：
            \(transcript)

            当前用户消息：
            \(userMessage)
            """
        }

        return """
        Recent conversation context. Use only when relevant and do not repeat it verbatim:
        \(transcript)

        Current user message:
        \(userMessage)
        """
    }

    private func storeUserMessageIfNeeded(_ userMessage: String) {
        let trimmed = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if messages.last?.isUser == true && messages.last?.content == trimmed {
            return
        }
        let userChatMessage = ChatMessage(content: trimmed, isUser: true)
        modelContext.insert(userChatMessage)
        messages.append(userChatMessage)
    }
    
    // MARK: - 重新生成计划
    func regeneratePlan(profile: UserProfile) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 按用户环境/器械筛选动作库，供 AI 重新生成计划时同源取用
            let catalog = ExerciseTemplate.catalog(for: profile, in: modelContext)
            // 调用 AI 服务重新生成计划
            let newPlan = try await aiService.regeneratePlan(
                profile: profile,
                userRequest: pendingUserMessage,
                catalog: catalog
            )
            
            // 先持久化新计划，不改变现有链接，避免空状态闪断
            modelContext.insert(newPlan)
            try modelContext.save()
            
            // 验证新计划有效后再切换链接
            guard !(newPlan.days ?? []).isEmpty else {
                throw NSError(domain: "AIAssistant", code: -1, userInfo: [NSLocalizedDescriptionKey: emptyPlanMessage])
            }
            profile.workoutPlan = newPlan
            try modelContext.save()
            
            // 不删除旧计划，保留为备份
            
            // 添加成功消息
            let successMessage = ChatMessage(
                content: planRegeneratedMessage,
                isUser: false,
                isSystemAction: true
            )
            modelContext.insert(successMessage)
            messages.append(successMessage)
            
            isLoading = false
            
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            
            let errorChatMessage = ChatMessage(
                content: localizedFailure(prefixChinese: "抱歉，重新生成计划失败", prefixEnglish: "Sorry, regenerating the plan failed", error: error),
                isUser: false
            )
            modelContext.insert(errorChatMessage)
            messages.append(errorChatMessage)
        }
    }
    
    // MARK: - 执行 AI 操作指令
    private func executeCommand(_ command: AIActionCommand, plan: WorkoutPlan, catalog: [ExerciseTemplate]) throws -> String {
        var feedbackMessages: [String] = []
        
        for action in command.actions {
            switch command.type {
            case "update_plan":
                if let feedback = updateExercise(action: action, plan: plan, catalog: catalog) {
                    feedbackMessages.append(feedback)
                }
                
            case "add_exercise":
                if let feedback = addExercise(action: action, plan: plan, catalog: catalog) {
                    feedbackMessages.append(feedback)
                }
                
            case "remove_exercise":
                if let feedback = removeExercise(action: action, plan: plan, catalog: catalog) {
                    feedbackMessages.append(feedback)
                }
                
            default:
                feedbackMessages.append(languagePolicy.prefersSimplifiedChinese ? "未知的操作类型：\(command.type)" : "Unknown action type: \(command.type)")
            }
        }
        
        // 保存修改
        try modelContext.save()
        
        return feedbackMessages.isEmpty ? (languagePolicy.prefersSimplifiedChinese ? "操作完成" : "Done") : feedbackMessages.joined(separator: "\n")
    }
    
    // MARK: - 把 AI 返回的动作名解析回动作库
    /// 将 AI 给的动作名解析为动作库里的规范显示名（与 `ExerciseTemplate.displayName` 对齐），
    /// 并返回对应模板，用于回连 GIF 演示与详情。模糊匹配仅在唯一命中时采用，避免误改。
    private func resolveCatalogName(_ name: String, catalog: [ExerciseTemplate]) -> (displayName: String, template: ExerciseTemplate?) {
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !catalog.isEmpty else { return (target, nil) }
        if let exact = catalog.first(where: { $0.displayName.caseInsensitiveCompare(target) == .orderedSame }) {
            return (exact.displayName, exact)
        }
        let fuzzy = catalog.filter {
            $0.displayName.localizedCaseInsensitiveContains(target) || target.localizedCaseInsensitiveContains($0.displayName)
        }
        if fuzzy.count == 1 { return (fuzzy.first!.displayName, fuzzy.first!) }
        return (target, nil)
    }
    
    // MARK: - 更新动作
    private func updateExercise(action: AIActionCommand.Action, plan: WorkoutPlan, catalog: [ExerciseTemplate]) -> String? {
        guard let dayNumber = action.day,
              let oldName = action.oldExercise,
              let newName = action.newExercise else {
            return nil
        }
        
        // 找到对应的训练日
        guard let day = (plan.days ?? []).first(where: { $0.dayNumber == dayNumber }) else {
            return dayNotFoundMessage(dayNumber)
        }
        
        // 找到要替换的动作（优先精确匹配动作名或其模板显示名，失败时仅在唯一近似匹配时回退）
        let exactMatches = (day.exercises ?? []).filter {
            $0.name.caseInsensitiveCompare(oldName) == .orderedSame
            || ($0.template?.displayName.caseInsensitiveCompare(oldName) == .orderedSame)
        }
        let targetExercise: Exercise?
        if exactMatches.count == 1 {
            targetExercise = exactMatches.first
        } else {
            let fuzzyMatches = (day.exercises ?? []).filter {
                $0.name.localizedCaseInsensitiveContains(oldName)
                || oldName.localizedCaseInsensitiveContains($0.name)
                || ($0.template?.displayName.localizedCaseInsensitiveContains(oldName) ?? false)
            }
            targetExercise = (fuzzyMatches.count == 1) ? fuzzyMatches.first : nil
        }
        guard let exercise = targetExercise else {
            return exerciseNotFoundMessage(dayNumber: dayNumber, exerciseName: oldName)
        }
        
        // 更新动作信息：新名字按动作库解析为规范名，并回连模板（打通 GIF/详情）
        let resolved = resolveCatalogName(newName, catalog: catalog)
        exercise.name = resolved.displayName
        exercise.template = resolved.template
        if let sets = action.sets {
            exercise.sets = sets
        }
        if let reps = action.reps {
            exercise.reps = reps
        }
        if let weight = action.weight {
            exercise.weight = weight
        }
        
        let reason = action.reason ?? defaultUpdateReason
        return languagePolicy.prefersSimplifiedChinese
            ? "✅ 已将第 \(dayNumber) 天的「\(oldName)」替换为「\(resolved.displayName)」\n原因：\(reason)"
            : "✅ Replaced \(oldName) with \(resolved.displayName) on day \(dayNumber).\nReason: \(reason)"
    }
    
    // MARK: - 添加动作
    private func addExercise(action: AIActionCommand.Action, plan: WorkoutPlan, catalog: [ExerciseTemplate]) -> String? {
        guard let dayNumber = action.day,
              let exerciseName = action.newExercise ?? action.exerciseName else {
            return nil
        }
        
        // 找到对应的训练日
        guard let day = (plan.days ?? []).first(where: { $0.dayNumber == dayNumber }) else {
            return dayNotFoundMessage(dayNumber)
        }
        
        // 创建新动作：名字按动作库解析为规范名，并回连模板（打通 GIF/详情）
        let resolved = resolveCatalogName(exerciseName, catalog: catalog)
        let newExercise = Exercise(
            name: resolved.displayName,
            sets: action.sets ?? 3,
            reps: action.reps ?? "8-12",
            weight: action.weight ?? 0
        )
        newExercise.template = resolved.template
        newExercise.workoutDay = day
        if day.exercises == nil { day.exercises = [] }
        newExercise.orderIndex = (day.exercises ?? []).count
        day.exercises?.append(newExercise)
        modelContext.insert(newExercise)
        
        let reason = action.reason ?? defaultAddReason
        return languagePolicy.prefersSimplifiedChinese
            ? "✅ 已在第 \(dayNumber) 天添加动作「\(resolved.displayName)」\n原因：\(reason)"
            : "✅ Added \(resolved.displayName) to day \(dayNumber).\nReason: \(reason)"
    }
    
    // MARK: - 删除动作
    private func removeExercise(action: AIActionCommand.Action, plan: WorkoutPlan, catalog: [ExerciseTemplate]) -> String? {
        guard let dayNumber = action.day,
              let exerciseName = action.exerciseName ?? action.oldExercise else {
            return nil
        }
        
        // 找到对应的训练日
        guard let day = (plan.days ?? []).first(where: { $0.dayNumber == dayNumber }) else {
            return dayNotFoundMessage(dayNumber)
        }
        
        // 找到要删除的动作（优先精确匹配，失败时仅在唯一近似匹配时回退）
        let exactIndexes = (day.exercises ?? []).enumerated().compactMap { idx, ex in
            (ex.name.caseInsensitiveCompare(exerciseName) == .orderedSame
             || ex.template?.displayName.caseInsensitiveCompare(exerciseName) == .orderedSame) ? idx : nil
        }
        var index: Int?
        if exactIndexes.count == 1 {
            index = exactIndexes.first
        } else {
            let fuzzyIndexes = (day.exercises ?? []).enumerated().compactMap { idx, ex in
                (ex.name.localizedCaseInsensitiveContains(exerciseName)
                 || exerciseName.localizedCaseInsensitiveContains(ex.name)
                 || (ex.template?.displayName.localizedCaseInsensitiveContains(exerciseName) ?? false)) ? idx : nil
            }
            index = (fuzzyIndexes.count == 1) ? fuzzyIndexes.first : nil
        }
        guard let index = index else {
            return exerciseNotFoundMessage(dayNumber: dayNumber, exerciseName: exerciseName)
        }
        
        let exercise = (day.exercises ?? [])[index]
        day.exercises?.remove(at: index)
        modelContext.delete(exercise)
        
        let reason = action.reason ?? defaultRemoveReason
        return languagePolicy.prefersSimplifiedChinese
            ? "✅ 已从第 \(dayNumber) 天删除动作「\(exerciseName)」\n原因：\(reason)"
            : "✅ Removed \(exerciseName) from day \(dayNumber).\nReason: \(reason)"
    }

    private var suggestionOnlyPromptPrefix: String {
        languagePolicy.prefersSimplifiedChinese
            ? "【请只提供建议，不要返回任何 JSON 指令或修改计划】\n"
            : "[Advice only. Do not return JSON commands and do not modify the plan.]\n"
    }

    private var suggestionOnlyEnabledMessage: String {
        languagePolicy.prefersSimplifiedChinese
            ? "已启用建议模式：我只会给出文字建议，你可在训练页自行调整。"
            : "Advice mode is on: I will only give text suggestions. You can adjust the plan from the training page."
    }

    private var emptyPlanMessage: String {
        languagePolicy.prefersSimplifiedChinese
            ? "生成的计划为空，请稍后重试"
            : "The generated plan is empty. Please try again later."
    }

    private var planRegeneratedMessage: String {
        languagePolicy.prefersSimplifiedChinese
            ? "✅ 已根据您的要求重新生成训练计划！新计划已应用。"
            : "✅ Regenerated the training plan from your request. The new plan has been applied."
    }

    private var defaultUpdateReason: String {
        languagePolicy.prefersSimplifiedChinese ? "根据您的需求调整" : "Adjusted from your request"
    }

    private var defaultAddReason: String {
        languagePolicy.prefersSimplifiedChinese ? "根据您的需求添加" : "Added from your request"
    }

    private var defaultRemoveReason: String {
        languagePolicy.prefersSimplifiedChinese ? "根据您的需求删除" : "Removed from your request"
    }

    private func localizedFailure(prefixChinese: String, prefixEnglish: String, error: Error) -> String {
        let prefix = languagePolicy.prefersSimplifiedChinese ? prefixChinese : prefixEnglish
        return "\(prefix): \(error.localizedDescription)"
    }

    private func dayNotFoundMessage(_ dayNumber: Int) -> String {
        languagePolicy.prefersSimplifiedChinese
            ? "❌ 未找到第 \(dayNumber) 天的训练"
            : "❌ Could not find training day \(dayNumber)."
    }

    private func exerciseNotFoundMessage(dayNumber: Int, exerciseName: String) -> String {
        languagePolicy.prefersSimplifiedChinese
            ? "❌ 在第 \(dayNumber) 天未找到唯一匹配的动作：\(exerciseName)，请提供更精确的名称"
            : "❌ Could not find a unique match for \(exerciseName) on day \(dayNumber). Please use a more specific name."
    }
}
