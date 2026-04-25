//
//  WatchConnectivityService.swift
//  Faith Journal
//
//  Watch Connectivity service for syncing data between iPhone and Apple Watch
//

import Foundation
import SwiftData
#if os(iOS)
import WatchConnectivity

@available(iOS 17.0, *)
@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()
    
    @Published var isReachable = false
    @Published var isPaired = false
    @Published var isWatchAppInstalled = false
    
    private var session: WCSession?
    private var modelContext: ModelContext?
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            
            isPaired = session?.isPaired ?? false
            isWatchAppInstalled = session?.isWatchAppInstalled ?? false
            isReachable = session?.isReachable ?? false
            
            print("⌚ [WATCH] Watch Connectivity initialized")
            print("⌚ [WATCH] Paired: \(isPaired), Installed: \(isWatchAppInstalled), Reachable: \(isReachable)")
        } else {
            print("⚠️ [WATCH] Watch Connectivity not supported on this device")
        }
    }
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        print("⌚ [WATCH] ModelContext configured")
    }
    
    // MARK: - Send Data to Watch
    
    /// Send a journal entry to the Watch
    func sendJournalEntry(_ entry: JournalEntry) {
        guard let session = session, session.isReachable else {
            // Use application context for background updates
            updateApplicationContext()
            return
        }
        
        let entryData: [String: Any] = [
            "id": entry.id.uuidString,
            "title": entry.title,
            "content": entry.content,
            "date": entry.date.timeIntervalSince1970,
            "mood": entry.mood ?? "",
            "isPrivate": entry.isPrivate
        ]
        
        session.sendMessage(["type": "journalEntry", "data": entryData], replyHandler: nil) { error in
            print("❌ [WATCH] Failed to send journal entry: \(error.localizedDescription)")
        }
        
        print("✅ [WATCH] Sent journal entry to Watch: \(entry.title)")
    }
    
    /// Send a prayer request to the Watch
    func sendPrayerRequest(_ request: PrayerRequest) {
        guard let session = session, session.isReachable else {
            updateApplicationContext()
            return
        }
        
        let requestData: [String: Any] = [
            "id": request.id.uuidString,
            "title": request.title,
            "details": request.details,
            "isAnswered": request.isAnswered,
            "createdAt": request.createdAt.timeIntervalSince1970
        ]
        
        session.sendMessage(["type": "prayerRequest", "data": requestData], replyHandler: nil) { error in
            print("❌ [WATCH] Failed to send prayer request: \(error.localizedDescription)")
        }
        
        print("✅ [WATCH] Sent prayer request to Watch: \(request.title)")
    }
    
    /// Send a mood entry to the Watch
    func sendMoodEntry(_ entry: MoodEntry) {
        guard let session = session, session.isReachable else {
            updateApplicationContext()
            return
        }
        
        let moodData: [String: Any] = [
            "id": entry.id.uuidString,
            "mood": entry.mood,
            "intensity": entry.intensity,
            "date": entry.date.timeIntervalSince1970,
            "notes": entry.notes ?? ""
        ]
        
        session.sendMessage(["type": "moodEntry", "data": moodData], replyHandler: nil) { error in
            print("❌ [WATCH] Failed to send mood entry: \(error.localizedDescription)")
        }
        
        print("✅ [WATCH] Sent mood entry to Watch")
    }
    
    /// Send Bible verse of the day to Watch
    func sendBibleVerse(_ verse: BibleVerse) {
        guard let session = session else { return }
        
        let verseData: [String: Any] = [
            "reference": verse.reference,
            "text": verse.text,
            "translation": verse.translation
        ]
        
        // Use application context so it's available even when Watch app isn't running
        var context = session.applicationContext
        context["verseOfTheDay"] = verseData
        context["verseUpdatedAt"] = Date().timeIntervalSince1970
        
        do {
            try session.updateApplicationContext(context)
            print("✅ [WATCH] Updated Bible verse of the day in application context")
        } catch {
            print("❌ [WATCH] Failed to update application context: \(error.localizedDescription)")
        }
    }
    
    /// Send devotional of the day to Watch
    func sendDevotional(_ devotional: Devotional) {
        guard let session = session else { return }
        
        let devotionalData: [String: Any] = [
            "id": devotional.id.uuidString,
            "title": devotional.title,
            "scripture": devotional.scripture,
            "content": devotional.content,
            "author": devotional.author,
            "category": devotional.category,
            "date": devotional.date.timeIntervalSince1970
        ]
        
        // Use application context so it's available even when Watch app isn't running
        var context = session.applicationContext
        context["devotionalOfTheDay"] = devotionalData
        context["devotionalUpdatedAt"] = Date().timeIntervalSince1970
        
        do {
            try session.updateApplicationContext(context)
            print("✅ [WATCH] Updated devotional of the day in application context")
        } catch {
            print("❌ [WATCH] Failed to update devotional in application context: \(error.localizedDescription)")
        }
    }
    
    /// Update application context with latest data
    private func updateApplicationContext() {
        guard let session = session, let modelContext = modelContext else { return }
        
        var context: [String: Any] = [:]
        
        // Get recent journal entries
        let journalDescriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\JournalEntry.createdAt, order: .reverse)]
        )
        if let entries = try? modelContext.fetch(journalDescriptor).prefix(5) {
            context["recentEntries"] = entries.map { entry in
                [
                    "id": entry.id.uuidString,
                    "title": entry.title,
                    "date": entry.date.timeIntervalSince1970
                ]
            }
        }
        
        // Get active prayer requests
        let prayerDescriptor = FetchDescriptor<PrayerRequest>(
            predicate: #Predicate<PrayerRequest> { !$0.isAnswered },
            sortBy: [SortDescriptor(\PrayerRequest.createdAt, order: .reverse)]
        )
        if let requests = try? modelContext.fetch(prayerDescriptor).prefix(5) {
            context["activePrayers"] = requests.map { request in
                [
                    "id": request.id.uuidString,
                    "title": request.title,
                    "createdAt": request.createdAt.timeIntervalSince1970
                ]
            }
        }
        
        context["lastSync"] = Date().timeIntervalSince1970
        
        do {
            try session.updateApplicationContext(context)
            print("✅ [WATCH] Updated application context")
        } catch {
            print("❌ [WATCH] Failed to update application context: \(error.localizedDescription)")
        }
    }
    
    /// Sync all data to Watch
    func syncAllData() {
        updateApplicationContext()
        
        // Also send Bible verse if available
        if let verse = BibleVerseOfTheDayManager.shared.currentVerse {
            sendBibleVerse(verse)
        }
        
        // Also send devotional if available
        if let devotional = DevotionalManager.shared.getTodaysDevotional() {
            sendDevotional(devotional)
        }
    }
}

