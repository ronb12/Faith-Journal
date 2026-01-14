import SwiftUI
import UIKit

@available(iOS 17.0, *)
struct LandingView: View {
    @Binding var hasLoggedIn: Bool
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showLogin = false
    
    init(hasLoggedIn: Binding<Bool> = .constant(false)) {
        _hasLoggedIn = hasLoggedIn
    }
    
    private var screenBounds: CGRect {
        UIScreen.main.bounds
    }
    
    var body: some View {
        ZStack {
            // Base purple background - ensures no black shows through
            Color.purple.opacity(0.8)
                .ignoresSafeArea(.all)
            
            // Gradient Background - fills entire screen
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.8),
                    Color.blue.opacity(0.9),
                    Color.purple.opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(.all)
            
            GeometryReader { geometry in
                // Decorative circles
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 300, height: 300)
                    .offset(x: -100, y: -150)
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 200, height: 200)
                    .offset(x: geometry.size.width - 100, y: geometry.size.height - 200)
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Top spacing (no safe area padding - background fills screen)
                        Spacer()
                            .frame(height: 20)
                    
                    // Logo/Icon Section
                    VStack(spacing: 20) {
                        // App Icon
                        AppIconView()
                            .frame(width: 120, height: 120)
                            .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
                            .padding(.bottom, 8)
                        
                        VStack(spacing: 8) {
                            Text("Faith Journal")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                            
                            Text("Grow your faith. Track your journey.")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.95))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Feature highlights with improved design
                    VStack(spacing: 16) {
                        FeatureRow(icon: "book.fill", text: "Daily Devotionals", color: .white)
                        FeatureRow(icon: "hands.sparkles.fill", text: "Prayer Requests & Tracking", color: .white)
                        FeatureRow(icon: "heart.text.square.fill", text: "Mood & Gratitude Journal", color: .white)
                        FeatureRow(icon: "magnifyingglass", text: "Bible Reading & Search", color: .white)
                        FeatureRow(icon: "icloud.fill", text: "Cloud Sync & Privacy", color: .white)
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                    )
                    .padding(.horizontal, 24)
                    
                    Spacer()
                        .frame(height: 20)
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        // Get Started Button
                        Button(action: {
                            print("🔄 [LANDING] Get Started button tapped")
                            showLogin = true
                            print("🔄 [LANDING] showLogin set to: \(showLogin)")
                        }) {
                            HStack {
                                Text("Get Started")
                                    .font(.headline)
                                    .font(.body.weight(.semibold))
                                Image(systemName: "arrow.right")
                                    .font(.headline)
                            }
                            .foregroundColor(.purple)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                            )
                        }
                        .padding(.horizontal, 24)
                        
                        // Demo Button - Only show in simulator or for testing
                        #if targetEnvironment(simulator)
                        Button(action: {
                            print("🔄 [LANDING] Try Demo button tapped (Simulator)")
                            // Skip login and onboarding for demo (simulator only)
                            // Update both AppStorage values immediately
                            UserDefaults.standard.set(true, forKey: "hasLoggedIn")
                            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                            UserDefaults.standard.synchronize()
                            
                            print("🔄 [LANDING] UserDefaults updated - hasLoggedIn: \(UserDefaults.standard.bool(forKey: "hasLoggedIn")), hasCompletedOnboarding: \(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))")
                            
                            // Also update bindings
                            hasLoggedIn = true
                            hasCompletedOnboarding = true
                            print("🔄 [LANDING] Bindings updated - hasLoggedIn: \(hasLoggedIn), hasCompletedOnboarding: \(hasCompletedOnboarding)")
                        }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.headline)
                                Text("Try Demo")
                                    .font(.headline)
                                    .font(.body.weight(.semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.8), lineWidth: 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.1))
                                    )
                            )
                        }
                        .padding(.horizontal, 24)
                        #endif
                    }
                        // Bottom spacing (no safe area padding - background fills screen)
                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all, edges: .all)
        .statusBar(hidden: false)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showLogin) {
            LoginView(hasLoggedIn: $hasLoggedIn)
                .onAppear {
                    print("🔄 [LANDING] LoginView appeared via fullScreenCover")
                }
        }
        .onChange(of: showLogin) { oldValue, newValue in
            print("🔄 [LANDING] showLogin changed from \(oldValue) to \(newValue)")
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(text)
                .font(.body)
                .foregroundColor(color)
                .font(.body.weight(.medium))
            
            Spacer()
        }
    }
}

struct AppIconView: View {
    @State private var appIcon: UIImage?
    
    var body: some View {
        Group {
            if let icon = appIcon {
                Image(uiImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
            } else {
                // Fallback to system icon if app icon not found
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .frame(width: 120, height: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 26)
                            .fill(Color.white.opacity(0.2))
                    )
            }
        }
        .onAppear {
            loadAppIcon()
        }
    }
    
    private func loadAppIcon() {
        // Try multiple methods to get the app icon
        if let icon = UIImage(named: "AppIcon") {
            appIcon = icon
            return
        }
        
        // Try to get from bundle icons
        if let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIconsDictionary = iconsDictionary["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIconsDictionary["CFBundleIconFiles"] as? [String] {
            for iconName in iconFiles.reversed() {
                if let icon = UIImage(named: iconName) {
                    appIcon = icon
                    return
                }
            }
        }
        
        // Try common app icon names
        let commonNames = ["AppIcon-1024x1024", "AppIcon-60x60@3x", "iPhone_120x120", "AppIcon"]
        for name in commonNames {
            if let icon = UIImage(named: name) {
                appIcon = icon
                return
            }
        }
        
        // Last resort: try to get from assets
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "png", inDirectory: nil),
           let icon = UIImage(contentsOfFile: path) {
            appIcon = icon
        }
    }
}

struct FaithJournalLogo: View {
    var body: some View {
        EmptyView() // Logo now handled by Image("logo") in LandingView
    }
}

@available(iOS 17.0, *)
#Preview {
    LandingView()
}
