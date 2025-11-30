import SwiftUI
import SwiftData

struct DietAIAssistantView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: DietAssistantViewModel
    @FocusState private var isInputFocused: Bool

    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: DietAssistantViewModel(modelContext: modelContext))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.messages, id: \.id) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        if viewModel.isLoading {
                            HStack {
                                ProgressView()
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
                    if let last = viewModel.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
                .onTapGesture { isInputFocused = false }
            }

            Divider()

            HStack(spacing: 12) {
                TextField("输入消息...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                    .submitLabel(.send)
                    .onSubmit { Task { await viewModel.sendMessage() } }
                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
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
                    Button("完成") { isInputFocused = false }
                }
            }
        }
        .navigationTitle("AI 助手")
        .navigationBarTitleDisplayMode(.inline)
    }
}