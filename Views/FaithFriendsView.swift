//
//  FaithFriendsView.swift
//  Faith Journal
//
//  Faith Friends - add friends via in-app search, receive notifications when friends create live sessions.
//

import SwiftUI
import SwiftData
import CoreImage.CIFilterBuiltins
import UserNotifications
#if os(iOS)
import MessageUI
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@available(iOS 17.0, *)
struct FaithFriendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\PrayerRequest.createdAt, order: .reverse)]) private var myPrayerRequests: [PrayerRequest]
    @Query(sort: [SortDescriptor(\ReadingPlan.createdAt, order: .reverse)]) private var myReadingPlans: [ReadingPlan]
    @ObservedObject private var firebaseService = FirebaseSyncService.shared
    @State private var searchText = ""
    @State private var searchResults: [[String: Any]] = []
    @State private var lastSearchFoundSelfOnly = false
    @State private var isSearching = false
    @State private var friends: [[String: Any]] = []
    @State private var pendingIncoming: [[String: Any]] = []
    @State private var pendingOutgoing: [[String: Any]] = []
    @State private var isLoadingFriends = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var actionInProgress: String? = nil
    @State private var myFriendCode: String? = nil
    @State private var friendCodeLoaded = false
    @State private var addByCodeText = ""
    @State private var showingShareSheet = false
    @State private var showCopyAlert = false
    @State private var showingQRScanner = false
    @State private var scannedFriendCode = ""
    @State private var showingEmailComposer = false
    @State private var friendToRemove: [String: Any]? = nil
    @State private var showingRemoveConfirm = false
    @State private var searchDebounceTask: Task<Void, Never>? = nil
    @State private var hasProcessedPendingFriendCode = false

    // Prayer Wall
    @State private var friendsSharedPrayers: [[String: Any]] = []
    @State private var isLoadingPrayerWall = false
    @State private var intercessedPrayerIds: Set<String> = []

    // Friend Live Session Banner
    @State private var dismissedAlertId: UUID? = nil

    // Accountability Partner
    @State private var accountabilityPartnerId: String? = nil
    @State private var accountabilityPartnerName: String? = nil
    @State private var isLoadingPartner = false
    @State private var accountabilityReadingNudge: String? = nil
    @State private var friendSharedReadingPlans: [[String: Any]] = []
    @State private var isLoadingFriendReading = false

    private var myUserId: String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
        #else
        return nil
        #endif
    }

    var body: some View {
        ZStack(alignment: .top) {
            List {
                accountabilityPartnerSection
                friendSharedReadingSection
                prayerWallSection
                inviteSection
                addByCodeSection
                searchSection
                friendsSectionWithPartner
                sentRequestsSection
                pendingRequestsSection
            }
            // Feature 2: In-App Friend Live Session Banner
            if let alert = firebaseService.latestFriendSessionAlert,
               alert.id != dismissedAlertId {
                FriendLiveBanner(alert: alert) {
                    dismissedAlertId = alert.id
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: firebaseService.latestFriendSessionAlert?.id)
                .zIndex(10)
            }
        }
        .navigationTitle("Faith Friends")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $searchText, prompt: "Search by name or email...")
        .onSubmit(of: .search) { performSearch() }
        .onChange(of: searchText) { _, newValue in
            searchDebounceTask?.cancel()
            if newValue.isEmpty {
                searchResults = []
                lastSearchFoundSelfOnly = false
                return
            }
            guard newValue.count >= 2 else { return }
            searchDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                performSearch()
            }
        }
        .onAppear {
            loadFriends()
            FirebaseSyncService.shared.refreshMySearchProfile()
            loadFriendCode()
            loadPrayerWall()
            loadAccountabilityPartner()
            loadFriendSharedReading()
            processPendingFriendCodeIfNeeded()
        }
        .alert("Error", isPresented: $showingError) { Button("OK") { } } message: { Text(errorMessage) }
        .alert("Copied", isPresented: $showCopyAlert) { Button("OK") { } } message: { Text("Friend code copied to clipboard") }
        .alert("Remove Friend?", isPresented: $showingRemoveConfirm) {
            Button("Cancel", role: .cancel) { friendToRemove = nil }
            Button("Remove", role: .destructive) { confirmRemoveFriend() }
        } message: {
            if let f = friendToRemove, let name = f["friendDisplayName"] as? String ?? f["displayName"] as? String {
                Text("Remove \(name) from your friends? They can send you a new request later if you change your mind.")
            } else {
                Text("Remove this friend? They can send you a new request later if you change your mind.")
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showingShareSheet) {
            InviteUsersActivityView(
                activityItems: friendShareItems(),
                onDismiss: { showingShareSheet = false }
            )
        }
        .sheet(isPresented: $showingEmailComposer) {
            if MFMailComposeViewController.canSendMail() {
                FriendInviteEmailComposerView(
                    subject: "Add me on Faith Journal",
                    body: friendShareText()
                )
            } else {
                VStack(spacing: 16) {
                    Text("Mail Not Configured").font(.headline)
                    Text("Use Share below to send via Messages or another app.").font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                    Button("OK") { showingEmailComposer = false }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingQRScanner) {
            QRCodeScannerView(scannedCode: $scannedFriendCode)
        }
        .onChange(of: scannedFriendCode) { _, newValue in
            guard !newValue.isEmpty else { return }
            // Extract the 6-char code from deep-link URLs like faithjournal://friend/XXXXXX
            let extracted = (URL(string: newValue)?.lastPathComponent ?? newValue)
                .trimmingCharacters(in: .whitespaces)
                .uppercased()
            addByCodeText = extracted
            if extracted.count == 6 {
                addFriendByCode()
            }
            scannedFriendCode = ""
        }
        #endif
    }

    private var searchSection: some View {
        Section {
            if !searchText.isEmpty && searchText.count >= 2 {
                if isSearching {
                    HStack { Spacer(); ProgressView(); Spacer() }.padding()
                } else if searchResults.isEmpty {
                    Text(lastSearchFoundSelfOnly ? "That's you! Search for a friend's name or email to add them." : "No users found. Try a different search.").foregroundColor(.secondary).padding(.vertical, 8)
                } else {
                    ForEach(Array(searchResults.enumerated()), id: \.offset) { _, user in
                        UserSearchRow(user: user, myUserId: myUserId, friendUserIds: Set(friends.compactMap { $0["friendUserId"] as? String }), onAddFriend: { addFriend(user: user) }, actionInProgress: $actionInProgress)
                    }
                }
            }
        } header: { Text("Find Friends") } footer: {
            Text("Search by the start of a name (e.g. \"Jo\" for John) or any word in the name (e.g. \"Smith\" for John Smith). Users must open the app and save their name in Profile (More → Profile → Edit) to appear in search.")
        }
    }


    private var pendingRequestsSection: some View {
        Section {
            if pendingIncoming.isEmpty {
                Text("No pending requests. When someone adds you by code or from search, they’ll appear here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(pendingIncoming.enumerated()), id: \.offset) { _, req in
                    PendingRequestRow(request: req, onAccept: { acceptRequest(req) }, onDecline: { declineRequest(req) }, actionInProgress: $actionInProgress)
                }
            }
        } header: { Text("Pending Requests") } footer: {
            Text("Accept or decline friend requests from people who added you.")
        }
    }
    
    private var sentRequestsSection: some View {
        Section {
            if pendingOutgoing.isEmpty {
                Text("No sent requests. When you add someone by search or code, they'll appear here until they accept or decline.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(pendingOutgoing.enumerated()), id: \.offset) { _, req in
                    SentRequestRow(request: req)
                }
            }
        } header: { Text("Sent Requests") } footer: {
            Text("Requests you've sent. Status will update when they accept or decline.")
        }
    }

    private var inviteSection: some View {
        Section(header: Text("Invite as Friend"), footer: Text("Share your friend code via email, text, or copy so others can add you.")) {
            if let code = myFriendCode {
                VStack(spacing: 16) {
                    if let qrImage = generateFriendQRCode(from: "faithjournal://friend/\(code)") {
                        friendQRCodeImage(qrImage)
                        Text("Scan to add me as a friend").font(.caption).foregroundColor(.secondary)
                    }
                    HStack {
                        Text(code)
                            .font(.title3.weight(.semibold))
                            .fontDesign(.monospaced)
                            .foregroundColor(.purple)
                    Spacer()
                    Button(action: {
                        PlatformPasteboard.setString(code)
                        showCopyAlert = true
                    }) { Image(systemName: "doc.on.doc").foregroundColor(.blue) }
                    #if os(iOS)
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up").foregroundColor(.blue)
                    }
                    #endif
                    }
                }
                .padding(.vertical, 8)
            } else if !friendCodeLoaded {
                HStack {
                    Text("Loading...").foregroundColor(.secondary)
                    Spacer()
                    ProgressView().scaleEffect(0.8)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Couldn't load friend code. Make sure you're signed in.")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Button("Retry") { loadFriendCode() }
                        .font(.subheadline.weight(.medium))
                }
            }
            #if os(iOS)
            shareInviteButtons
            #endif
        }
    }

    @ViewBuilder
    private var shareInviteButtons: some View {
        let hasCode = myFriendCode != nil
        VStack(spacing: 12) {
            Button(action: { if hasCode { showingShareSheet = true } }) {
                Label("Share via Text or Other Apps", systemImage: "message.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(!hasCode)
            .opacity(hasCode ? 1 : 0.6)
            HStack(spacing: 12) {
                Button(action: {
                    guard hasCode else { return }
                    #if os(iOS)
                    if MFMailComposeViewController.canSendMail() {
                        showingEmailComposer = true
                    } else {
                        showingShareSheet = true
                    }
                    #elseif os(macOS)
                    PlatformPasteboard.setString(friendShareText())
                    showCopyAlert = true
                    #endif
                }) {
                    Label("Email", systemImage: "envelope.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!hasCode)
                .opacity(hasCode ? 1 : 0.6)
                Button(action: {
                    guard hasCode else { return }
                    PlatformPasteboard.setString(myFriendCode ?? "")
                    showCopyAlert = true
                }) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!hasCode)
                .opacity(hasCode ? 1 : 0.6)
            }
        }
        .padding(.vertical, 8)
    }

    private var addByCodeSection: some View {
        Section(header: Text("Add by Code"), footer: Text("Enter a friend's code or scan their QR code to send a friend request.")) {
            HStack {
                TextField("Friend code (6 characters)", text: $addByCodeText)
                    #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    #endif
                    .autocorrectionDisabled()
                #if os(iOS)
                Button(action: { showingQRScanner = true }) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title2)
                        .foregroundColor(.purple)
                }
                #endif
                if actionInProgress == "code" {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Button("Send") { addFriendByCode() }
                        .disabled(addByCodeText.trimmingCharacters(in: .whitespaces).count != 6)
                }
            }
        }
    }

    private func generateFriendQRCode(from string: String) -> PlatformImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        #if os(iOS)
        return UIImage(cgImage: cgImage)
        #else
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #endif
    }

    @ViewBuilder
    private func friendQRCodeImage(_ image: PlatformImage) -> some View {
        #if os(iOS)
        let img = Image(uiImage: image)
        #else
        let img = Image(nsImage: image)
        #endif
        img
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: 160, height: 160)
            .padding(12)
            .background(Color.white)
            .cornerRadius(12)
    }

    private func friendShareText() -> String {
        let code = myFriendCode ?? ""
        return """
        Add me on Faith Journal! My friend code: \(code)

        To add me as a friend:
        1. Open Faith Journal
        2. Go to Faith Friends
        3. Enter my code: \(code)
        """
    }

    private func friendShareItems() -> [Any] {
        let code = myFriendCode ?? ""
        let text = friendShareText()
        var items: [Any] = [text]
        if let url = URL(string: "faithjournal://friend/\(code)") {
            items.append(url)
        }
        return items
    }

    private func addFriendByCode() {
        let code = addByCodeText.trimmingCharacters(in: .whitespaces).uppercased()
        guard code.count == 6 else { return }
        actionInProgress = "code"
        Task {
            do {
                try await FirebaseSyncService.shared.sendFriendRequestByCode(code)
                await MainActor.run {
                    actionInProgress = nil
                    addByCodeText = ""
                    loadFriends()
                }
            } catch {
                await MainActor.run {
                    actionInProgress = nil
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    private func performSearch() {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { searchResults = []; lastSearchFoundSelfOnly = false; return }
        isSearching = true
        Task {
            let results = await FirebaseSyncService.shared.searchUsers(query: q)
            await MainActor.run {
                let filtered = results.filter { ($0["userId"] as? String) != myUserId }
                searchResults = filtered
                lastSearchFoundSelfOnly = !results.isEmpty && filtered.isEmpty
                isSearching = false
            }
        }
    }

    private func loadFriendCode() {
        friendCodeLoaded = false
        Task {
            // Quick path: already have a code
            if let existing = await FirebaseSyncService.shared.getMyFriendCode() {
                await MainActor.run {
                    myFriendCode = existing
                    friendCodeLoaded = true
                }
                return
            }
            // Race: ensure code (may hang) vs 10s timeout so we never stick on "Loading..."
            enum LoadResult { case code(String?); case timeout }
            let loadResult: LoadResult = await withTaskGroup(of: LoadResult.self) { group in
                group.addTask {
                    let code = await FirebaseSyncService.shared.ensureAndGetMyFriendCode()
                    return .code(code)
                }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 10_000_000_000)
                    return .timeout
                }
                return await group.next() ?? .timeout
            }
            await MainActor.run {
                switch loadResult {
                case .code(let code):
                    myFriendCode = code
                case .timeout:
                    myFriendCode = nil
                }
                friendCodeLoaded = true
            }
        }
    }

    private func loadFriends() {
        isLoadingFriends = true
        Task {
            let (friendsList, pending, sent) = await FirebaseSyncService.shared.fetchFriendsFromFirebase()
            await MainActor.run {
                friends = friendsList
                pendingIncoming = pending
                pendingOutgoing = sent
                FirebaseSyncService.shared.pendingFriendRequestCount = pending.count
                isLoadingFriends = false
            }
        }
    }

    private func addFriend(user: [String: Any]) {
        guard let userId = user["userId"] as? String, let displayName = user["displayName"] as? String else { return }
        actionInProgress = userId
        Task {
            do {
                try await FirebaseSyncService.shared.sendFriendRequest(toUserId: userId, toDisplayName: displayName)
                await MainActor.run { actionInProgress = nil; loadFriends() }
            } catch {
                await MainActor.run { actionInProgress = nil; errorMessage = error.localizedDescription; showingError = true }
            }
        }
    }

    private func acceptRequest(_ req: [String: Any]) {
        guard let fromUserId = req["friendUserId"] as? String else { return }
        actionInProgress = fromUserId
        Task {
            do {
                try await FirebaseSyncService.shared.acceptFriendRequest(fromUserId: fromUserId)
                await MainActor.run { actionInProgress = nil; loadFriends(); loadPrayerWall(); loadFriendSharedReading() }
            } catch {
                await MainActor.run { actionInProgress = nil; errorMessage = error.localizedDescription; showingError = true }
            }
        }
    }

    private func declineRequest(_ req: [String: Any]) {
        guard let fromUserId = req["friendUserId"] as? String else { return }
        actionInProgress = fromUserId
        Task {
            do {
                try await FirebaseSyncService.shared.declineFriendRequest(fromUserId: fromUserId)
                await MainActor.run { actionInProgress = nil; loadFriends() }
            } catch {
                await MainActor.run { actionInProgress = nil; errorMessage = error.localizedDescription; showingError = true }
            }
        }
    }
    
    private func confirmRemoveFriend() {
        guard let f = friendToRemove, let friendUserId = f["friendUserId"] as? String else {
            friendToRemove = nil
            return
        }
        actionInProgress = friendUserId
        friendToRemove = nil
        Task {
            do {
                try await FirebaseSyncService.shared.removeFriend(friendUserId: friendUserId)
                await MainActor.run { actionInProgress = nil; loadFriends(); loadPrayerWall(); loadFriendSharedReading() }
            } catch {
                await MainActor.run { actionInProgress = nil; errorMessage = error.localizedDescription; showingError = true }
            }
        }
    }

    private func processPendingFriendCodeIfNeeded() {
        guard !hasProcessedPendingFriendCode else { return }
        guard let code = UserDefaults.standard.string(forKey: "pendingFriendCode")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(),
              code.count == 6 else { return }
        hasProcessedPendingFriendCode = true
        UserDefaults.standard.removeObject(forKey: "pendingFriendCode")
        addByCodeText = code
        addFriendByCode()
    }

    // MARK: - Prayer Wall

    private var prayerWallSection: some View {
        Section {
            if isLoadingPrayerWall {
                HStack { Spacer(); ProgressView(); Spacer() }.padding()
            } else if friendsSharedPrayers.isEmpty {
                Text("No shared prayers yet. When friends share a prayer, it appears here.")
                    .font(.subheadline).foregroundColor(.secondary).padding(.vertical, 8)
            } else {
                ForEach(Array(friendsSharedPrayers.prefix(10).enumerated()), id: \.offset) { _, prayer in
                    SharedPrayerCard(
                        prayer: prayer,
                        hasInterceeded: intercessedPrayerIds.contains(prayer["id"] as? String ?? ""),
                        onPray: { prayForFriend(prayer: prayer) }
                    )
                }
            }
        } header: { Text("Prayer Wall") } footer: {
            Text("Pray alongside your friends. Tap \"I'm Praying\" to let them know you stood with them.")
        }
    }

    private func loadPrayerWall() {
        isLoadingPrayerWall = true
        Task {
            let prayers = await FirebaseSyncService.shared.fetchFriendsSharedPrayers()
            await MainActor.run {
                friendsSharedPrayers = prayers
                isLoadingPrayerWall = false
            }
        }
    }

    private func prayForFriend(prayer: [String: Any]) {
        guard let prayerId = prayer["id"] as? String,
              let ownerId = prayer["ownerId"] as? String else { return }
        intercessedPrayerIds.insert(prayerId)
        Task {
            do {
                try await FirebaseSyncService.shared.prayForFriend(ownerId: ownerId, prayerId: prayerId)
            } catch {
                _ = await MainActor.run { intercessedPrayerIds.remove(prayerId) }
            }
        }
    }

    // MARK: - Accountability Partner

    private var accountabilityPartnerSection: some View {
        Section {
            if isLoadingPartner {
                HStack { Spacer(); ProgressView(); Spacer() }.padding()
            } else if let partnerId = accountabilityPartnerId, let partnerName = accountabilityPartnerName {
                AccountabilityPartnerCard(
                    partnerName: partnerName,
                    myPrayerRequests: myPrayerRequests,
                    readingNudge: accountabilityReadingNudge,
                    onRemove: { removeAccountabilityPartner() }
                )
                .swipeActions(edge: .trailing) {
                    Button("Remove", role: .destructive) { removeAccountabilityPartner() }
                }
                let _ = partnerId // suppress unused warning
            } else {
                Text("No accountability partner set. Long-press a friend to assign one.")
                    .font(.subheadline).foregroundColor(.secondary).padding(.vertical, 8)
            }
        } header: { Text("Accountability Partner") } footer: {
            Text("Your partner receives a weekly summary of your prayer activity to encourage consistency.")
        }
    }

    private func loadAccountabilityPartner() {
        isLoadingPartner = true
        Task {
            let partner = await FirebaseSyncService.shared.fetchAccountabilityPartner()
            await MainActor.run {
                accountabilityPartnerId = partner?.userId
                accountabilityPartnerName = partner?.name
                isLoadingPartner = false
            }
            await loadAccountabilityReadingNudge()
        }
    }
    
    private func loadAccountabilityReadingNudge() async {
        let (pid, partnerName, planSnapshots) = await MainActor.run { () -> (String?, String?, [(title: String, duration: Int, currentDay: Int)]) in
            let shared = myReadingPlans.filter { $0.sharedWithFriends }
            let snapshots = shared.map { (title: $0.title, duration: $0.duration, currentDay: $0.currentDay) }
            return (accountabilityPartnerId, accountabilityPartnerName, snapshots)
        }
        guard let pId = pid, !pId.isEmpty, let pName = partnerName else {
            await MainActor.run { accountabilityReadingNudge = nil }
            return
        }
        if planSnapshots.isEmpty {
            await MainActor.run { accountabilityReadingNudge = nil }
            return
        }
        let remote = await FirebaseSyncService.shared.fetchSharedReadingPlansForFriend(friendUserId: pId)
        for plan in planSnapshots {
            if let m = remote.first(where: { ($0["title"] as? String) == plan.title && ($0["duration"] as? Int) == plan.duration }) {
                let pDay = (m["currentDay"] as? Int) ?? 1
                let mDay = plan.currentDay
                if pDay != mDay {
                    await MainActor.run {
                        accountabilityReadingNudge = "\(pName) is on day \(pDay) of \(plan.duration) on “\(plan.title)”; you’re on day \(mDay)."
                    }
                    return
                }
            }
        }
        await MainActor.run { accountabilityReadingNudge = nil }
    }
    
    private func loadFriendSharedReading() {
        isLoadingFriendReading = true
        Task {
            let rows = await FirebaseSyncService.shared.fetchFriendsSharedReadingPlans()
            await MainActor.run {
                friendSharedReadingPlans = rows
                isLoadingFriendReading = false
            }
        }
    }
    
    // MARK: - Shared reading with friends (group progress)
    
    private var friendSharedReadingSection: some View {
        Section {
            if isLoadingFriendReading {
                HStack { Spacer(); ProgressView(); Spacer() }.padding()
            } else if friendSharedReadingPlans.isEmpty {
                Text("No shared reading plans from friends. Turn on “Share progress with friends” in a plan’s settings to see progress here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(Array(friendSharedReadingPlans.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(row["ownerName"] as? String ?? "Friend")
                            .font(.subheadline.weight(.semibold))
                        Text((row["title"] as? String) ?? "Reading plan")
                            .font(.body)
                        HStack {
                            if let c = row["currentDay"] as? Int, let d = row["duration"] as? Int {
                                Text("Day \(c) of \(d)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let s = row["streakCount"] as? Int, s > 0 {
                                Text("·")
                                    .foregroundColor(.secondary)
                                Text("\(s)-day streak")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: { Text("Friends’ reading (shared plans)") } footer: {
            Text("Shows each friend’s current day and streak for plans they share with friends.")
        }
    }

    private func setAccountabilityPartner(friend: [String: Any]) {
        let friendId = friend["friendUserId"] as? String ?? ""
        let friendName = friend["friendDisplayName"] as? String ?? friend["displayName"] as? String ?? "Friend"
        accountabilityPartnerId = friendId
        accountabilityPartnerName = friendName
        scheduleWeeklySummaryNotification()
        Task { await FirebaseSyncService.shared.setAccountabilityPartner(friendUserId: friendId, friendDisplayName: friendName) }
    }

    private func removeAccountabilityPartner() {
        accountabilityPartnerId = nil
        accountabilityPartnerName = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["accountability-partner-weekly"])
        Task { await FirebaseSyncService.shared.removeAccountabilityPartner() }
    }

    private func scheduleWeeklySummaryNotification() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["accountability-partner-weekly"])
            let content = UNMutableNotificationContent()
            content.title = "Weekly Prayer Summary"
            content.body = "Share your prayer activity with your accountability partner this week."
            content.sound = .default
            var components = DateComponents()
            components.weekday = 1 // Sunday
            components.hour = 8
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "accountability-partner-weekly", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Updated Friends Section

    private var friendsSectionWithPartner: some View {
        Section {
            if isLoadingFriends {
                HStack { Spacer(); ProgressView(); Spacer() }.padding()
            } else if friends.isEmpty {
                Text("No friends yet. Search above to add friends.").foregroundColor(.secondary).padding(.vertical, 8)
            } else {
                ForEach(Array(friends.enumerated()), id: \.offset) { _, f in
                    let fId = f["friendUserId"] as? String ?? ""
                    FriendRow(
                        friend: f,
                        isAccountabilityPartner: fId == accountabilityPartnerId,
                        onSetAsPartner: { setAccountabilityPartner(friend: f) },
                        onRemoveAsPartner: { removeAccountabilityPartner() }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            friendToRemove = f
                            showingRemoveConfirm = true
                        } label: { Label("Remove Friend", systemImage: "person.badge.minus") }
                    }
                }
            }
        } header: { Text("My Friends") } footer: {
            Text("Long-press a friend to set them as your accountability partner.")
        }
    }
}

@available(iOS 17.0, *)
private struct FriendAvatarView: View {
    let avatarURL: String?
    let displayName: String
    let size: CGFloat
    let accent: Color
    var body: some View {
        Group {
            if let urlString = avatarURL, let url = URL(string: urlString), urlString.hasPrefix("http") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        avatarInitial
                    @unknown default:
                        avatarInitial
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                avatarInitial
            }
        }
    }
    private var initialFont: Font {
        if size <= 28 { return .caption2.weight(.semibold) }
        if size <= 36 { return .caption.weight(.semibold) }
        return .headline
    }

    private var avatarInitial: some View {
        Circle()
            .fill(accent.opacity(0.3))
            .frame(width: size, height: size)
            .overlay(
                Text(String(displayName.prefix(1)).uppercased())
                    .font(initialFont)
                    .foregroundColor(accent)
            )
    }
}

@available(iOS 17.0, *)
private struct UserSearchRow: View {
    let user: [String: Any]
    let myUserId: String?
    let friendUserIds: Set<String>
    let onAddFriend: () -> Void
    @Binding var actionInProgress: String?
    private var userId: String? { user["userId"] as? String }
    private var displayName: String { user["displayName"] as? String ?? "Unknown" }
    private var avatarURL: String? { user["avatarURL"] as? String }
    private var isFriend: Bool { userId.map { friendUserIds.contains($0) } ?? false }
    private var isPending: Bool { userId.map { actionInProgress == $0 } ?? false }
    var body: some View {
        HStack {
            FriendAvatarView(avatarURL: avatarURL, displayName: displayName, size: 44, accent: .purple)
            Text(displayName).font(.headline)
            Spacer()
            if isFriend { Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
            else {
                Button(action: onAddFriend) {
                    if isPending { ProgressView().scaleEffect(0.8) }
                    else { Text("Add").font(.subheadline.weight(.medium)).foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 6).background(Color.purple).cornerRadius(8) }
                }.disabled(isPending)
            }
        }.padding(.vertical, 4)
    }
}

@available(iOS 17.0, *)
private struct FriendRow: View {
    let friend: [String: Any]
    let isAccountabilityPartner: Bool
    let onSetAsPartner: () -> Void
    let onRemoveAsPartner: () -> Void
    private var displayName: String { friend["friendDisplayName"] as? String ?? friend["displayName"] as? String ?? "Friend" }
    private var avatarURL: String? { friend["friendAvatarURL"] as? String }
    var body: some View {
        HStack(spacing: 8) {
            FriendAvatarView(avatarURL: avatarURL, displayName: displayName, size: 28, accent: .purple)
            Text(displayName)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(1)
            Spacer(minLength: 6)
            if isAccountabilityPartner {
                Image(systemName: "shield.checkered")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.purple)
                    .accessibilityLabel("Accountability partner")
            }
        }
        .padding(.vertical, 2)
        .listRowInsets(EdgeInsets(top: 1, leading: 14, bottom: 1, trailing: 12))
        .contextMenu {
            if isAccountabilityPartner {
                Button(role: .destructive, action: onRemoveAsPartner) {
                    Label("Remove as Partner", systemImage: "shield.slash")
                }
            } else {
                Button(action: onSetAsPartner) {
                    Label("Set as Accountability Partner", systemImage: "shield.checkered")
                }
            }
        }
    }
}

@available(iOS 17.0, *)
private struct SharedPrayerCard: View {
    let prayer: [String: Any]
    let hasInterceeded: Bool
    let onPray: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared

    private var title: String { prayer["title"] as? String ?? "Prayer Request" }
    private var details: String { prayer["details"] as? String ?? "" }
    private var ownerName: String { prayer["ownerName"] as? String ?? "Friend" }
    private var ownerAvatarURL: String? { prayer["ownerAvatarURL"] as? String }
    private var intercessorCount: Int { (prayer["intercessorIds"] as? [String])?.count ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                FriendAvatarView(avatarURL: ownerAvatarURL, displayName: ownerName, size: 32, accent: .purple)
                Text(ownerName).font(.subheadline.weight(.medium))
                Spacer()
                if intercessorCount > 0 {
                    Label("\(intercessorCount)", systemImage: "hands.and.sparkles.fill")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }
            Text(title).font(.headline)
            if !details.isEmpty {
                Text(details)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            Button(action: onPray) {
                HStack {
                    Image(systemName: hasInterceeded ? "hands.and.sparkles.fill" : "hands.and.sparkles")
                    Text(hasInterceeded ? "Praying ✓" : "I'm Praying")
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(hasInterceeded ? Color.purple.opacity(0.12) : themeManager.colors.primary)
                .foregroundColor(hasInterceeded ? .purple : .white)
                .cornerRadius(10)
            }
            .disabled(hasInterceeded)
        }
        .padding(.vertical, 4)
    }
}

@available(iOS 17.0, *)
private struct AccountabilityPartnerCard: View {
    let partnerName: String
    let myPrayerRequests: [PrayerRequest]
    var readingNudge: String? = nil
    let onRemove: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared

    private var thisWeekCheckIns: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return myPrayerRequests.reduce(0) { sum, req in
            sum + req.checkInDates.filter { $0 >= weekAgo }.count
        }
    }
    private var activeRequests: Int { myPrayerRequests.filter { $0.status == .active }.count }
    private var answeredThisMonth: Int {
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return myPrayerRequests.filter { $0.isAnswered && ($0.answerDate ?? .distantPast) >= monthAgo }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundColor(.purple)
                Text(partnerName)
                    .font(.headline)
                Spacer()
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.secondary)
                }
            }
            HStack(spacing: 16) {
                VStack {
                    Text("\(thisWeekCheckIns)")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.orange)
                    Text("Prayers\nThis Week")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                Divider()
                VStack {
                    Text("\(activeRequests)")
                        .font(.title2.weight(.bold))
                        .foregroundColor(themeManager.colors.primary)
                    Text("Active\nRequests")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                Divider()
                VStack {
                    Text("\(answeredThisMonth)")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.green)
                    Text("Answered\nThis Month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            if let nudge = readingNudge, !nudge.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "book.closed.fill")
                        .foregroundColor(themeManager.colors.primary)
                    Text(nudge)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }
}

@available(iOS 17.0, *)
private struct FriendLiveBanner: View {
    let alert: FirebaseSyncService.FriendSessionAlert
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundColor(.white)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(alert.hostName) is Live!")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text(alert.sessionTitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

@available(iOS 17.0, *)
private struct SentRequestRow: View {
    let request: [String: Any]
    private var displayName: String {
        request["displayName"] as? String ?? "Unknown User"
    }
    private var avatarURL: String? { request["avatarURL"] as? String }
    private var status: String { request["status"] as? String ?? "pending" }
    var body: some View {
        HStack {
            FriendAvatarView(avatarURL: avatarURL, displayName: displayName, size: 40, accent: .blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName).font(.headline)
                Text(status == "pending" ? "Pending — waiting for response" : status.capitalized)
                    .font(.caption)
                    .foregroundColor(status == "pending" ? .orange : .secondary)
            }
            Spacer()
        }.padding(.vertical, 4)
    }
}

@available(iOS 17.0, *)
private struct PendingRequestRow: View {
    let request: [String: Any]
    let onAccept: () -> Void
    let onDecline: () -> Void
    @Binding var actionInProgress: String?
    private var displayName: String {
        if let id = request["friendUserId"] as? String { return request["displayName"] as? String ?? String(id.prefix(8)) + "..." }
        return "Unknown"
    }
    private var avatarURL: String? { request["avatarURL"] as? String }
    private var fromUserId: String? { request["friendUserId"] as? String }
    private var isBusy: Bool { fromUserId.map { actionInProgress == $0 } ?? false }
    var body: some View {
        HStack {
            FriendAvatarView(avatarURL: avatarURL, displayName: displayName, size: 40, accent: .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName).font(.headline)
                Text("Wants to be friends").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if isBusy { ProgressView().scaleEffect(0.8) }
            else {
                Button("Decline", action: onDecline).font(.caption).foregroundColor(.secondary)
                Button("Accept", action: onAccept).font(.subheadline.weight(.medium)).foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 6).background(Color.purple).cornerRadius(8)
            }
        }.padding(.vertical, 4).disabled(isBusy)
    }
}

#if os(iOS)
@available(iOS 17.0, *)
private struct FriendInviteEmailComposerView: UIViewControllerRepresentable {
    let subject: String
    let body: String

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}
#endif

#Preview {
    NavigationStack { FaithFriendsView().modelContainer(for: [FaithFriend.self, PrayerRequest.self], inMemory: true) }
}
