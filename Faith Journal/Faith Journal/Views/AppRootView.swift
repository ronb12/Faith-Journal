//
//  AppRootView.swift
//  Faith Journal
//
//  Root view that handles onboarding flow
//

import SwiftUI

struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    
    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .onAppear {
            showOnboarding = !hasCompletedOnboarding
        }
    }
}

#Preview {
    AppRootView()
}
