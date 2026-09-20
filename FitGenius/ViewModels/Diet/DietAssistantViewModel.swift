import Foundation
import SwiftData
import Combine
import UIKit
import PhotosUI
import SwiftUI

@MainActor
class DietAssistantViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
	@Published var inputText: String = ""
	@Published var isLoading: Bool = false
    @Published var loadingText: String = "assistant_thinking".localized
	@Published var errorMessage: String?
    @Published var mediaErrorMessage: String?
    @Published private(set) var conversationHistory: [ChatConversationSummary] = []
    @Published private(set) var activeConversationID: UUID?

    // 待发送的媒体
    @Published var pendingMediaData: Data?
    @Published var pendingMediaType: String? // "image"
    @Published var pendingThumbnail: UIImage?
    @Published var isPreparingMedia: Bool = false

    private let modelContext: ModelContext
    private let service = AIService()
    private let activeConversationDefaultsKey = "dietAssistantActiveConversationID"

	init(modelContext: ModelContext) {
		self.modelContext = modelContext
        loadHistory()
	}
    
    func loadHistory() {
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
            predicate: #Predicate { $0.topic == "diet" },
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
        appendMessage(content: "diet_assistant_welcome".localized, isUser: false)
        refreshConversationHistory()
    }

    func selectConversation(id: UUID?) {
        activeConversationID = id
        setStoredActiveConversation(id)
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.topic == "diet" },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        messages = ((try? modelContext.fetch(descriptor)) ?? []).filter { $0.conversationID == id }
        refreshConversationHistory()
    }

    func deleteConversation(id: UUID?) {
        let descriptor = FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.topic == "diet" })
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
            predicate: #Predicate { $0.topic == "diet" },
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
            topic: "diet",
            conversationID: activeConversationID
        )
        modelContext.insert(message)
        messages.append(message)
        refreshConversationHistory()
        return message
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty && pendingMediaData == nil { return }
        
        let currentText = text
        let currentMedia = pendingMediaData
        let currentMediaType = pendingMediaType
        
        // 清空输入状态
        inputText = ""
        clearPendingMedia()
        
        // 构造用户消息
        var content = currentText
        if currentMedia != nil {
            if content.isEmpty {
                content = "assistant_analyze_image".localized
            }
            // content += "（已附加图片）" // 视觉上不需要在文本里加这个，MessageBubble 会显示图片
        }
        
        appendMessage(content: content, isUser: true, mediaData: currentMedia, mediaType: currentMediaType)
        
		isLoading = true
        errorMessage = nil
        
		do {
            let reply: String
            if let media = currentMedia, currentMediaType == "image" {
                reply = try await service.dietChatWithImages(
                    userMessage: messageWithRecentDietContext(currentText.isEmpty ? "assistant_analyze_image".localized : currentText),
                    images: [media]
                )
            } else {
                reply = try await service.dietChat(userMessage: messageWithRecentDietContext(currentText))
            }
            
            appendMessage(content: AIResponseFormatter.displayText(from: reply), isUser: false)
        } catch {
            errorMessage = error.localizedDescription
            appendMessage(content: "assistant_error_format".localized(with: error.localizedDescription), isUser: false)
		}
		isLoading = false
	}
	
    func handleMediaSelection(item: PhotosPickerItem) {
        Task {
            isPreparingMedia = true
            mediaErrorMessage = nil
            defer { isPreparingMedia = false }

            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw MediaImagePreprocessorError.unreadableImage
                }
                handleMediaSelection(data: data)
            } catch {
                mediaErrorMessage = error.localizedDescription
            }
        }
    }

    func handleMediaSelection(data: Data) {
        do {
            let normalized = try MediaImagePreprocessor.normalizedJPEG(from: data)
            pendingMediaData = normalized
            pendingMediaType = "image"
            pendingThumbnail = UIImage(data: normalized)
            mediaErrorMessage = nil
        } catch {
            mediaErrorMessage = error.localizedDescription
        }
    }
    
    func clearPendingMedia() {
        pendingMediaData = nil
        pendingMediaType = nil
        pendingThumbnail = nil
        mediaErrorMessage = nil
    }
    
    func clearHistory() {
        do {
            let descriptor = FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.topic == "diet" })
            let items = try modelContext.fetch(descriptor)
            for item in items {
                modelContext.delete(item)
            }
            messages.removeAll()
            activeConversationID = UUID()
            setStoredActiveConversation(activeConversationID)
            appendMessage(content: "diet_assistant_welcome".localized, isUser: false)
            refreshConversationHistory()
        } catch {
            print("Failed to clear history: \(error)")
        }
    }

    private func messageWithRecentDietContext(_ userMessage: String) -> String {
        let languagePolicy = AppLanguagePolicy.current
        let recent = messages
            .dropLast()
            .filter { $0.topic == "diet" && !$0.isSystemAction && $0.mediaData == nil && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .suffix(6)

        guard !recent.isEmpty else { return userMessage }

        let transcript = recent.map { message in
            let role = message.isUser
                ? (languagePolicy.prefersSimplifiedChinese ? "用户" : "User")
                : (languagePolicy.prefersSimplifiedChinese ? "营养教练" : "Nutrition coach")
            return "\(role)：\(message.content.truncatedForAIContext(maxLength: 420))"
        }.joined(separator: "\n")

        if languagePolicy.prefersSimplifiedChinese {
            return """
            最近饮食对话上下文（只在相关时使用，不要逐字复述）：
            \(transcript)

            当前用户消息：
            \(userMessage)
            """
        }

        return """
        Recent diet conversation context. Use only when relevant and do not repeat it verbatim:
        \(transcript)

        Current user message:
        \(userMessage)
        """
    }
}
