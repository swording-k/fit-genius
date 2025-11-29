import SwiftUI
import SwiftData

// MARK: - AI 助手聊天界面
struct AIAssistantView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @StateObject private var viewModel: AIAssistantViewModel
    @FocusState private var isInputFocused: Bool
    
    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: AIAssistantViewModel(modelContext: modelContext))
    }
    
    var profile: UserProfile? {
        profiles.first
    }
    
    var plan: WorkoutPlan? {
        profile?.workoutPlan
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if profile == nil || plan == nil {
                // 空状态
                VStack(spacing: 20) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("暂无训练计划")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text("请先完成用户资料设置并生成训练计划")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 消息列表
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
                                    Text("AI 正在思考...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    // 点击空白处收起键盘
                    .onTapGesture {
                        isInputFocused = false
                    }
                }
                
                Divider()
                
                // 输入框
                HStack(spacing: 12) {
                    TextField("输入消息...", text: $viewModel.inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputFocused)
                        .lineLimit(1...5)
                        .submitLabel(.send)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(viewModel.inputText.isEmpty ? .gray : .blue)
                    }
                    .disabled(viewModel.inputText.isEmpty || viewModel.isLoading)
                }
                .padding()
                .background(Color(.systemBackground))
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("完成") {
                            isInputFocused = false
                        }
                    }
                }
            }
        }
        .navigationTitle("AI 助手")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    viewModel.messages.removeAll()
                    let welcomeMessage = ChatMessage(
                        content: "你好！我是你的 AI 健身助手。你可以向我咨询健身建议，或者让我帮你调整训练计划。",
                        isUser: false
                    )
                    viewModel.messages.append(welcomeMessage)
                }) {
                    Image(systemName: "trash")
                }
            }
        }
        .alert("重新生成训练计划", isPresented: $viewModel.showPlanRegenerationAlert) {
            Button("取消", role: .cancel) {
                // 取消操作
            }
            Button("确认", role: .destructive) {
                // 确认重新生成
                if let profile = profile {
                    Task {
                        await viewModel.regeneratePlan(profile: profile)
                    }
                }
            }
        } message: {
            Text("检测到您想要修改训练计划的整体结构（如循环天数）。\n\n这将重新生成完整的训练计划，您手动修改的内容将会丢失。\n\n是否继续？")
        }
    }
    
    // 发送消息的辅助方法
    private func sendMessage() {
        guard let profile = profile, let plan = plan else { return }
        isInputFocused = false  // 发送后收起键盘
        Task {
            await viewModel.sendMessage(profile: profile, plan: plan)
        }
    }
}

// MARK: - 消息气泡
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
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
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, WorkoutPlan.self, ChatMessage.self, configurations: config)
    
    return NavigationStack {
        AIAssistantView(modelContext: container.mainContext)
    }
    .modelContainer(container)
}
