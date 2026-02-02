// BibleViewModel.swift
// Faith Journal

import Foundation
import Combine

class BibleViewModel: ObservableObject {
    @Published var books: [BibleBook] = []
    @Published var selectedVersion: String = "KJV"
    @Published var availableVersions: [String] = ["KJV", "NIV", "ESV"]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    func loadBible() {
        // Dummy data for now
        isLoading = false
        errorMessage = nil
        books = [
            BibleBook(name: "Genesis", chapters: [
                BibleChapter(number: 1, verses: [
                    BibleVerseDisplay(number: 1, text: "In the beginning God created the heaven and the earth."),
                    BibleVerseDisplay(number: 2, text: "And the earth was without form, and void; and darkness was upon the face of the deep.")
                ])
            ])
        ]
    }
}
