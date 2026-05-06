//
//  PushNotificationAppDelegate.swift
//  Faith Journal
//
//  Registers for remote (push) notifications and saves FCM token to Firestore
//  so the backend can send push notifications (e.g. friend requests).
//  Requires: FirebaseMessaging package added in Xcode (Firebase → FirebaseMessaging).
//

#if os(iOS)
import UIKit
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

class PushNotificationAppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
        #endif
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        #endif
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("⚠️ [PUSH] Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

#if canImport(FirebaseMessaging) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
extension PushNotificationAppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken, !token.isEmpty else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(uid).setData(["fcmToken": token], merge: true) { error in
            if let error = error {
                print("⚠️ [PUSH] Failed to save FCM token: \(error.localizedDescription)")
            } else {
                print("✅ [PUSH] FCM token saved for user \(uid.prefix(8))...")
            }
        }
    }
}
#endif
#endif
