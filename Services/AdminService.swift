import Foundation
#if canImport(UIKit)
import UIKit
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class AdminService: ObservableObject {
    static let shared = AdminService()
    private init() {}
    
    /// Single admin account (strict).
    /// For production, keep this tight and controlled via Firebase custom claims.
    private let allowedAdminEmail = "ronellbradley@hotmail.com"
    
    @Published private(set) var isAdminCached: Bool = false
    
    /// Call on app launch / after sign-in.
    func refreshAdminStatus() async {
        var isAdmin = false
        
        #if canImport(FirebaseAuth)
        if let user = Auth.auth().currentUser {
            isAdmin = await isFirebaseUserAdmin(user)
        }
        #endif
        
        #if DEBUG
        // Local override for testing on simulator/dev builds:
        if UserDefaults.standard.bool(forKey: "debug_isAdmin") {
            isAdmin = true
        }
        #endif
        
        isAdminCached = isAdmin
    }
    
    #if canImport(FirebaseAuth)
    /// `admin` custom claim, allowlisted email, or (DEBUG) `debug_isAdmin` / server-side equivalents.
    private func isFirebaseUserAdmin(_ user: User) async -> Bool {
        let allowed = allowedAdminEmail.lowercased()
        do { try await user.reload() } catch { /* use cached */ }
        if (try? await user.getIDTokenResult(forcingRefresh: true))?.claims["admin"] as? Bool == true {
            return true
        }
        let emails = [user.email] + user.providerData.map { $0.email }
        let lower = Set(emails.compactMap { $0?.lowercased() })
        return lower.contains(allowed)
    }
    #endif
    
    var isAdmin: Bool {
        isAdminCached
    }
    
    /// Subscribe admin devices to the `admins` topic so they receive server-triggered pushes.
    func refreshAdminPushSubscription() async {
        await refreshAdminStatus()
        guard isAdminCached else { return }
        
        // Reuse the same permission prompt behavior as existing notifications.
        _ = await NotificationService.shared.requestAuthorization()
        
        #if canImport(UIKit)
        // Needed for APNs token → FCM registration (remote push)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
        
        #if canImport(FirebaseMessaging)
        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                Messaging.messaging().subscribe(toTopic: "admins") { error in
                    if let error { cont.resume(throwing: error) }
                    else { cont.resume(returning: ()) }
                }
            }
            print("✅ [ADMIN] Subscribed to FCM topic: admins")
        } catch {
            print("❌ [ADMIN] Failed to subscribe to admins topic: \(error.localizedDescription)")
        }
        #else
        print("⚠️ [ADMIN] FirebaseMessaging not included; cannot subscribe to admins topic.")
        #endif
    }
}

