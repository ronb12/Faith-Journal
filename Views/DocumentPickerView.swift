//
//  DocumentPickerView.swift
//  Faith Journal
//
//  Document picker for file attachments
//

import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
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
            let fileManager = FileManager.default
            guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            
            var copiedURLs: [URL] = []
            
            for url in urls {
                let fileName = url.lastPathComponent
                let destinationURL = documentsPath.appendingPathComponent("attachments").appendingPathComponent(fileName)
                
                try? fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                
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
#elseif os(macOS)
import AppKit

struct DocumentPickerView: View {
    @Binding var selectedFileURLs: [URL]
    var allowedContentTypes: [UTType]
    var allowsMultipleSelection: Bool
    
    var body: some View {
        EmptyView()
            .onAppear {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = allowsMultipleSelection
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowedContentTypes = allowedContentTypes
            
            if panel.runModal() == .OK {
                let fileManager = FileManager.default
                guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
                
                for url in panel.urls {
                    let fileName = url.lastPathComponent
                    let destinationURL = documentsPath.appendingPathComponent("attachments").appendingPathComponent(fileName)
                    
                    try? fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    
                    do {
                        if fileManager.fileExists(atPath: destinationURL.path) {
                            try fileManager.removeItem(at: destinationURL)
                        }
                        try fileManager.copyItem(at: url, to: destinationURL)
                        selectedFileURLs.append(destinationURL)
                    } catch {
                        print("Error copying file: \(error)")
                    }
                }
            }
        }
    }
}
#endif
