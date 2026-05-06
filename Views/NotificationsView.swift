import SwiftUI
#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import FirebaseAuth
import FirebaseFirestore
#endif

@available(iOS 17.0, macOS 14.0, *)
private struct AppNotificationItem: Identifiable {
    let id: String
    let title: String
    let body: String
    let createdAt: Date
    let isRead: Bool
    let type: String
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private final class AppNotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotificationItem] = []
    @Published var errorMessage: String?

    #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
    private var listener: ListenerRegistration?
    #endif

    func start() {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let uid = Auth.auth().currentUser?.uid else {
            notifications = []
            return
        }

        listener?.remove()
        listener = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("appNotifications")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error {
                        self?.errorMessage = error.localizedDescription
                        return
                    }

                    self?.errorMessage = nil
                    self?.notifications = snapshot?.documents.map { document in
                        let data = document.data()
                        return AppNotificationItem(
                            id: document.documentID,
                            title: data["title"] as? String ?? "Faith Journal",
                            body: data["body"] as? String ?? "",
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                            isRead: data["isRead"] as? Bool ?? false,
                            type: data["type"] as? String ?? "general"
                        )
                    } ?? []
                }
            }
        #endif
    }

    func stop() {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        listener?.remove()
        listener = nil
        #endif
    }

    func markRead(_ notification: AppNotificationItem) {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let uid = Auth.auth().currentUser?.uid, !notification.isRead else { return }

        Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("appNotifications")
            .document(notification.id)
            .setData(["isRead": true, "readAt": FieldValue.serverTimestamp()], merge: true)
        #endif
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct NotificationsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @StateObject private var viewModel = AppNotificationsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.platformSystemGroupedBackground
                    .ignoresSafeArea(.all, edges: .all)

                if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Notifications unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                    .padding()
                } else if viewModel.notifications.isEmpty {
                    ContentUnavailableView(
                        "No notifications yet",
                        systemImage: "bell",
                        description: Text("When something important happens, you will see it here.")
                    )
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.notifications) { notification in
                                notificationRow(notification)
                                    .onAppear {
                                        viewModel.markRead(notification)
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Notifications")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.platformSystemGroupedBackground, for: .navigationBar)
            #endif
            .onAppear {
                viewModel.start()
            }
            .onDisappear {
                viewModel.stop()
            }
        }
    }

    private func notificationRow(_ notification: AppNotificationItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: iconName(for: notification.type))
                    .font(.headline)
                    .foregroundColor(themeManager.colors.primary)
                    .frame(width: 42, height: 42)
                    .background(themeManager.colors.primary.opacity(0.14))
                    .clipShape(Circle())

                if !notification.isRead {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 9, height: 9)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(notification.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Spacer()

                    Text(notification.createdAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(notification.body)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.platformSecondarySystemBackground)
        .cornerRadius(12)
    }

    private func iconName(for type: String) -> String {
        switch type {
        case "community_thank_you":
            return "heart.fill"
        case "friend_request":
            return "person.crop.circle.badge.plus"
        case "live_session":
            return "video.fill"
        default:
            return "bell.fill"
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct NotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationsView()
    }
}