// MARK: - WCSessionDelegate

@available(iOS 17.0, *)
extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ [WATCH] Session activation failed: \(error.localizedDescription)")
            return
        }
        
        print("✅ [WATCH] Session activated with state: \(activationState.rawValue)")
        Task { @MainActor in
            isPaired = session.isPaired
            isWatchAppInstalled = session.isWatchAppInstalled
            isReachable = session.isReachable
            
            // Sync data when session becomes active
            if activationState == .activated {
                syncAllData()
            }
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ [WATCH] Session became inactive")
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("⚠️ [WATCH] Session deactivated")
        // Reactivate session
        session.activate()
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
            print("⌚ [WATCH] Reachability changed: \(isReachable)")
            
            if isReachable {
                syncAllData()
            }
        }
    }
    
    // Handle messages from Watch
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("📨 [WATCH] Received message from Watch: \(message)")
        
        Task { @MainActor in
            guard let type = message["type"] as? String,
                  let modelContext = modelContext else { return }
        
        switch type {
        case "createJournalEntry":
            if let data = message["data"] as? [String: Any],
               let title = data["title"] as? String,
               let content = data["content"] as? String {
                let entry = JournalEntry(title: title, content: content)
                modelContext.insert(entry)
                try? modelContext.save()
                
                // Sync to Firebase
                Task {
                    await FirebaseSyncService.shared.syncJournalEntry(entry)
                }
                
                print("✅ [WATCH] Created journal entry from Watch")
            }
            
        case "createMoodEntry":
            if let data = message["data"] as? [String: Any],
               let moodString = data["mood"] as? String {
                let intensity = data["intensity"] as? Int ?? 5
                let entry = MoodEntry(mood: moodString, intensity: intensity, notes: data["notes"] as? String)
                modelContext.insert(entry)
                try? modelContext.save()
                
                // Sync to Firebase
                Task {
                    await FirebaseSyncService.shared.syncMoodEntry(entry)
                }
                
                print("✅ [WATCH] Created mood entry from Watch")
            }
            
        case "requestSync":
            syncAllData()
            
        default:
            print("⚠️ [WATCH] Unknown message type: \(type)")
        }
        }
    }
}
#else
/// Stub for macOS - Watch Connectivity not available
@available(macOS 14.0, *)
@MainActor
class WatchConnectivityService: ObservableObject {
    static let shared = WatchConnectivityService()
    @Published var isReachable = false
    @Published var isPaired = false
    @Published var isWatchAppInstalled = false
    func configure(modelContext: ModelContext) {}
    func sendJournalEntry(_ entry: JournalEntry) {}
    func sendPrayerRequest(_ request: PrayerRequest) {}
}
#endif

