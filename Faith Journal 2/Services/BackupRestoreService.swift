//
//  BackupRestoreService.swift
//  Faith Journal
//
//  Comprehensive backup and restore system
//

import Foundation
import SwiftData
import PDFKit
import UniformTypeIdentifiers

@available(iOS 17.0, *)
@MainActor
class BackupRestoreService: ObservableObject {
    static let shared = BackupRestoreService()
    
    @Published var isBackingUp = false
    @Published var backupProgress: Double = 0.0
    @Published var lastBackupDate: Date?
    @Published var automaticBackupsEnabled = true
    @Published var backupFrequency: BackupFrequency = .weekly
    
    enum BackupFrequency: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
    }
    
    private let userDefaults = UserDefaults.standard
    private let maxBackupVersions = 5
    
    struct BackupMetadata: Codable {
        let version: String
        let timestamp: Date
        let deviceInfo: String
        let dataCounts: DataCounts
        
        struct DataCounts: Codable {
            let journalEntries: Int
            let prayerRequests: Int
            let moodEntries: Int
            let bookmarkedVerses: Int
            let bibleHighlights: Int
            let bibleNotes: Int
            let readingPlans: Int
        }
    }
    
    struct BackupData: Codable {
        let metadata: BackupMetadata
        let journalEntries: [JournalEntryExport]
        let prayerRequests: [PrayerRequestExport]
        let moodEntries: [MoodEntryExport]
        let bookmarkedVerses: [BookmarkedVerseExport]
        let bibleHighlights: [BibleHighlightExport]
        let bibleNotes: [BibleNoteExport]
        let readingPlans: [ReadingPlanExport]
    }
    
    // Export models (Codable versions)
    struct JournalEntryExport: Codable {
        let id: String
        let title: String
        let content: String
        let date: Date
        let tags: [String]
        let mood: String?
        let location: String?
        let isPrivate: Bool
        let createdAt: Date
        let updatedAt: Date
        // Note: Media files (photos, audio, drawings) stored as URLs/paths
    }
    
    struct PrayerRequestExport: Codable {
        let id: String
        let title: String
        let details: String
        let status: String
        let isAnswered: Bool
        let answerDate: Date?
        let answerNotes: String?
        let isPrivate: Bool
        let tags: [String]
        let createdAt: Date
        let updatedAt: Date
    }
    
    struct MoodEntryExport: Codable {
        let id: String
        let date: Date
        let mood: String
        let intensity: Int
        let notes: String?
        let tags: [String]
        let moodCategory: String
        let emoji: String
        let location: String?
        let weather: String?
        let timeOfDay: String
        let activities: [String]
        let energyLevel: Int
    }
    
    struct BookmarkedVerseExport: Codable {
        let id: String
        let verseReference: String
        let verseText: String
        let translation: String
        let notes: String
        let createdAt: Date
    }
    
    struct BibleHighlightExport: Codable {
        let id: String
        let verseReference: String
        let verseText: String
        let translation: String
        let colorIndex: Int
        let createdAt: Date
    }
    
    struct BibleNoteExport: Codable {
        let id: String
        let verseReference: String
        let verseText: String
        let translation: String
        let noteText: String
        let createdAt: Date
        let updatedAt: Date
    }
    
    struct ReadingPlanExport: Codable {
        let id: String
        let title: String
        let planDescription: String
        let duration: Int
        let startDate: Date
        let endDate: Date?
        let currentDay: Int
        let isCompleted: Bool
        let category: String
        let difficulty: String
        let isCustom: Bool
    }
    
    private init() {
        loadPreferences()
    }
    
    // MARK: - Preferences
    
    private func loadPreferences() {
        automaticBackupsEnabled = userDefaults.bool(forKey: "automaticBackupsEnabled", defaultValue: true)
        
        if let frequencyString = userDefaults.string(forKey: "backupFrequency"),
           let frequency = BackupFrequency(rawValue: frequencyString) {
            backupFrequency = frequency
        }
        
        if let lastBackup = userDefaults.object(forKey: "lastBackupDate") as? Date {
            lastBackupDate = lastBackup
        }
    }
    
    func savePreferences() {
        userDefaults.set(automaticBackupsEnabled, forKey: "automaticBackupsEnabled")
        userDefaults.set(backupFrequency.rawValue, forKey: "backupFrequency")
    }
    
    // MARK: - Create Backup
    
    func createBackup(modelContext: ModelContext) async throws -> URL {
        isBackingUp = true
        backupProgress = 0.0
        
        defer {
            isBackingUp = false
            backupProgress = 0.0
        }
        
        // Fetch all data
        backupProgress = 0.1
        
        let journalEntries = try fetchJournalEntries(modelContext: modelContext)
        backupProgress = 0.2
        
        let prayerRequests = try fetchPrayerRequests(modelContext: modelContext)
        backupProgress = 0.3
        
        let moodEntries = try fetchMoodEntries(modelContext: modelContext)
        backupProgress = 0.4
        
        let bookmarkedVerses = try fetchBookmarkedVerses(modelContext: modelContext)
        backupProgress = 0.5
        
        let bibleHighlights = try fetchBibleHighlights(modelContext: modelContext)
        backupProgress = 0.6
        
        let bibleNotes = try fetchBibleNotes(modelContext: modelContext)
        backupProgress = 0.7
        
        let readingPlans = try fetchReadingPlans(modelContext: modelContext)
        backupProgress = 0.8
        
        // Create metadata
        let metadata = BackupMetadata(
            version: "1.0",
            timestamp: Date(),
            deviceInfo: UIDevice.current.model,
            dataCounts: BackupMetadata.DataCounts(
                journalEntries: journalEntries.count,
                prayerRequests: prayerRequests.count,
                moodEntries: moodEntries.count,
                bookmarkedVerses: bookmarkedVerses.count,
                bibleHighlights: bibleHighlights.count,
                bibleNotes: bibleNotes.count,
                readingPlans: readingPlans.count
            )
        )
        
        // Create backup data structure
        let backupData = BackupData(
            metadata: metadata,
            journalEntries: journalEntries,
            prayerRequests: prayerRequests,
            moodEntries: moodEntries,
            bookmarkedVerses: bookmarkedVerses,
            bibleHighlights: bibleHighlights,
            bibleNotes: bibleNotes,
            readingPlans: readingPlans
        )
        
        // Encode to JSON
        backupProgress = 0.9
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        guard let jsonData = try? encoder.encode(backupData) else {
            throw BackupError.encodingFailed
        }
        
        // Save to file
        let filename = "FaithJournal_Backup_\(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")).json"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let backupURL = documentsPath.appendingPathComponent(filename)
        
        try jsonData.write(to: backupURL)
        
        // Update last backup date
        lastBackupDate = Date()
        userDefaults.set(lastBackupDate, forKey: "lastBackupDate")
        
        // Clean up old backups
        await cleanupOldBackups()
        
        backupProgress = 1.0
        
        print("✅ Backup created: \(backupURL.lastPathComponent)")
        print("📊 Backup contains: \(metadata.dataCounts.journalEntries) entries, \(metadata.dataCounts.prayerRequests) prayers, \(metadata.dataCounts.moodEntries) mood entries")
        
        return backupURL
    }
    
    // MARK: - Fetch Data
    
    private func fetchJournalEntries(modelContext: ModelContext) throws -> [JournalEntryExport] {
        let descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\JournalEntry.date, order: .reverse)]
        )
        
        let entries = try modelContext.fetch(descriptor)
        
        return entries.map { entry in
            JournalEntryExport(
                id: entry.id.uuidString,
                title: entry.title,
                content: entry.content,
                date: entry.date,
                tags: entry.tags,
                mood: entry.mood,
                location: entry.location,
                isPrivate: entry.isPrivate,
                createdAt: entry.createdAt,
                updatedAt: entry.updatedAt
            )
        }
    }
    
    private func fetchPrayerRequests(modelContext: ModelContext) throws -> [PrayerRequestExport] {
        let descriptor = FetchDescriptor<PrayerRequest>(
            sortBy: [SortDescriptor(\PrayerRequest.createdAt, order: .reverse)]
        )
        
        let requests = try modelContext.fetch(descriptor)
        
        return requests.map { request in
            PrayerRequestExport(
                id: request.id.uuidString,
                title: request.title,
                details: request.details,
                status: request.status.rawValue,
                isAnswered: request.isAnswered,
                answerDate: request.answerDate,
                answerNotes: request.answerNotes,
                isPrivate: request.isPrivate,
                tags: request.tags,
                createdAt: request.createdAt,
                updatedAt: request.updatedAt
            )
        }
    }
    
    private func fetchMoodEntries(modelContext: ModelContext) throws -> [MoodEntryExport] {
        let descriptor = FetchDescriptor<MoodEntry>(
            sortBy: [SortDescriptor(\MoodEntry.date, order: .reverse)]
        )
        
        let entries = try modelContext.fetch(descriptor)
        
        return entries.map { entry in
            MoodEntryExport(
                id: entry.id.uuidString,
                date: entry.date,
                mood: entry.mood,
                intensity: entry.intensity,
                notes: entry.notes,
                tags: entry.tags,
                moodCategory: entry.moodCategory,
                emoji: entry.emoji,
                location: entry.location,
                weather: entry.weather,
                timeOfDay: entry.timeOfDay,
                activities: entry.activities,
                energyLevel: entry.energyLevel
            )
        }
    }
    
    private func fetchBookmarkedVerses(modelContext: ModelContext) throws -> [BookmarkedVerseExport] {
        let descriptor = FetchDescriptor<BookmarkedVerse>(
            sortBy: [SortDescriptor(\BookmarkedVerse.createdAt, order: .reverse)]
        )
        
        let verses = try modelContext.fetch(descriptor)
        
        return verses.map { verse in
            BookmarkedVerseExport(
                id: verse.id.uuidString,
                verseReference: verse.verseReference,
                verseText: verse.verseText,
                translation: verse.translation,
                notes: verse.notes,
                createdAt: verse.createdAt
            )
        }
    }
    
    private func fetchBibleHighlights(modelContext: ModelContext) throws -> [BibleHighlightExport] {
        let descriptor = FetchDescriptor<BibleHighlight>(
            sortBy: [SortDescriptor(\BibleHighlight.createdAt, order: .reverse)]
        )
        
        let highlights = try modelContext.fetch(descriptor)
        
        return highlights.map { highlight in
            BibleHighlightExport(
                id: highlight.id.uuidString,
                verseReference: highlight.verseReference,
                verseText: highlight.verseText,
                translation: highlight.translation,
                colorIndex: highlight.colorIndex,
                createdAt: highlight.createdAt
            )
        }
    }
    
    private func fetchBibleNotes(modelContext: ModelContext) throws -> [BibleNoteExport] {
        let descriptor = FetchDescriptor<BibleNote>(
            sortBy: [SortDescriptor(\BibleNote.createdAt, order: .reverse)]
        )
        
        let notes = try modelContext.fetch(descriptor)
        
        return notes.map { note in
            BibleNoteExport(
                id: note.id.uuidString,
                verseReference: note.verseReference,
                verseText: note.verseText,
                translation: note.translation,
                noteText: note.noteText,
                createdAt: note.createdAt,
                updatedAt: note.updatedAt
            )
        }
    }
    
    private func fetchReadingPlans(modelContext: ModelContext) throws -> [ReadingPlanExport] {
        let descriptor = FetchDescriptor<ReadingPlan>(
            sortBy: [SortDescriptor(\ReadingPlan.startDate, order: .reverse)]
        )
        
        let plans = try modelContext.fetch(descriptor)
        
        return plans.map { plan in
            ReadingPlanExport(
                id: plan.id.uuidString,
                title: plan.title,
                planDescription: plan.planDescription,
                duration: plan.duration,
                startDate: plan.startDate,
                endDate: plan.endDate,
                currentDay: plan.currentDay,
                isCompleted: plan.isCompleted,
                category: plan.category,
                difficulty: plan.difficulty,
                isCustom: plan.isCustom
            )
        }
    }
    
    // MARK: - Restore Backup
    
    func restoreBackup(from url: URL, modelContext: ModelContext, merge: Bool = false) async throws {
        guard let data = try? Data(contentsOf: url) else {
            throw BackupError.fileNotFound
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let backupData = try? decoder.decode(BackupData.self, from: data) else {
            throw BackupError.invalidFormat
        }
        
        if !merge {
            // Clear existing data before restore
            // Note: In production, you might want to ask user for confirmation
        }
        
        // Restore journal entries
        for entryExport in backupData.journalEntries {
            if !merge || !entryExists(id: entryExport.id, in: modelContext) {
                let entry = JournalEntry(
                    title: entryExport.title,
                    content: entryExport.content,
                    tags: entryExport.tags,
                    mood: entryExport.mood,
                    location: entryExport.location,
                    isPrivate: entryExport.isPrivate
                )
                entry.id = UUID(uuidString: entryExport.id) ?? UUID()
                entry.date = entryExport.date
                entry.createdAt = entryExport.createdAt
                entry.updatedAt = entryExport.updatedAt
                
                modelContext.insert(entry)
            }
        }
        
        // Restore prayer requests
        for requestExport in backupData.prayerRequests {
            if !merge || !prayerExists(id: requestExport.id, in: modelContext) {
            let request = PrayerRequest(
                title: requestExport.title,
                details: requestExport.details
            )
                request.id = UUID(uuidString: requestExport.id) ?? UUID()
                
                if let status = PrayerRequest.PrayerStatus(rawValue: requestExport.status) {
                request.status = status
            }
            request.isAnswered = requestExport.isAnswered
            request.answerDate = requestExport.answerDate
            request.answerNotes = requestExport.answerNotes
            request.isPrivate = requestExport.isPrivate
            request.tags = requestExport.tags
            request.createdAt = requestExport.createdAt
            request.updatedAt = requestExport.updatedAt
                
                modelContext.insert(request)
            }
        }
        
        // Restore mood entries
        for moodExport in backupData.moodEntries {
            if !merge || !moodExists(id: moodExport.id, in: modelContext) {
                let mood = MoodEntry(
                    mood: moodExport.mood,
                    intensity: moodExport.intensity,
                    notes: moodExport.notes,
                    tags: moodExport.tags
                )
                mood.id = UUID(uuidString: moodExport.id) ?? UUID()
                mood.date = moodExport.date
                mood.moodCategory = moodExport.moodCategory
                mood.emoji = moodExport.emoji
                mood.location = moodExport.location
                mood.weather = moodExport.weather
                mood.timeOfDay = moodExport.timeOfDay
                mood.activities = moodExport.activities
                mood.energyLevel = moodExport.energyLevel
                
                modelContext.insert(mood)
            }
        }
        
        // Restore bookmarked verses
        for verseExport in backupData.bookmarkedVerses {
            if !merge || !verseExists(id: verseExport.id, in: modelContext) {
                let verse = BookmarkedVerse(
                    verseReference: verseExport.verseReference,
                    verseText: verseExport.verseText,
                    translation: verseExport.translation,
                    notes: verseExport.notes
                )
                verse.id = UUID(uuidString: verseExport.id) ?? UUID()
                verse.createdAt = verseExport.createdAt
                
                modelContext.insert(verse)
            }
        }
        
        // Restore Bible highlights
        for highlightExport in backupData.bibleHighlights {
            if !merge || !highlightExists(id: highlightExport.id, in: modelContext) {
                let highlight = BibleHighlight(
                    verseReference: highlightExport.verseReference,
                    verseText: highlightExport.verseText,
                    translation: highlightExport.translation,
                    colorIndex: highlightExport.colorIndex
                )
                highlight.id = UUID(uuidString: highlightExport.id) ?? UUID()
                highlight.createdAt = highlightExport.createdAt
                
                modelContext.insert(highlight)
            }
        }
        
        // Restore Bible notes
        for noteExport in backupData.bibleNotes {
            if !merge || !bibleNoteExists(id: noteExport.id, in: modelContext) {
                let note = BibleNote(
                    verseReference: noteExport.verseReference,
                    verseText: noteExport.verseText,
                    translation: noteExport.translation,
                    noteText: noteExport.noteText
                )
                note.id = UUID(uuidString: noteExport.id) ?? UUID()
                note.createdAt = noteExport.createdAt
                note.updatedAt = noteExport.updatedAt
                
                modelContext.insert(note)
            }
        }
        
        // Restore reading plans
        for planExport in backupData.readingPlans {
            if !merge || !readingPlanExists(id: planExport.id, in: modelContext) {
                let plan = ReadingPlan(
                    title: planExport.title,
                    description: planExport.planDescription,
                    duration: planExport.duration,
                    startDate: planExport.startDate,
                    category: planExport.category,
                    difficulty: planExport.difficulty,
                    isCustom: planExport.isCustom
                )
                plan.id = UUID(uuidString: planExport.id) ?? UUID()
                plan.endDate = planExport.endDate
                plan.currentDay = planExport.currentDay
                plan.isCompleted = planExport.isCompleted
                
                modelContext.insert(plan)
            }
        }
        
        try modelContext.save()
        
        print("✅ Restore completed: \(backupData.metadata.dataCounts.journalEntries) entries restored")
    }
    
    // MARK: - Helper Functions
    
    private func entryExists(id: String, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate<JournalEntry> { $0.id.uuidString == id }
        )
        
        return (try? context.fetch(descriptor).first) != nil
    }
    
    private func prayerExists(id: String, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<PrayerRequest>(
            predicate: #Predicate<PrayerRequest> { $0.id.uuidString == id }
        )
        
        return (try? context.fetch(descriptor).first) != nil
    }
    
    private func moodExists(id: String, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate<MoodEntry> { $0.id.uuidString == id }
        )
        
        return (try? context.fetch(descriptor).first) != nil
    }
    
    private func verseExists(id: String, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<BookmarkedVerse>(
            predicate: #Predicate<BookmarkedVerse> { $0.id.uuidString == id }
        )
        
        return (try? context.fetch(descriptor).first) != nil
    }
    
    private func highlightExists(id: String, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<BibleHighlight>(
            predicate: #Predicate<BibleHighlight> { $0.id.uuidString == id }
        )
        
        return (try? context.fetch(descriptor).first) != nil
    }
    
    private func bibleNoteExists(id: String, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<BibleNote>(
            predicate: #Predicate<BibleNote> { $0.id.uuidString == id }
        )
        
        return (try? context.fetch(descriptor).first) != nil
    }
    
    private func readingPlanExists(id: String, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<ReadingPlan>(
            predicate: #Predicate<ReadingPlan> { $0.id.uuidString == id }
        )
        
        return (try? context.fetch(descriptor).first) != nil
    }
    
    private func cleanupOldBackups() async {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: documentsPath,
                includingPropertiesForKeys: [.creationDateKey]
            )
            
            let backupFiles = files.filter { $0.lastPathComponent.hasPrefix("FaithJournal_Backup_") }
                .sorted { file1, file2 in
                    let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 > date2
                }
            
            // Keep only the most recent backups
            if backupFiles.count > maxBackupVersions {
                for file in backupFiles.dropFirst(maxBackupVersions) {
                    try? FileManager.default.removeItem(at: file)
                    print("🗑️ Removed old backup: \(file.lastPathComponent)")
                }
            }
        } catch {
            print("❌ Error cleaning up backups: \(error)")
        }
    }
    
    // MARK: - Automatic Backups
    
    func checkAndPerformAutomaticBackup(modelContext: ModelContext) async {
        guard automaticBackupsEnabled else { return }
        
        guard let lastBackup = lastBackupDate else {
            // No backup yet, create one
            try? await createBackup(modelContext: modelContext)
            return
        }
        
        let daysSinceBackup = Calendar.current.dateComponents([.day], from: lastBackup, to: Date()).day ?? 0
        
        let shouldBackup: Bool
        switch backupFrequency {
        case .daily:
            shouldBackup = daysSinceBackup >= 1
        case .weekly:
            shouldBackup = daysSinceBackup >= 7
        case .monthly:
            shouldBackup = daysSinceBackup >= 30
        }
        
        if shouldBackup {
            try? await createBackup(modelContext: modelContext)
        }
    }
    
    // MARK: - Export Journal as PDF
    
    func exportJournalAsPDF(entries: [JournalEntry], title: String = "My Faith Journal") async throws -> URL {
        let pdfMetaData = [
            kCGPDFContextCreator: "Faith Journal",
            kCGPDFContextAuthor: "Faith Journal User",
            kCGPDFContextTitle: title
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let filename = "FaithJournal_\(title.replacingOccurrences(of: " ", with: "_"))_\(ISO8601DateFormatter().string(from: Date())).pdf"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let pdfURL = documentsPath.appendingPathComponent(filename)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            let titleFont = UIFont.boldSystemFont(ofSize: 24)
            let dateFont = UIFont.systemFont(ofSize: 12)
            let contentFont = UIFont.systemFont(ofSize: 14)
            
            var currentY: CGFloat = 50
            
            // Title
            title.draw(at: CGPoint(x: 50, y: currentY), withAttributes: [
                .font: titleFont,
                .foregroundColor: UIColor.label
            ])
            currentY += 40
            
            // Entries
            for entry in entries.sorted(by: { $0.date > $1.date }) {
                // Check if we need a new page
                if currentY > pageHeight - 200 {
                    context.beginPage()
                    currentY = 50
                }
                
                // Entry date
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .long
                let dateString = dateFormatter.string(from: entry.date)
                
                dateString.draw(at: CGPoint(x: 50, y: currentY), withAttributes: [
                    .font: dateFont,
                    .foregroundColor: UIColor.secondaryLabel
                ])
                currentY += 25
                
                // Entry title
                if !entry.title.isEmpty {
                    entry.title.draw(at: CGPoint(x: 50, y: currentY), withAttributes: [
                        .font: UIFont.boldSystemFont(ofSize: 16),
                        .foregroundColor: UIColor.label
                    ])
                    currentY += 25
                }
                
                // Entry content
                let contentRect = CGRect(x: 50, y: currentY, width: pageWidth - 100, height: pageHeight - currentY - 50)
                entry.content.draw(in: contentRect, withAttributes: [
                    .font: contentFont,
                    .foregroundColor: UIColor.label
                ])
                
                currentY += entry.content.height(withConstrainedWidth: pageWidth - 100, font: contentFont) + 40
            }
        }
        
        try data.write(to: pdfURL)
        
        return pdfURL
    }
}

enum BackupError: LocalizedError {
    case encodingFailed
    case fileNotFound
    case invalidFormat
    case restoreFailed
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode backup data"
        case .fileNotFound:
            return "Backup file not found"
        case .invalidFormat:
            return "Invalid backup file format"
        case .restoreFailed:
            return "Failed to restore backup"
        }
    }
}

extension String {
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
        return ceil(boundingBox.height)
    }
}
