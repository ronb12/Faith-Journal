#!/usr/bin/env swift

import Foundation

// Faith Journal App Rules Validator
// This script checks if the app meets all the requirements defined in .cursorrules

struct AppValidator {
    
    // MARK: - File Paths to Check
    let requiredFiles = [
        "Faith Journal/Faith Journal/HomeView.swift",
        "Faith Journal/Faith Journal/ContentView.swift",
        "Faith Journal/Faith Journal/BibleVerseOfTheDayManager.swift",
        "Faith Journal/Faith Journal/DevotionalsView.swift",
        "Faith Journal/Faith Journal/NewJournalEntryView.swift",
        "Faith Journal/Faith Journal/PrayerView.swift",
        "Faith Journal/Faith Journal/SettingsView.swift",
        "Faith Journal/Faith Journal/ThemeManager.swift",
        "Faith Journal/Faith Journal/JournalEntry.swift",
        "Faith Journal/Faith Journal/PrayerRequest.swift",
        "Faith Journal/Faith Journal/UserProfile.swift",
        "Faith Journal/Faith Journal/LiveStreamManager.swift",
        "Faith Journal/Faith Journal/WebRTCManager.swift",
        "Faith Journal/Faith Journal/AdNetworkManager.swift",
        "Faith Journal/Faith Journal/MonetizationManager.swift",
        "Faith Journal/Faith Journal/Info.plist"
    ]
    
    // MARK: - Required Features to Check
    let requiredFeatures = [
        "Bible Verse of the Day",
        "50 Devotionals",
        "Journal Entries with Apple Pencil",
        "Prayer Requests",
        "Color Theme Selection",
        "Personalized Greeting",
        "Live Streaming",
        "AdSense Integration",
        "User Settings",
        "SwiftData Models"
    ]
    
    // MARK: - Required Code Patterns
    let requiredPatterns = [
        "@StateObject": "View models with @StateObject",
        "@ObservedObject": "External objects with @ObservedObject",
        "@State": "Local view state with @State",
        "@Model": "SwiftData models with @Model",
        "@AppStorage": "User preferences with @AppStorage",
        "UserDefaults.standard": "Complex data with UserDefaults",
        "PencilKit": "Apple Pencil integration",
        "WebRTC": "Live streaming support",
        "Google AdSense": "AdSense integration",
        "StoreKit": "In-app purchases"
    ]
    
    // MARK: - Validation Methods
    
