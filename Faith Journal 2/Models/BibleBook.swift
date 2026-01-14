// BibleBook.swift
// Faith Journal

import Foundation

public struct BibleBook: Identifiable, Hashable, Codable {
    public var id = UUID()
    public let name: String
    public let chapters: [BibleChapter]
}
