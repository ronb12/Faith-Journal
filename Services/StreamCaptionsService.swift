//
//  StreamCaptionsService.swift
//  Faith Journal
//
//  Closed captions and transcription service
//

import Foundation
import AVFoundation
import Speech

@MainActor
@available(iOS 17.0, macOS 14.0, *)
class StreamCaptionsService: ObservableObject {
    static let shared = StreamCaptionsService()
    
    @Published var isTranscribing = false
    @Published var currentCaption: String = ""
    @Published var captionHistory: [CaptionEntry] = []
    @Published var captionStyle: CaptionStyle = .default
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    struct CaptionEntry: Identifiable {
        let id = UUID()
        let text: String
        let timestamp: Date
        let speaker: String?
    }
    
    struct CaptionStyle {
        var fontSize: CGFloat = 18
        var fontColor: String = "#FFFFFF"
        var backgroundColor: String = "#00000080"
        var position: CaptionPosition = .bottom
        var showBackground: Bool = true
        
        static let `default` = CaptionStyle()
    }
    
    enum CaptionPosition {
        case top
        case bottom
        case center
    }
    
    private init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    func startTranscription() async throws {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw CaptionError.recognizerUnavailable
        }
        
        let status = SFSpeechRecognizer.authorizationStatus()
        if status != .authorized {
            let authStatus = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            guard authStatus == .authorized else {
                throw CaptionError.permissionDenied
            }
        }
        
        // Stop any existing recognition
        stopTranscription()
        
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #elseif os(macOS)
        // Audio capture for speech recognition on macOS would require different setup
        throw CaptionError.recognizerUnavailable
        #endif
        
        #if os(iOS)
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw CaptionError.failedToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                Task { @MainActor in
                    self.currentCaption = result.bestTranscription.formattedString
                    
                    // Add to history when final
                    if result.isFinal {
                        let entry = CaptionEntry(
                            text: result.bestTranscription.formattedString,
                            timestamp: Date(),
                            speaker: nil
                        )
                        self.captionHistory.append(entry)
                    }
                }
            }
            
            if error != nil {
                self.stopTranscription()
            }
        }
        isTranscribing = true
        #endif
    }
    
    func stopTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        isTranscribing = false
        currentCaption = ""
    }
    
    func clearHistory() {
        captionHistory.removeAll()
    }
}

enum CaptionError: LocalizedError {
    case recognizerUnavailable
    case permissionDenied
    case failedToCreateRequest
    
    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognizer is not available"
        case .permissionDenied:
            return "Speech recognition permission denied"
        case .failedToCreateRequest:
            return "Failed to create recognition request"
        }
    }
}

