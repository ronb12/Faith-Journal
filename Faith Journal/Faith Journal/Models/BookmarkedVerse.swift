//
//  BookmarkedVerse.swift
//  Faith Journal
//
//  Model for bookmarked verses from live sessions
//

import Foundation
import SwiftData

@Model
final class BookmarkedVerse {
    var id: UUID = UUID()
    var verseReference: String = "" // e.g., "John 3:16"
    var verseText: String = ""
    var translation: String = "NIV"
    var sessionId: UUID?
    var sessionTitle: String = ""
    var bookmarkedBy: String = "" // User ID who bookmarked it
    var bookmarkedByName: String = "" // User name
    var notes: String = "" // Optional notes about the verse
    var createdAt: Date = Date()
    
    init(
        verseReference: String,
        verseText: String,
        translation: String = "NIV",
        sessionId: UUID? = nil,
        sessionTitle: String = "",
        bookmarkedBy: String = "",
        bookmarkedByName: String = "",
        notes: String = ""
    ) {
        self.id = UUID()
        self.verseReference = verseReference
        self.verseText = verseText
        self.translation = translation
        self.sessionId = sessionId
        self.sessionTitle = sessionTitle
        self.bookmarkedBy = bookmarkedBy
        self.bookmarkedByName = bookmarkedByName
        self.notes = notes
        self.createdAt = Date()
    }
}

