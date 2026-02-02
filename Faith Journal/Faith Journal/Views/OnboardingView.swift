//
//  OnboardingView.swift
//  Faith Journal
//
//  Onboarding flow for new users
//

import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var onboardingCompleted = false
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfile]
    @State private var userName: String = ""
    @State private var isSavingName = false
    
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
        ZStack {
            // Background that fills entire screen
            Color(.systemGroupedBackground)
                .ignoresSafeArea(.all, edges: .all)
            
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    // Regular onboarding pages
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                    // Name input page (last page)
                    NameInputPageView(userName: $userName)
                        .tag(pages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            
            VStack(spacing: 16) {
                // Custom page indicators
                HStack(spacing: 8) {
                    ForEach(0..<(pages.count + 1), id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.purple : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                            .animation(.easeInOut, value: currentPage)
                    }
                }
                
                if currentPage == pages.count {
                    // Name input page - show "Get Started" button
                    Button(action: {
                        saveNameAndComplete()
                    }) {
                        HStack {
                            if isSavingName {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Get Started")
                                    .font(.headline)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.purple)
                        .cornerRadius(12)
                    }
                    .disabled(userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSavingName)
                    .padding(.horizontal)
                    .accessibility(label: Text("Get Started"))
                    .accessibilityHint("Complete onboarding and start using Faith Journal")
                    .minTouchTarget()
                } else if currentPage == pages.count - 1 {
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
                    .accessibility(label: Text("Get Started"))
                    .accessibilityHint("Complete onboarding and start using Faith Journal")
                    .minTouchTarget()
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
                }
            }
            .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all, edges: .all)
    }
    
    private func saveNameAndComplete() {
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        isSavingName = true
        
        Task {
            // Save to local UserProfile (SwiftData)
            let profileName = trimmedName
            let descriptor = FetchDescriptor<UserProfile>()
            if let existingProfile = try? modelContext.fetch(descriptor).first {
                existingProfile.name = profileName
                existingProfile.updatedAt = Date()
            } else {
                let newProfile = UserProfile(name: profileName)
                modelContext.insert(newProfile)
            }
            
            do {
                try modelContext.save()
                print("✅ [ONBOARDING] Saved name to UserProfile: \(profileName)")
            } catch {
                print("❌ [ONBOARDING] Error saving UserProfile: \(error.localizedDescription)")
            }
            
            // Save to Firebase ProfileManager if authenticated
            do {
                try await ProfileManager.shared.saveProfileName(profileName)
                print("✅ [ONBOARDING] Saved name to Firebase: \(profileName)")
            } catch {
                print("⚠️ [ONBOARDING] Could not save to Firebase (may not be authenticated): \(error.localizedDescription)")
                // Continue anyway - local profile is saved
            }
            
            await MainActor.run {
                isSavingName = false
                onboardingCompleted = true
                hasCompletedOnboarding = true
            }
        }
    }
    
    private func completeOnboarding() {
        // If user skips, still complete onboarding but don't save name
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
                .accessibilityHidden(true) // Decorative image
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .font(.body.weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .accessibilityLabel(page.description)
            }
            
            Spacer()
        }
    }
}

// MARK: - Name Input Page

struct NameInputPageView: View {
    @Binding var userName: String
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.purple)
                .padding()
                .accessibilityHidden(true)
            
            VStack(spacing: 16) {
                Text("What's your name?")
                    .font(.largeTitle)
                    .font(.body.weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text("This name will be used in live sessions and when sharing with others.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                TextField("Enter your name", text: $userName)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                    .focused($isTextFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        // Allow submission if name is not empty
                    }
            }
            
            Spacer()
        }
        .onAppear {
            // Auto-focus the text field when this page appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        OnboardingView(hasCompletedOnboarding: .constant(false))
    } else {
        Text("iOS 17+ required")
    }
}
