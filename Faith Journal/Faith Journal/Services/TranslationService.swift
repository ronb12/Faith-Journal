//
//  TranslationService.swift
//  Faith Journal
//
//  Language translation service for chat messages
//  Uses iOS native translation features when available
//
//  ✅ CONFIRMED: Uses iOS Native Translation APIs
//  - Language Detection: NLLanguageRecognizer (iOS 12+, Natural Language framework)
//  - Programmatic translation: TranslationSession(installedSource:target:) — iOS 26+ (SDK 26+)
//  (SwiftUI .translationTask is the non–iOS-26 path in views; not used here.)
//  Both use Apple's native translation infrastructure - no third-party APIs
//

import Foundation
import NaturalLanguage

#if canImport(Translation)
import Translation
#endif

@available(iOS 15.0, *)
@MainActor
class TranslationService: ObservableObject {
    static let shared = TranslationService()
    
    @Published var defaultTargetLanguage: String = {
        if #available(iOS 16.0, *) {
            return Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            return Locale.current.languageCode ?? "en"
        }
    }()
    
    private init() {}
    
    // Supported languages for translation
    // These languages are supported by iOS native Translation framework
    let supportedLanguages: [(code: String, name: String)] = [
        ("en", "English"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("zh", "Chinese (Simplified)"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("ar", "Arabic"),
        ("hi", "Hindi"),
        ("ru", "Russian"),
        ("tr", "Turkish"),
        ("nl", "Dutch"),
        ("pl", "Polish"),
        ("uk", "Ukrainian"),
        ("vi", "Vietnamese"),
        ("th", "Thai"),
        ("id", "Indonesian"),
        ("cs", "Czech"),
        ("sv", "Swedish"),
        ("ro", "Romanian"),
        ("he", "Hebrew"),
        ("da", "Danish"),
        ("fi", "Finnish"),
        ("no", "Norwegian"),
        ("hu", "Hungarian"),
        ("el", "Greek")
    ]
    
    // iOS Native Language Translator (available iOS 15+)
    // Note: iOS translation requires language model downloads on first use
    // and works offline once downloaded
    func translate(text: String, from sourceLanguage: String = "auto", to targetLanguage: String) async -> String? {
        guard !text.isEmpty else { return nil }
        
        // Return original if same language
        if sourceLanguage != "auto" && sourceLanguage == targetLanguage {
            return text
        }
        
        // Auto-detect source language if needed
        let detectedSource = sourceLanguage == "auto" ? await detectLanguage(text: text) : sourceLanguage
        
        // If detected source is same as target, return original
        if detectedSource == targetLanguage {
            return text
        }
        
        // Use iOS native translation when the OS supports it (see translateWithNLLanguageTranslator)
        return await translateWithNLLanguageTranslator(
            text: text,
            from: detectedSource,
            to: targetLanguage
        )
    }
    
    @available(iOS 15.0, *)
    private func translateWithNLLanguageTranslator(text: String, from sourceLanguage: String, to targetLanguage: String) async -> String? {
        // Non-UI TranslationSession.init(installedSource:target:) is iOS 26+ in the current SDK.
        // (SwiftUI .translationTask remains the path on iOS 18–25 in views.)
        if #available(iOS 26.0, *) {
            return await translateWithTranslationSession(text: text, from: sourceLanguage, to: targetLanguage)
        }
        print("ℹ️ Translation requested: \(sourceLanguage) → \(targetLanguage)")
        print("⚠️ Programmatic native translation requires iOS 26.0+.")
        return nil
    }
    
    /// iOS 26+ programmatic translation (see TranslationSession.init(installedSource:target:)).
    @available(iOS 26.0, *)
    private func translateWithTranslationSession(text: String, from sourceLanguage: String, to targetLanguage: String) async -> String? {
        #if canImport(Translation) && os(iOS)
        let sourceLang = Locale.Language(identifier: sourceLanguage)
        let targetLang = Locale.Language(identifier: targetLanguage)
        let session = TranslationSession(installedSource: sourceLang, target: targetLang)
        do {
            try await session.prepareTranslation()
            let response = try await session.translate(text)
            return response.targetText
        } catch {
            print("❌ TranslationSession error: \(error.localizedDescription)")
            if let nsError = error as NSError?,
               nsError.domain.contains("Translation") || nsError.localizedDescription.contains("model") {
                print("💡 Translation models may need to be downloaded. iOS will prompt automatically.")
            }
            return nil
        }
        #else
        print("⚠️ Translation framework not available")
        return nil
        #endif
    }
    
    // Detect language using iOS native language recognition
    func detectLanguage(text: String) async -> String {
        guard !text.isEmpty else { return "en" }
        
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        if let dominantLanguage = recognizer.dominantLanguage {
            return dominantLanguage.rawValue // Returns language code like "en", "es", etc.
        }
        
        // Fallback to English if detection fails
        return "en"
    }
    
    
    // Convert language code string to NLLanguage
    private func getNLLanguage(from code: String) -> NLLanguage? {
        // Handle common language code mappings
        let languageMap: [String: NLLanguage] = [
            "en": .english,
            "es": .spanish,
            "fr": .french,
            "de": .german,
            "it": .italian,
            "pt": .portuguese,
            "zh": .simplifiedChinese,
            "ja": .japanese,
            "ko": .korean,
            "ar": .arabic,
            "hi": .hindi,
            "ru": .russian,
            "tr": .turkish,
            "nl": .dutch,
            "pl": .polish,
            "uk": .ukrainian,
            "vi": .vietnamese,
            "th": .thai,
            "id": .indonesian,
            "cs": .czech,
            "sv": .swedish,
            "ro": .romanian,
            "he": .hebrew,
            "da": .danish,
            "fi": .finnish,
            "no": .norwegian,
            "hu": .hungarian,
            "el": .greek
        ]
        
        return languageMap[code.lowercased()]
    }
    
    func getLanguageName(for code: String) -> String {
        return supportedLanguages.first(where: { $0.code == code.lowercased() })?.name ?? code.uppercased()
    }
    
    // Check if translation is available for a language pair
    @available(iOS 15.0, *)
    func isTranslationAvailable(from sourceLanguage: String, to targetLanguage: String) -> Bool {
        // Check if both languages are in our supported list
        let supportedCodes = supportedLanguages.map { $0.code.lowercased() }
        return supportedCodes.contains(sourceLanguage.lowercased()) &&
               supportedCodes.contains(targetLanguage.lowercased()) &&
               sourceLanguage.lowercased() != targetLanguage.lowercased()
    }
}
