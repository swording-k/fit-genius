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
    @Published var showClearHistoryAlert: Bool = false
    @Published private(set) var conversationHistory: [ChatConversationSummary] = []
    @Published private(set) var activeConversationID: UUID?
    @Published var pendingUserMessage: String = ""
    @Published var suggestionOnly: Bool = false
    @Published private(set) var pendingPlanCommand: AIActionCommand?
    @Published private(set) var pendingPlanValidationErrors: [String] = []
    @Published private(set) var pendingReplacementPlan: WorkoutPlan?
    @Published private(set) var pendingReplacementValidationErrors: [String] = []
    
    // 待发送的媒体
    @Published var pendingMediaData: Data?
    @Published var pendingMediaType: String? // "image" or "video"
    @Published var pendingThumbnail: UIImage?
    @Published var pendingFormExerciseType: FormExerciseType?
    @Published var isPreparingMedia: Bool = false
    
    private let aiService = AIService()
    private let modelContext: ModelContext
    private var languagePolicy: AppLanguagePolicy { AppLanguagePolicy.current }
    private let activeConversationDefaultsKey = "fitnessAssistantActiveConversationID"
    private var pendingPlanCatalog: [ExerciseTemplate] = []
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadInitialConversation()
    }

    private func loadInitialConversation() {
        let storedID = UserDefaults.standard.string(forKey: activeConversationDefaultsKey)
            .flatMap(UUID.init(uuidString:))
        if let storedID, conversationExists(id: storedID) {
            selectConversation(id: storedID)
        } else {
            startNewConversation()
        }
    }

    private func conversationExists(id: UUID) -> Bool {
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.topic == "fitness" },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return (try? modelContext.fetch(descriptor))?.contains { $0.conversationID == id } == true
    }

    func startNewConversation() {
        activeConversationID = UUID()
        setStoredActiveConversation(activeConversationID)
        inputText = ""
        clearPendingMedia()
        messages = []
        appendMessage(content: "fitness_assistant_welcome".localized, isUser: false)
        refreshConversationHistory()
    }

    func selectConversation(id: UUID?) {
        activeConversationID = id
        setStoredActiveConversation(id)
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.topic == "fitness" },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        messages = ((try? modelContext.fetch(descriptor)) ?? []).filter { $0.conversationID == id }
        refreshConversationHistory()
    }

    func deleteConversation(id: UUID?) {
        let descriptor = FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.topic == "fitness" })
        for message in ((try? modelContext.fetch(descriptor)) ?? []) where message.conversationID == id {
            modelContext.delete(message)
        }
        try? modelContext.save()
        if activeConversationID == id {
            startNewConversation()
        } else {
            refreshConversationHistory()
        }
    }

    private func setStoredActiveConversation(_ id: UUID?) {
        UserDefaults.standard.set(id?.uuidString ?? "legacy", forKey: activeConversationDefaultsKey)
    }

    private func refreshConversationHistory() {
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.topic == "fitness" },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        let grouped = Dictionary(grouping: (try? modelContext.fetch(descriptor)) ?? [], by: \.conversationID)
        let summaries = grouped.map { id, entries in
            ChatConversationSummary(
                sessionID: id,
                title: ChatSessionPolicy.title(
                    firstUserMessage: entries.first(where: \.isUser)?.content,
                    fallback: id == nil ? "chat_earlier_conversation".localized : "chat_new_conversation".localized
                ),
                updatedAt: entries.map(\.timestamp).max() ?? .distantPast
            )
        }
        let orderedIDs = ChatSessionPolicy.orderedSessionIDs(
            entries: summaries.map { .init(id: $0.sessionID, latestTimestamp: $0.updatedAt) },
            activeID: activeConversationID
        )
        conversationHistory = orderedIDs.compactMap { id in summaries.first { $0.sessionID == id } }
    }

    @discardableResult
    private func appendMessage(
        content: String,
        isUser: Bool,
        isSystemAction: Bool = false,
        mediaData: Data? = nil,
        mediaType: String? = nil
    ) -> ChatMessage {
        let message = ChatMessage(
            content: content,
            isUser: isUser,
            isSystemAction: isSystemAction,
            mediaData: mediaData,
            mediaType: mediaType,
            topic: "fitness",
            conversationID: activeConversationID
        )
        modelContext.insert(message)
        messages.append(message)
        refreshConversationHistory()
        return message
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
            activeConversationID = UUID()
            setStoredActiveConversation(activeConversationID)
            appendMessage(content: "fitness_assistant_welcome_short".localized, isUser: false)
            refreshConversationHistory()
        } catch {
            print("Failed to clear fitness chat history: \(error)")
        }
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
    func sendMessage(profile: UserProfile?, plan: WorkoutPlan?) async {
        // 1. 检查是否有待发送的媒体
        if let mediaData = pendingMediaData, let type = pendingMediaType {
            let isVideo = (type == "video")
            guard let profile else {
                appendMessage(content: "assistant_profile_needed_for_media".localized, isUser: false)
                return
            }
            await sendMediaMessage(profile: profile, plan: plan, mediaData: mediaData, isVideo: isVideo, userText: inputText)
            clearPendingMedia()
            return
        }
        
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = inputText
        inputText = ""
        
        appendMessage(content: userMessage, isUser: true)

        guard let profile, let plan else {
            await processGeneralQuestion(userMessage: userMessage, profile: profile, plan: plan)
            return
        }
        
        if suggestionOnly {
            await provideSuggestionOnly(userMessage: userMessage, profile: profile, plan: plan)
            return
        }
        
        // 动作级别修改
        await processExerciseLevelModification(userMessage: userMessage, profile: profile, plan: plan)
    }

    private func processGeneralQuestion(
        userMessage: String,
        profile: UserProfile?,
        plan: WorkoutPlan?
    ) async {
        isLoading = true
        errorMessage = nil
        do {
            let (response, _) = try await aiService.chat(
                userMessage: messageWithRecentFormContext(
                    messageWithHealthContext(messageWithRecentConversationContext(userMessage))
                ),
                profile: profile,
                plan: plan
            )
            appendMessage(content: AIResponseFormatter.displayText(from: response), isUser: false)
        } catch {
            errorMessage = error.localizedDescription
            appendMessage(
                content: localizedFailure(
                    prefixChinese: "抱歉，暂时无法回答",
                    prefixEnglish: "Sorry, I couldn't answer that",
                    error: error
                ),
                isUser: false
            )
        }
        isLoading = false
    }
    
    // MARK: - 建议模式：仅提供文字建议
	func provideSuggestionOnly(userMessage: String, profile: UserProfile, plan: WorkoutPlan) async {
        storeUserMessageIfNeeded(userMessage)
        isLoading = true
        errorMessage = nil
		do {
			let (response, _) = try await aiService.chat(
                userMessage: messageWithRecentFormContext(
                    messageWithHealthContext(messageWithRecentConversationContext(suggestionOnlyPromptPrefix + userMessage))
                ),
                profile: profile,
                plan: plan
            )
			appendMessage(content: suggestionOnlyEnabledMessage, isUser: false, isSystemAction: true)
			if !response.isEmpty {
                appendMessage(content: AIResponseFormatter.displayText(from: response), isUser: false)
            }
            isLoading = false
		} catch {
			isLoading = false
			errorMessage = error.localizedDescription
            appendMessage(content: localizedFailure(prefixChinese: "抱歉，生成建议失败", prefixEnglish: "Sorry, generating advice failed", error: error), isUser: false)
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
        appendMessage(content: contentText, isUser: true, mediaData: storedMediaData, mediaType: storedMediaType)
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
            appendMessage(content: AIResponseFormatter.displayText(from: response), isUser: false)
            isLoading = false
            loadingText = "assistant_thinking".localized
		} catch {
			isLoading = false
            loadingText = "assistant_thinking".localized
			errorMessage = error.localizedDescription
            appendMessage(content: localizedFailure(prefixChinese: "抱歉，分析失败", prefixEnglish: "Sorry, analysis failed", error: error), isUser: false)
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
            appendMessage(
                content: content,
                isUser: false,
                mediaData: FormAnalysisChatPresentation.primaryFeedbackImageData(
                    localFrameImageData: artifact.feedbackImageData,
                    enrichmentAnnotatedImageData: artifact.enrichment?.annotatedImageData ?? []
                ),
                mediaType: "image"
            )

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
            appendMessage(
                content: String(
                    format: NSLocalizedString("assistant_form_analysis_failed", comment: ""),
                    error.localizedDescription
                ),
                isUser: false
            )
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
                userMessage: messageWithRecentFormContext(
                    messageWithHealthContext(messageWithRecentConversationContext(userMessage))
                ),
                profile: profile,
                plan: plan,
                catalog: catalog
            )
            
            // AI 只生成待确认提案，不直接写入训练计划。
            if let command = command {
                if command.type == "regenerate_plan" {
                    pendingUserMessage = messageWithHealthContext(userMessage)
                    await regeneratePlan(profile: profile)
                    return
                }
                let validation = validate(command: command, against: plan)
                pendingPlanValidationErrors = validation.errors
                pendingPlanCatalog = catalog
                pendingPlanCommand = command
                appendMessage(
                    content: validation.isValid
                        ? "plan_edit_proposal_ready".localized
                        : "plan_edit_proposal_invalid".localized,
                    isUser: false,
                    isSystemAction: true
                )
            } else if !response.isEmpty {
                // 普通文本回复
                appendMessage(content: AIResponseFormatter.displayText(from: response), isUser: false)
            } else {
                // 既没有可执行的指令，也没有可显示的文本（通常是 AI 返回了空内容或
                // 无法解析为动作指令）。给一句明确的中文/英文引导，而不是什么都不显示，
                // 让用户知道怎么表达才能触发计划修改。
                let hint = languagePolicy.prefersSimplifiedChinese
                    ? "我没有理解成具体的动作修改。请更明确一些，例如：\n• 把第1天的杠铃卧推换成哑铃飞鸟\n• 第2天加一个高位下拉\n• 把第1天的卧推改成5组\n• 删除第3天的绳索下压"
                    : "I couldn't interpret that as a specific plan edit. Try being explicit, e.g.:\n• Replace barbell bench press with dumbbell fly on day 1\n• Add lat pulldown to day 2\n• Change day 1 bench press to 5 sets\n• Remove cable pushdown from day 3"
                appendMessage(content: hint, isUser: false, isSystemAction: true)
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

            appendMessage(content: message, isUser: false)
        }
    }

    func discardPendingPlanCommand() {
        pendingPlanCommand = nil
        pendingPlanValidationErrors = []
        pendingPlanCatalog = []
    }

    func applyPendingPlanCommand(to plan: WorkoutPlan) {
        guard let command = pendingPlanCommand else { return }
        let validation = validate(command: command, against: plan)
        pendingPlanValidationErrors = validation.errors
        guard validation.isValid else { return }

        do {
            let feedback = try executeCommand(command, plan: plan, catalog: pendingPlanCatalog)
            appendMessage(content: feedback, isUser: false, isSystemAction: true)
            discardPendingPlanCommand()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            appendMessage(
                content: localizedFailure(
                    prefixChinese: "应用修改失败，原计划未改变",
                    prefixEnglish: "Applying the edit failed; your plan was not changed",
                    error: error
                ),
                isUser: false
            )
        }
    }

    private func validate(
        command: AIActionCommand,
        against plan: WorkoutPlan
    ) -> PlanEditValidationResult {
        let snapshot = PlanEditSnapshot(days: (plan.days ?? []).map { day in
            .init(
                dayNumber: day.dayNumber,
                isRestDay: day.isRestDay,
                exerciseNames: (day.exercises ?? []).map(\.name)
            )
        })

        let kind: PlanEditRequest.Kind?
        switch command.type {
        case "update_plan": kind = .update
        case "add_exercise": kind = .add
        case "remove_exercise": kind = .remove
        default: kind = nil
        }
        guard let kind else {
            return PlanEditValidationResult(errors: ["plan_edit_error_unknown_operation"])
        }

        let results = command.actions.map { action in
            PlanEditValidationPolicy.validate(
                PlanEditRequest(
                    kind: kind,
                    dayNumber: action.day,
                    targetName: action.oldExercise ?? action.exerciseName,
                    replacementName: action.newExercise ?? action.exerciseName,
                    sets: action.sets,
                    reps: action.reps,
                    weight: action.weight
                ),
                against: snapshot
            )
        }
        return PlanEditValidationResult(errors: results.flatMap(\.errors))
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

    private func messageWithHealthContext(_ userMessage: String) -> String {
        guard let healthContext = HealthContextBuilder(modelContext: modelContext).aiContextIfEnabled(),
              !healthContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return userMessage
        }

        if languagePolicy.prefersSimplifiedChinese {
            return """
            FitGenius 健康数据上下文（用户已开启 AI 使用健康摘要；只用于训练恢复、饮食执行和训练调整建议。不要做医疗诊断，不要声称用户患病）：
            \(healthContext)

            用户消息：
            \(userMessage)
            """
        }

        return """
        FitGenius health-data context. The user enabled AI access to health summaries. Use it only for training recovery, nutrition adherence, and programming advice. Do not diagnose medical conditions.
        \(healthContext)

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
        appendMessage(content: trimmed, isUser: true)
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
            
            let validation = validateReplacement(newPlan)
            pendingReplacementValidationErrors = validation.errors
            pendingReplacementPlan = newPlan
            appendMessage(
                content: validation.isValid
                    ? "plan_replacement_proposal_ready".localized
                    : "plan_edit_proposal_invalid".localized,
                isUser: false,
                isSystemAction: true
            )
            
            isLoading = false
            
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            
            appendMessage(content: localizedFailure(prefixChinese: "抱歉，重新生成计划失败", prefixEnglish: "Sorry, regenerating the plan failed", error: error), isUser: false)
        }
    }

    func discardPendingReplacement() {
        pendingReplacementPlan = nil
        pendingReplacementValidationErrors = []
    }

    func applyPendingReplacement(to profile: UserProfile) {
        guard let replacement = pendingReplacementPlan else { return }
        let validation = validateReplacement(replacement)
        pendingReplacementValidationErrors = validation.errors
        guard validation.isValid else { return }

        do {
            modelContext.insert(replacement)
            replacement.userProfile = profile
            profile.workoutPlan = replacement
            try modelContext.save()
            appendMessage(content: planRegeneratedMessage, isUser: false, isSystemAction: true)
            discardPendingReplacement()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            appendMessage(
                content: localizedFailure(
                    prefixChinese: "应用新计划失败，原计划未改变",
                    prefixEnglish: "Applying the new plan failed; your old plan was not changed",
                    error: error
                ),
                isUser: false
            )
        }
    }

    private func validateReplacement(_ plan: WorkoutPlan) -> PlanEditValidationResult {
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