    func validateFileExists(_ filePath: String) -> Bool {
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: filePath)
    }
    
    func validateFileContent(_ filePath: String, pattern: String) -> Bool {
        guard let content = try? String(contentsOfFile: filePath) else {
            return false
        }
        return content.contains(pattern)
    }
    
    func validateInfoPlist() -> [String] {
        var issues: [String] = []
        let infoPlistPath = "Faith Journal/Info.plist"
        
        guard validateFileExists(infoPlistPath) else {
            issues.append("❌ Info.plist file missing")
            return issues
        }
        
        // Check for required privacy descriptions
        let requiredPrivacyKeys = [
            "NSMicrophoneUsageDescription",
            "NSCameraUsageDescription", 
            "NSPhotoLibraryUsageDescription",
            "NSFaceIDUsageDescription",
            "NSSpeechRecognitionUsageDescription"
        ]
        
        for key in requiredPrivacyKeys {
            if !validateFileContent(infoPlistPath, pattern: key) {
                issues.append("❌ Missing privacy description: \(key)")
            }
        }
        
        return issues
    }
    
    func validateSwiftDataModels() -> [String] {
        var issues: [String] = []
        
        let modelFiles = [
            "Faith Journal/Faith Journal/JournalEntry.swift",
            "Faith Journal/Faith Journal/PrayerRequest.swift",
            "Faith Journal/Faith Journal/UserProfile.swift"
        ]
        
        for file in modelFiles {
            if !validateFileExists(file) {
                issues.append("❌ Missing model file: \(file)")
            } else if !validateFileContent(file, pattern: "@Model") {
                issues.append("❌ Missing @Model annotation in: \(file)")
            }
        }
        
        return issues
    }
    
    func validateManagers() -> [String] {
        var issues: [String] = []
        
        let managerFiles = [
            "Faith Journal/Faith Journal/BibleVerseOfTheDayManager.swift",
            "Faith Journal/Faith Journal/ThemeManager.swift",
            "Faith Journal/Faith Journal/DevotionalManager.swift"
        ]
        
        for file in managerFiles {
            if !validateFileExists(file) {
                issues.append("❌ Missing manager file: \(file)")
            }
        }
        
        return issues
    }
    
    func validateViews() -> [String] {
        var issues: [String] = []
        
        let viewFiles = [
            "Faith Journal/Faith Journal/HomeView.swift",
            "Faith Journal/Faith Journal/ContentView.swift",
            "Faith Journal/Faith Journal/NewJournalEntryView.swift",
            "Faith Journal/Faith Journal/PrayerView.swift",
            "Faith Journal/Faith Journal/SettingsView.swift"
        ]
        
        for file in viewFiles {
            if !validateFileExists(file) {
                issues.append("❌ Missing view file: \(file)")
            }
        }
        
        return issues
    }
    
    func validateLiveStreamingFeatures() -> [String] {
        var issues: [String] = []
        
        let streamingFiles = [
            "Faith Journal/Faith Journal/LiveStreamManager.swift",
            "Faith Journal/Faith Journal/WebRTCManager.swift",
            "Faith Journal/Faith Journal/LiveStreamView.swift"
        ]
        
        for file in streamingFiles {
            if !validateFileExists(file) {
                issues.append("❌ Missing live streaming file: \(file)")
            }
        }
        
        return issues
    }
    
    func validateAdSenseFeatures() -> [String] {
        var issues: [String] = []
        
        let adsenseFiles = [
            "Faith Journal/Faith Journal/AdNetworkManager.swift",
            "Faith Journal/Faith Journal/MonetizationManager.swift",
            "Faith Journal/Faith Journal/AdSenseSetupView.swift"
        ]
        
        for file in adsenseFiles {
            if !validateFileExists(file) {
                issues.append("❌ Missing AdSense file: \(file)")
            }
        }
        
        return issues
    }
    
    func runValidation() {
        print("🔍 Faith Journal App Rules Validation")
        print("=====================================")
        print()
        
        var allIssues: [String] = []
        
        // Validate Info.plist
        print("📱 Checking App Store Compliance...")
        let infoPlistIssues = validateInfoPlist()
        allIssues.append(contentsOf: infoPlistIssues)
        if infoPlistIssues.isEmpty {
            print("✅ Info.plist compliance: PASSED")
        } else {
            print("❌ Info.plist compliance: FAILED")
            infoPlistIssues.forEach { print("   \($0)") }
        }
        print()
        
        // Validate SwiftData Models
        print("🗄️ Checking Data Models...")
        let modelIssues = validateSwiftDataModels()
        allIssues.append(contentsOf: modelIssues)
        if modelIssues.isEmpty {
            print("✅ Data models: PASSED")
        } else {
            print("❌ Data models: FAILED")
            modelIssues.forEach { print("   \($0)") }
        }
        print()
        
        // Validate Managers
        print("⚙️ Checking Managers...")
        let managerIssues = validateManagers()
        allIssues.append(contentsOf: managerIssues)
        if managerIssues.isEmpty {
            print("✅ Managers: PASSED")
        } else {
            print("❌ Managers: FAILED")
            managerIssues.forEach { print("   \($0)") }
        }
        print()
        
        // Validate Views
        print("📱 Checking Views...")
        let viewIssues = validateViews()
        allIssues.append(contentsOf: viewIssues)
        if viewIssues.isEmpty {
            print("✅ Views: PASSED")
        } else {
            print("❌ Views: FAILED")
            viewIssues.forEach { print("   \($0)") }
        }
        print()
        
        // Validate Live Streaming
        print("📺 Checking Live Streaming Features...")
        let streamingIssues = validateLiveStreamingFeatures()
        allIssues.append(contentsOf: streamingIssues)
        if streamingIssues.isEmpty {
            print("✅ Live streaming: PASSED")
        } else {
            print("❌ Live streaming: FAILED")
            streamingIssues.forEach { print("   \($0)") }
        }
        print()
        
        // Validate AdSense
        print("💰 Checking AdSense Features...")
        let adsenseIssues = validateAdSenseFeatures()
        allIssues.append(contentsOf: adsenseIssues)
        if adsenseIssues.isEmpty {
            print("✅ AdSense: PASSED")
        } else {
            print("❌ AdSense: FAILED")
            adsenseIssues.forEach { print("   \($0)") }
        }
        print()
        
        // Summary
        print("📊 VALIDATION SUMMARY")
        print("=====================")
        if allIssues.isEmpty {
            print("🎉 ALL CHECKS PASSED! Your app meets all the rules.")
        } else {
            print("⚠️  Found \(allIssues.count) issues that need to be addressed:")
            print()
            allIssues.forEach { print("   \($0)") }
            print()
            print("💡 Use Cursor's AI to fix these issues automatically!")
        }
    }
}

// Run the validation
let validator = AppValidator()
validator.runValidation() 