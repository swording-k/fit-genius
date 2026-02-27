import SwiftUI
import PhotosUI
import Speech

// MARK: - 增强输入控件配置
struct InputControlsConfiguration {
    var showCamera: Bool = false
    var showMicrophone: Bool = true
    var showPhotoLibrary: Bool = false
    var photoLibraryFilter: PHPickerFilter = .images
    var placeholder: String = "输入消息..."
    
    static let dietAssistant = InputControlsConfiguration(
        showCamera: true,
        showMicrophone: true,
        showPhotoLibrary: true,
        photoLibraryFilter: .images,
        placeholder: "询问饮食建议或拍照识别食物..."
    )
    
    static let fitnessAssistant = InputControlsConfiguration(
        showCamera: false,
        showMicrophone: true,
        showPhotoLibrary: true,
        photoLibraryFilter: .any(of: [.images, .videos]),
        placeholder: "上传身材照或训练视频并询问健身建议..."
    )
}

// MARK: - 增强输入控件视图
struct EnhancedInputControlsView: View {
    // MARK: - Properties
    
    let configuration: InputControlsConfiguration
    @Binding var inputText: String
    @FocusState.Binding var isFocused: Bool
    let isLoading: Bool
    
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
                .disabled(isLoading)
            }
            
            // 文本输入框
            TextField(configuration.placeholder, text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit {
                    if !inputText.isEmpty {
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
                .disabled(isLoading)
            }
            
            // 相册按钮
            if configuration.showPhotoLibrary {
                PhotosPicker(selection: $selectedPhotoItem, matching: configuration.photoLibraryFilter) {
                    Image(systemName: "photo.fill")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .onChange(of: selectedPhotoItem) { _, newItem in
                    if let newItem = newItem {
                        onPhotoSelected?(newItem)
                    }
                }
            }
            
            // 发送按钮
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(inputText.isEmpty ? .gray : .blue)
            }
            .disabled(inputText.isEmpty || isLoading)
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
