import SwiftUI
import PhotosUI
import Speech

// MARK: - 增强输入控件配置
struct InputControlsConfiguration {
    var showCamera: Bool = false
    var showMicrophone: Bool = true
    var showPhotoLibrary: Bool = false
    var photoLibraryFilter: PHPickerFilter = .images
    var placeholder: String = "assistant_input_placeholder".localized
    
    static let dietAssistant = InputControlsConfiguration(
        showCamera: true,
        showMicrophone: true,
        showPhotoLibrary: true,
        photoLibraryFilter: .images,
        placeholder: "diet_assistant_input_placeholder".localized
    )
    
    static let fitnessAssistant = InputControlsConfiguration(
        showCamera: false,
        showMicrophone: true,
        showPhotoLibrary: true,
        photoLibraryFilter: .any(of: [.images, .videos]),
        placeholder: "fitness_assistant_input_placeholder".localized
    )
}

// MARK: - 增强输入控件视图
struct EnhancedInputControlsView: View {
    // MARK: - Properties
    
    let configuration: InputControlsConfiguration
    @Binding var inputText: String
    @FocusState.Binding var isFocused: Bool
    let isLoading: Bool
    var isPreparingMedia: Bool = false
    var canSendEmpty: Bool = false
    
    // 回调
    let onSend: () -> Void
    let onCameraCapture: (() -> Void)?
    let onPhotoSelected: ((PhotosPickerItem) -> Void)?
    
    // MARK: - State
    
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var showingPermissionAlert = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 10) {
            // 拍照按钮（仅饮食助手显示）
            if configuration.showCamera {
                Button(action: handleCameraAction) {
                    Image(systemName: "camera.fill")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .disabled(isLoading || isPreparingMedia)
            }
            
            // 文本输入框
            TextField(configuration.placeholder, text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit {
                    if !inputText.isEmpty || canSendEmpty {
                        onSend()
                    }
                }
                .onChange(of: speechRecognizer.recognizedText) { _, newValue in
                    if speechRecognizer.isRecording {
                        inputText = newValue
                    }
                }
            
            // 麦克风按钮
            if configuration.showMicrophone {
                Button(action: handleMicrophoneAction) {
                    Image(systemName: speechRecognizer.isRecording ? "mic.fill" : "mic")
                        .font(.title3)
                        .foregroundColor(speechRecognizer.isRecording ? .red : .primary)
                }
                .buttonStyle(.plain)
                .disabled(isLoading || isPreparingMedia)
            }
            
            // 相册按钮
            if configuration.showPhotoLibrary {
                PhotosPicker(selection: $selectedPhotoItem, matching: configuration.photoLibraryFilter) {
                    ZStack {
                        Image(systemName: "photo.fill")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .opacity(isPreparingMedia ? 0.25 : 1)
                        if isPreparingMedia {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoading || isPreparingMedia)
                .onChange(of: selectedPhotoItem) { _, newItem in
                    if let newItem = newItem {
                        onPhotoSelected?(newItem)
                        Task { @MainActor in
                            selectedPhotoItem = nil
                        }
                    }
                }
            }
            
            // 发送按钮
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor((inputText.isEmpty && !canSendEmpty) ? .gray : .blue)
            }
            .disabled((inputText.isEmpty && !canSendEmpty) || isLoading || isPreparingMedia)
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.systemBackground))
        .alert("需要权限", isPresented: $showingPermissionAlert) {
            Button("去设置", action: openSettings)
            Button("取消", role: .cancel) { }
        } message: {
            if let errorMessage = speechRecognizer.errorMessage {
                Text(errorMessage)
            } else {
                Text("需要麦克风和语音识别权限才能使用语音输入功能")
            }
        }
        .overlay(alignment: .top) {
            // 语音识别状态提示
            if speechRecognizer.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.8).repeatForever(), value: speechRecognizer.isRecording)
                    
                    Text("正在录音...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 4)
                .offset(y: -40)
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleCameraAction() {
        onCameraCapture?()
    }
    
    private func handleMicrophoneAction() {
        Task {
            if speechRecognizer.isRecording {
                // 停止录音
                speechRecognizer.stopRecording()
            } else {
                // 检查权限
                if speechRecognizer.authorizationStatus == .notDetermined {
                    await speechRecognizer.requestAuthorization()
                }
                
                // 开始录音
                if speechRecognizer.authorizationStatus == .authorized {
                    do {
                        speechRecognizer.resetText()
                        try await speechRecognizer.startRecording()
                    } catch {
                        showingPermissionAlert = true
                    }
                } else {
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var text = ""
    @Previewable @FocusState var isFocused: Bool
    
    VStack {
        Spacer()
        
        EnhancedInputControlsView(
            configuration: .dietAssistant,
            inputText: $text,
            isFocused: $isFocused,
            isLoading: false,
            onSend: {
                print("Send: \(text)")
                text = ""
            },
            onCameraCapture: {
                print("Camera capture")
            },
            onPhotoSelected: { item in
                print("Photo selected: \(item)")
            }
        )
    }
}
