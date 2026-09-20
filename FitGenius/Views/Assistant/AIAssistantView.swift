import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

// MARK: - AI 助手聊天界面
struct AIAssistantView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthViewModel
    @Query private var profiles: [UserProfile]
    @Query private var plans: [WorkoutPlan]
    @Query private var healthPreferences: [HealthInsightPreference]
    @Query private var healthDailySummaries: [HealthDailySummary]
    @Query private var readinessReports: [DailyReadinessReportRecord]
    @StateObject private var viewModel: AIAssistantViewModel
    @FocusState private var isInputFocused: Bool
    @AppStorage("hasAcceptedMedicalDisclaimer") private var hasAcceptedDisclaimer = false
    @State private var showDisclaimerAlert = false
    @State private var showLoginSheet = false
    @State private var showConversationHistory = false
    private let bottomAnchorID = "assistant-bottom-anchor"
    
    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: AIAssistantViewModel(modelContext: modelContext))
    }
    
    var profile: UserProfile? {
        guard let plan else { return profiles.reversed().first }
        return profiles.first { $0.workoutPlan === plan }
    }
    
    var plan: WorkoutPlan? {
        CurrentWorkoutPlanStore.resolve(profiles: profiles, plans: plans)
    }

    private var healthContextStatus: AssistantHealthContextStatus {
        AssistantHealthContextStatus.resolve(
            aiAccessEnabled: healthPreferences.first?.aiHealthContextEnabled == true,
            hasStoredHealthSummary: !healthDailySummaries.isEmpty || !readinessReports.isEmpty
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !hasAcceptedDisclaimer {
                DisclaimerBanner {
                    showDisclaimerAlert = true
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            if auth.needsBackendReconnect {
                Button {
                    showLoginSheet = true
                } label: {
                    Label("cloud_reconnect_ai_banner", systemImage: "exclamationmark.icloud")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            HealthAIContextBanner(status: healthContextStatus)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // 通用问答始终可用；资料和计划只作为渐进增强的上下文。
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.messages, id: \.id) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            // 加载指示器
                            if viewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                    Text(viewModel.loadingText)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }

                            Color.clear
                                .frame(height: 1)
                                .id(bottomAnchorID)
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                        }
                    }
                    .onChange(of: viewModel.isLoading) { _, _ in
                        withAnimation {
                            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                        }
                    }
                    .task {
                        await Task.yield()
                        proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                    }
                    // 点击空白处收起键盘
                    .onTapGesture {
                        isInputFocused = false
                    }
                }
                
                Divider()

                VStack(spacing: 4) {
                    HealthQuickQuestionsView { question in
                        viewModel.inputText = question
                        sendMessage()
                    }
                    .padding(.horizontal)
                    .padding(.top, 6)

                    if viewModel.pendingMediaData != nil || viewModel.isPreparingMedia {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                            ZStack {
                                if let thumb = viewModel.pendingThumbnail {
                                    Image(uiImage: thumb)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 64, height: 64)
                                        .clipped()
                                        .cornerRadius(8)
                                } else {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                    .frame(width: 64, height: 64)
                                    .cornerRadius(8)
                                }
                                if viewModel.isPreparingMedia {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                if viewModel.pendingMediaType == "video" {
                                    Image(systemName: "play.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                }
                            }
                            Button {
                                viewModel.clearPendingMedia()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            }
                            if viewModel.pendingMediaType == "video" {
                                HStack {
                                    Label("form_analysis_exercise_type", systemImage: "figure.strengthtraining.traditional")
                                        .font(.subheadline)
                                    Spacer()
                                    Picker("form_analysis_exercise_type", selection: $viewModel.pendingFormExerciseType) {
                                        Text("form_exercise_auto_detect").tag(nil as FormExerciseType?)
                                        ForEach(FormExerciseType.allCases) { type in
                                            Text(type.displayName).tag(type as FormExerciseType?)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    EnhancedInputControlsView(
                        configuration: .fitnessAssistant,
                        inputText: $viewModel.inputText,
                        isFocused: $isInputFocused,
                        isLoading: viewModel.isLoading,
                        isPreparingMedia: viewModel.isPreparingMedia,
                        canSendEmpty: viewModel.pendingMediaData != nil,
                        onSend: sendMessage,
                        onCameraCapture: nil,
                        onPhotoSelected: { item in
                            viewModel.handleMediaSelection(item: item)
                        }
                    )
                }
        }
        .onAppear {
            #if DEBUG
            viewModel.loadDebugLaunchVideoIfNeeded()
            #endif
        }
        .sheet(isPresented: $showDisclaimerAlert) {
            MedicalDisclaimerView(isPresented: $showDisclaimerAlert)
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView()
        }
        .sheet(isPresented: $showConversationHistory) {
            ChatConversationHistorySheet(
                conversations: viewModel.conversationHistory,
                activeConversationID: viewModel.activeConversationID,
                onStartNew: { viewModel.startNewConversation() },
                onSelect: { viewModel.selectConversation(id: $0) },
                onDelete: { viewModel.deleteConversation(id: $0) }
            )
        }
        .sheet(isPresented: Binding(
            get: { viewModel.pendingPlanCommand != nil },
            set: { if !$0 { viewModel.discardPendingPlanCommand() } }
        )) {
            if let command = viewModel.pendingPlanCommand {
                PlanChangePreviewSheet(
                    command: command,
                    validationErrors: viewModel.pendingPlanValidationErrors,
                    onCancel: { viewModel.discardPendingPlanCommand() },
                    onApply: {
                        if let plan {
                            viewModel.applyPendingPlanCommand(to: plan)
                        }
                    }
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.pendingReplacementPlan != nil },
            set: { if !$0 { viewModel.discardPendingReplacement() } }
        )) {
            if let replacement = viewModel.pendingReplacementPlan,
               let currentPlan = plan,
               let profile {
                PlanReplacementPreviewSheet(
                    currentPlan: currentPlan,
                    replacement: replacement,
                    validationErrors: viewModel.pendingReplacementValidationErrors,
                    onCancel: { viewModel.discardPendingReplacement() },
                    onApply: { viewModel.applyPendingReplacement(to: profile) }
                )
            }
        }
        .alert(
            "media_image_error_title",
            isPresented: Binding(
                get: { viewModel.mediaErrorMessage != nil },
                set: { if !$0 { viewModel.mediaErrorMessage = nil } }
            )
        ) {
            Button("form_analysis_close") { viewModel.mediaErrorMessage = nil }
        } message: {
            Text(viewModel.mediaErrorMessage ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.startNewConversation()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("chat_start_new_conversation")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showConversationHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityLabel("chat_history")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        viewModel.showClearHistoryAlert = true
                    } label: {
                        Label("clear_chat_history", systemImage: "trash")
                    }
                    
                    Divider()
                    
                    Button {
                        viewModel.suggestionOnly = true
                    } label: {
                        Label("suggestion_mode", systemImage: viewModel.suggestionOnly ? "checkmark.circle.fill" : "circle")
                    }
                    
                    Button {
                        viewModel.suggestionOnly = false
                    } label: {
                        Label("plan_edit_mode", systemImage: !viewModel.suggestionOnly ? "checkmark.circle.fill" : "circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("clear_history", isPresented: $viewModel.showClearHistoryAlert) {
            Button("cancel", role: .cancel) {}
            Button("clear", role: .destructive) {
                viewModel.clearHistory()
            }
        } message: {
            Text("clear_chat_history_confirm")
        }
    }
    
    // 发送消息的辅助方法
    private func sendMessage() {
        let isLocalVideoAnalysis = viewModel.pendingMediaType == "video"
        guard isLocalVideoAnalysis || auth.hasBackendSession else {
            showLoginSheet = true
            return
        }
        isInputFocused = false  // 发送后收起键盘
        Task {
            if let mediaData = viewModel.pendingMediaData,
               let type = viewModel.pendingMediaType,
               let profile {
                await viewModel.sendMediaMessage(
                    profile: profile,
                    plan: plan,
                    mediaData: mediaData,
                    isVideo: type == "video",
                    userText: viewModel.inputText,
                    userId: auth.currentSessionUserId,
                    bearerToken: auth.currentBearerToken
                )
                viewModel.clearPendingMedia()
            } else {
                await viewModel.sendMessage(profile: profile, plan: plan)
            }
        }
    }

    private func sendSuggestionOnly() {
        guard let profile = profile else { return }
        let isLocalVideoAnalysis = viewModel.pendingMediaType == "video"
        guard isLocalVideoAnalysis || auth.hasBackendSession else {
            showLoginSheet = true
            return
        }
        isInputFocused = false
        if let mediaData = viewModel.pendingMediaData, let type = viewModel.pendingMediaType {
            let isVideo = (type == "video")
            Task {
                await viewModel.sendMediaMessage(
                    profile: profile,
                    plan: nil,
                    mediaData: mediaData,
                    isVideo: isVideo,
                    userText: viewModel.inputText,
                    userId: auth.currentSessionUserId,
                    bearerToken: auth.currentBearerToken
                )
                viewModel.clearPendingMedia()
                viewModel.inputText = ""
            }
        } else {
            Task {
                await viewModel.provideSuggestionOnly(userMessage: viewModel.inputText, profile: profile, plan: WorkoutPlan(name: "temporary_plan".localized))
                viewModel.inputText = ""
            }
        }
    }
}

private struct HealthAIContextBanner: View {
    let status: AssistantHealthContextStatus

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: status == .ready ? "heart.text.square.fill" : "heart.text.square")
                .foregroundStyle(status == .ready ? .green : .secondary)
            Text(status.messageKey)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if status != .ready {
                Button("health_ai_context_manage") {
                    NotificationCenter.default.post(name: .openProfileFromAssistant, object: nil)
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private extension AssistantHealthContextStatus {
    var messageKey: String {
        switch self {
        case .disabled: return "health_ai_context_status_disabled"
        case .needsRefresh: return "health_ai_context_status_needs_refresh"
        case .ready: return "health_ai_context_status_ready"
        }
    }
}

private struct HealthQuickQuestionsView: View {
    let onSelect: (String) -> Void

    private var questions: [String] {
        [
            "health_quick_today_train".localized,
            "health_quick_adjust_week".localized,
            "health_quick_recovery_bad".localized,
            "health_quick_weekly_report".localized
        ]
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(questions, id: \.self) { question in
                    Button {
                        onSelect(question)
                    } label: {
                        Text(question)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.10))
                            .foregroundStyle(.blue)
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - 消息气泡
struct MessageBubble: View {
    let message: ChatMessage
    @State private var thumbnail: UIImage?
    @State private var previewImage: UIImage?
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
				if let data = message.mediaData, let type = message.mediaType {
					if type == "image", let uiImage = UIImage(data: data) {
                        Button {
                            previewImage = uiImage
                        } label: {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 280, maxHeight: 360)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
					} else if type == "video" {
                        ZStack {
                            if let thumb = thumbnail {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 160, height: 160)
                                    .clipped()
                                    .cornerRadius(12)
                                    .overlay(
                                        Image(systemName: "play.circle.fill")
                                            .font(.largeTitle)
                                            .foregroundColor(.white.opacity(0.8))
                                    )
                            } else {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .tint(.white)
                                    Text("generating_preview")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .frame(width: 160, height: 90)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(12)
                            }
                        }
                        .task {
                            if thumbnail == nil {
                                thumbnail = await generateThumbnail(from: data)
                            }
                        }
					}
				}
				Text(AIResponseFormatter.displayText(from: message.content))
					.padding(12)
					.background(
						RoundedRectangle(cornerRadius: 16)
							.fill(bubbleColor)
						)
					.foregroundColor(message.isUser ? .white : .primary)
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
        .sheet(item: $previewImage) { image in
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .navigationTitle("form_feedback_image_title")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("form_analysis_close") {
                            previewImage = nil
                        }
                    }
                }
            }
        }
    }
    
    private var bubbleColor: Color {
        if message.isSystemAction {
            return Color.green.opacity(0.2)
        } else if message.isUser {
            return Color.blue
        } else {
            return Color.gray.opacity(0.2)
        }
    }
    
	private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func generateThumbnail(from data: Data) async -> UIImage? {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        do {
            try data.write(to: tempFile)
            let asset = AVAsset(url: tempFile)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 0.0, preferredTimescale: 600)
            let imageRef = try await generator.image(at: time).image
            try? FileManager.default.removeItem(at: tempFile)
            return UIImage(cgImage: imageRef)
        } catch {
            return nil
        }
    }
}

extension UIImage: @retroactive Identifiable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, WorkoutPlan.self, ChatMessage.self, configurations: config)
    
    return NavigationStack {
        AIAssistantView(modelContext: container.mainContext)
    }
    .modelContainer(container)
}
