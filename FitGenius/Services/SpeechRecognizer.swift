import Foundation
import Speech
import AVFoundation
import Combine

// MARK: - 语音识别服务
/// 使用 Apple Speech Framework 实现语音转文字功能
@MainActor
class SpeechRecognizer: ObservableObject {
    // MARK: - Published Properties
    
    /// 当前识别的文本
    @Published var recognizedText: String = ""
    
    /// 是否正在录音
    @Published var isRecording: Bool = false
    
    /// 授权状态
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    /// 错误信息
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Initialization
    
    init() {
        // 初始化语音识别器，支持简体中文
        // 如果需要英文，可以使用 Locale(identifier: "en-US")
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        
        // 检查当前授权状态
        self.authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }
    
    // MARK: - Public Methods
    
    /// 请求语音识别和麦克风权限
    func requestAuthorization() async {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    continuation.resume()
                }
            }
        }
    }
    
    /// 开始录音和语音识别
    func startRecording() async throws {
        // 检查权限
        guard authorizationStatus == .authorized else {
            errorMessage = "语音识别权限未授权"
            throw SpeechRecognizerError.notAuthorized
        }
        
        // 检查语音识别器是否可用
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "语音识别服务不可用"
            throw SpeechRecognizerError.recognizerNotAvailable
        }
        
        // 如果已经在录音，先停止
        if audioEngine.isRunning {
            stopRecording()
            return
        }
        
        do {
            // 配置音频会话
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // 创建识别请求
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            guard let recognitionRequest = recognitionRequest else {
                throw SpeechRecognizerError.unableToCreateRequest
            }
            
            // 配置请求
            recognitionRequest.shouldReportPartialResults = true // 实时返回结果
            
            // 配置音频引擎
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            // 开始识别任务
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] (result: SFSpeechRecognitionResult?, error: Error?) in
                guard let self = self else { return }
                
                Task { @MainActor in
                    var isFinal = false
                    
                    if let result = result {
                        // 更新识别的文本
                        self.recognizedText = result.bestTranscription.formattedString
                        isFinal = result.isFinal
                    }
                    
                    if error != nil || isFinal {
                        // 发生错误或识别完成，停止录音
                        self.stopRecording()
                        
                        if let error = error {
                            self.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            
            // 启动音频引擎
            audioEngine.prepare()
            try audioEngine.start()
            
            isRecording = true
            errorMessage = nil
            
        } catch {
            errorMessage = "启动录音失败: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// 停止录音和语音识别
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRecording = false
    }
    
    /// 重置识别的文本
    func resetText() {
        recognizedText = ""
        errorMessage = nil
    }
}

// MARK: - Errors

enum SpeechRecognizerError: Error, LocalizedError {
    case notAuthorized
    case recognizerNotAvailable
    case unableToCreateRequest
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "语音识别权限未授权，请在设置中允许访问语音识别"
        case .recognizerNotAvailable:
            return "语音识别服务暂时不可用"
        case .unableToCreateRequest:
            return "无法创建语音识别请求"
        }
    }
}
