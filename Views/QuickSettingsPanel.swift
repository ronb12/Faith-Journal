//
//  QuickSettingsPanel.swift
//  Faith Journal
//
//  Quick settings panel for live streaming
//

import SwiftUI

@available(iOS 17.0, *)
struct QuickSettingsPanel: View {
    @Binding var backgroundBlurEnabled: Bool
    @Binding var selectedFilter: BroadcastStreamView_HLS.VideoFilter
    @Binding var batterySaverEnabled: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Quick Settings")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Background Blur
            Toggle(isOn: $backgroundBlurEnabled) {
                HStack {
                    Image(systemName: "camera.filters")
                        .foregroundColor(.white)
                    Text("Background Blur")
                        .foregroundColor(.white)
                }
            }
            .tint(.purple)
            
            // Video Filters
            VStack(alignment: .leading, spacing: 8) {
                Text("Video Filter")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(BroadcastStreamView_HLS.VideoFilter.allCases, id: \.self) { filter in
                            FilterButton(
                                filter: filter,
                                isSelected: selectedFilter == filter,
                                action: { selectedFilter = filter }
                            )
                        }
                    }
                }
            }
            
            // Battery Saver
            Toggle(isOn: $batterySaverEnabled) {
                HStack {
                    Image(systemName: "battery.25")
                        .foregroundColor(.orange)
                    Text("Battery Saver")
                        .foregroundColor(.white)
                }
            }
            .tint(.orange)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

@available(iOS 17.0, *)
struct FilterButton: View {
    let filter: BroadcastStreamView_HLS.VideoFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .purple : .white.opacity(0.6))
                Text(filter.rawValue)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.purple.opacity(0.3) : Color.white.opacity(0.1))
            )
        }
    }
}

