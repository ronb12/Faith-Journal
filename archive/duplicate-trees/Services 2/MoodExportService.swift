//
//  MoodExportService.swift
//  Faith Journal
//
//  Mood data export service
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
class MoodExportService {
    static let shared = MoodExportService()
    
    private init() {}
    
    func exportToCSV(entries: [MoodEntry]) -> String {
        var csv = "Date,Time,Mood,Intensity,Category,Emoji,Notes,Tags,Activities,Energy Level,Time of Day,Location,Weather\n"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            let dateStr = formatter.string(from: entry.date)
            let timeStr = timeFormatter.string(from: entry.date)
            let notes = entry.notes?.replacingOccurrences(of: ",", with: ";") ?? ""
            let tags = entry.tags.joined(separator: ";")
            let activities = entry.activities.joined(separator: ";")
            let location = entry.location?.replacingOccurrences(of: ",", with: ";") ?? ""
            let weather = entry.weather?.replacingOccurrences(of: ",", with: ";") ?? ""
            
            csv += "\(dateStr),\(timeStr),\(entry.mood),\(entry.intensity),\(entry.moodCategory),\(entry.emoji),\(notes),\(tags),\(activities),\(entry.energyLevel),\(entry.timeOfDay),\(location),\(weather)\n"
        }
        
        return csv
    }
    
    func exportToJSON(entries: [MoodEntry]) -> Data? {
        struct MoodEntryExport: Codable {
            let id: String
            let date: String
            let mood: String
            let intensity: Int
            let category: String
            let emoji: String
            let notes: String
            let tags: [String]
            let activities: [String]
            let energyLevel: Int
            let timeOfDay: String
            let location: String
            let weather: String
            let linkedJournalEntryId: String
            let linkedPrayerRequestIds: [String]
            let linkedReadingPlanId: String
        }
        
        let exportData = entries.map { entry in
            MoodEntryExport(
                id: entry.id.uuidString,
                date: ISO8601DateFormatter().string(from: entry.date),
                mood: entry.mood,
                intensity: entry.intensity,
                category: entry.moodCategory,
                emoji: entry.emoji,
                notes: entry.notes ?? "",
                tags: entry.tags,
                activities: entry.activities,
                energyLevel: entry.energyLevel,
                timeOfDay: entry.timeOfDay,
                location: entry.location ?? "",
                weather: entry.weather ?? "",
                linkedJournalEntryId: entry.linkedJournalEntryId?.uuidString ?? "",
                linkedPrayerRequestIds: entry.linkedPrayerRequestIds.map { $0.uuidString },
                linkedReadingPlanId: entry.linkedReadingPlanId?.uuidString ?? ""
            )
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(exportData)
    }
    
    @MainActor
    func generatePDFReport(entries: [MoodEntry], analytics: MoodAnalyticsService) -> Data? {
        // Simple text-based report (full PDF generation would require PDFKit)
        var report = "MOOD ANALYTICS REPORT\n"
        report += "Generated: \(Date())\n"
        report += "Total Entries: \(entries.count)\n\n"
        
        report += "STATISTICS\n"
        report += "Average Mood: \(String(format: "%.2f", analytics.getAverageMood(entries: entries, timeframe: .all)))/10\n"
        
        let streaks = analytics.getMoodStreaks(entries: entries)
        report += "Current Streak: \(streaks.currentStreak) days\n"
        report += "Longest Positive Streak: \(streaks.positiveStreak) days\n"
        
        let (bestDay, worstDay) = analytics.getBestWorstDays(entries: entries)
        report += "Best Day: \(bestDay)\n"
        report += "Worst Day: \(worstDay)\n\n"
        
        report += "RECENT ENTRIES\n"
        for entry in entries.sorted(by: { $0.date > $1.date }).prefix(10) {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            report += "\(formatter.string(from: entry.date)): \(entry.mood) (\(entry.intensity)/10)\n"
        }
        
        return report.data(using: .utf8)
    }
}
