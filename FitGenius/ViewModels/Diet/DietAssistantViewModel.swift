import Foundation
import SwiftData
import Combine

@MainActor
class DietAssistantViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let modelContext: ModelContext
    private let service = AIService()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let welcome = ChatMessage(content: "你好！我是你的 AI 饮食助手。你可以向我咨询饮食建议，或者让我帮你规范化并计算你的饮食数据。", isUser: false)
        messages.append(welcome)
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        let userMsg = ChatMessage(content: text, isUser: true)
        messages.append(userMsg)
        isLoading = true
        do {
            let reply = try await service.dietChat(userMessage: text)
            let aiMsg = ChatMessage(content: reply, isUser: false)
            messages.append(aiMsg)
        } catch {
            errorMessage = error.localizedDescription
            let errMsg = ChatMessage(content: error.localizedDescription, isUser: false)
            messages.append(errMsg)
        }
        isLoading = false
    }
}