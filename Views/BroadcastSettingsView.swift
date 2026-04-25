//
//  BroadcastSettingsView.swift
//  Faith Journal
//
//  Settings view for broadcast streaming
//

import SwiftUI

@available(iOS 17.0, *)
struct BroadcastSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var videoQuality: BroadcastStreamView_HLS.VideoQuality
    @Binding var networkQuality: BroadcastStreamView_HLS.NetworkQuality
    @Binding var isRecording: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Video Quality")) {
                    Picker("Quality", selection: $videoQuality) {
                        ForEach(BroadcastStreamView_HLS.VideoQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                }
                
                Section(header: Text("Network Status")) {
                    HStack {
                        Text("Connection")
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(networkQuality.color)
                                .frame(width: 8, height: 8)
                            Text(networkQuality.rawValue)
                                .font(.caption)
                        }
                    }
                }
                
                Section(header: Text("Recording")) {
                    Toggle("Record Session", isOn: $isRecording)
                }
                
                Section(header: Text("Additional Options")) {
                    // Add more settings here as needed
                    Text("Background blur, filters, and more coming soon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Broadcast Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

