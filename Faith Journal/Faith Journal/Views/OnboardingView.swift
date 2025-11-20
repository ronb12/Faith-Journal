//
//  OnboardingView.swift
//  Faith Journal
//
//  Onboarding flow for new users
//

import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var onboardingCompleted = false
    
    let pages = [
        OnboardingPage(
            title: "Welcome to Faith Journal",
            description: "Your personal space to grow in faith, reflect on God's word, and connect with others in Bible study.",
            imageName: "book.fill",
            color: .purple
        ),
        OnboardingPage(
            title: "Journal Your Journey",
            description: "Capture your thoughts, prayers, and reflections. Add photos, audio, and drawings to enrich your entries.",
            imageName: "square.and.pencil",
            color: .blue
        ),
        OnboardingPage(
            title: "Prayer Requests",
            description: "Track your prayer requests and see how God answers them. Share prayers with your community.",
            imageName: "hands.sparkles.fill",
            color: .green
        ),
        OnboardingPage(
            title: "Bible Study Together",
            description: "Join live Bible study sessions, explore 1000+ verses, and grow in faith with others.",
            imageName: "person.3.fill",
            color: .orange
        ),
        OnboardingPage(
            title: "Daily Devotionals",
            description: "Receive daily devotionals, Bible verses, and reflection prompts to strengthen your walk with God.",
            imageName: "heart.fill",
            color: .red
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            VStack(spacing: 16) {
                // Custom page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.purple : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                            .animation(.easeInOut, value: currentPage)
                    }
                }
                
                if currentPage == pages.count - 1 {
                    Button(action: {
                        completeOnboarding()
                    }) {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                } else {
                    Button(action: {
                        withAnimation {
                            currentPage += 1
                        }
                    }) {
                        Text("Next")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        completeOnboarding()
                    }) {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
    }
    
    private func completeOnboarding() {
        onboardingCompleted = true
        hasCompletedOnboarding = true
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: page.imageName)
                .font(.system(size: 80))
                .foregroundColor(page.color)
                .padding()
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
