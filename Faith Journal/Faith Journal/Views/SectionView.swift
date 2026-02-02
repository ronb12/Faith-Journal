//
//  SectionView.swift
//  Faith Journal
//
//  Reusable section view component
//

import SwiftUI

struct SectionView: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .font(.body.weight(.semibold))
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

