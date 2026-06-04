import SwiftUI
import SwiftData
import PhotosUI

struct DietAIAssistantView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var viewModel: DietAssistantViewModel
    @FocusState private var isInputFocused: Bool
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showClearAlert = false
    @AppStorage("hasAcceptedMedicalDisclaimer") private var hasAcceptedDisclaimer = false
    @State private var showDisclaimerAlert = false
    @State private var showLoginSheet = false

    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: DietAssistantViewModel(modelContext: modelContext))
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

            if !auth.hasBackendSession {
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
                                Text(viewModel.loadingText)
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
            
            // 媒体预览区 (类似 AIAssistantView)
            if viewModel.pendingMediaData != nil {
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
                .padding(.horizontal)
                .padding(.top, 8)
            }

			EnhancedInputControlsView(
				configuration: .dietAssistant,
				inputText: $viewModel.inputText,
				isFocused: $isInputFocused,
				isLoading: viewModel.isLoading,
                canSendEmpty: viewModel.pendingMediaData != nil,
				onSend: {
                    guard auth.hasBackendSession else {
                        showLoginSheet = true
                        return
                    }
					Task { await viewModel.sendMessage() }
				},
				onCameraCapture: {
                    showCamera = true
                },
				onPhotoSelected: { item in
					Task {
						if let data = try? await item.loadTransferable(type: Data.self) {
                            viewModel.handleMediaSelection(data: data)
						}
					}
				}
			)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { isInputFocused = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showClearAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .navigationTitle("AI 饮食助手")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCamera) {
            CameraPicker(selectedImage: $capturedImage)
        }
        .sheet(isPresented: $showDisclaimerAlert) {
            MedicalDisclaimerView(isPresented: $showDisclaimerAlert)
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView()
        }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage, let data = image.jpegData(compressionQuality: 0.8) {
                viewModel.handleMediaSelection(data: data)
                capturedImage = nil
            }
        }
        .alert("清空记录", isPresented: $showClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                viewModel.clearHistory()
            }
        } message: {
            Text("确定要清空所有聊天记录吗？此操作无法撤销。")
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
    }
}
