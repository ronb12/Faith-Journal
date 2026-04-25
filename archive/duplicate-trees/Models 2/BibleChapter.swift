// BibleChapter.swift
// Faith Journal

import Foundation

public struct BibleChapter: Identifiable, Hashable, Codable {
    public var id = UUID()
    public let number: Int
    public let verses: [BibleVerseDisplay]
}
