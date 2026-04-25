//
//  SpeechSynthesizerService.swift
//  Faith Journal
//
//  Audio narration service for reading plans
//

import Foundation
import AVFoundation

@MainActor
class SpeechSynthesizerService: NSObject, ObservableObject {
    nonisolated(unsafe) private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func speak(_ text: String, rate: Float = 0.5) {
        stopSpeaking()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = rate
        synthesizer.speak(utterance)
        isSpeaking = true
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    func pauseSpeaking() {
        synthesizer.pauseSpeaking(at: .immediate)
    }
    
    func continueSpeaking() {
        synthesizer.continueSpeaking()
    }
}

extension SpeechSynthesizerService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}

