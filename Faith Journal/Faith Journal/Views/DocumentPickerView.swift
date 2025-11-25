//
//  DocumentPickerView.swift
//  Faith Journal
//
//  Document picker for file attachments
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct DocumentPickerView: UIViewControllerRepresentable {
    @Binding var selectedFileURLs: [URL]
    var allowedContentTypes: [UTType]
    var allowsMultipleSelection: Bool
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = allowsMultipleSelection
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Copy files to app's document directory
            let fileManager = FileManager.default
            guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            
            var copiedURLs: [URL] = []
            
            for url in urls {
                let fileName = url.lastPathComponent
                let destinationURL = documentsPath.appendingPathComponent("attachments").appendingPathComponent(fileName)
                
                // Create attachments directory if it doesn't exist
                try? fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                
                // Copy file
                do {
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                    }
                    try fileManager.copyItem(at: url, to: destinationURL)
                    copiedURLs.append(destinationURL)
                } catch {
                    print("Error copying file: \(error)")
                }
            }
            
            parent.selectedFileURLs.append(contentsOf: copiedURLs)
        }
    }
}

