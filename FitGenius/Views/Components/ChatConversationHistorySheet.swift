import SwiftUI

struct ChatConversationHistorySheet: View {
    let conversations: [ChatConversationSummary]
    let activeConversationID: UUID?
    let onStartNew: () -> Void
    let onSelect: (UUID?) -> Void
    let onDelete: (UUID?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onStartNew()
                        dismiss()
                    } label: {
                        Label("chat_start_new_conversation", systemImage: "square.and.pencil")
                    }
                }

                Section("chat_history") {
                    ForEach(conversations) { conversation in
                        Button {
                            onSelect(conversation.sessionID)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: conversation.sessionID == nil ? "archivebox" : "bubble.left.and.bubble.right")
                                    .foregroundStyle(.secondary)
                                Text(conversation.title)
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                if conversation.sessionID == activeConversationID {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                onDelete(conversation.sessionID)
                            } label: {
                                Label("chat_delete_conversation", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("chat_history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                }
            }
        }
    }
}
