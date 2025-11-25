# Multi-User Live Sessions Setup Guide

## Overview

Live Sessions have been optimized to support **multiple independent users** with different Apple IDs. This uses CloudKit's **public database** to enable sharing between different users.

## Architecture

### Dual Database Strategy

```
Private Database (SwiftData + CloudKit)
├── JournalEntry        (user-specific)
├── PrayerRequest       (user-specific)
├── MoodEntry          (user-specific)
└── UserProfile        (user-specific)

Public Database (CloudKit Direct)
├── LiveSession        (shared across users)
├── LiveSessionParticipant  (shared across users)
└── ChatMessage        (shared across users)
```

### How It Works

1. **Private Data** (Journal, Prayers, Moods)
   - Stored in SwiftData → CloudKit Private Database
   - Only synced across user's own devices
   - Not visible to other users

2. **Shared Data** (Live Sessions)
   - Stored in SwiftData locally (for UI)
   - Synced to CloudKit Public Database (for sharing)
   - Visible to all users with different Apple IDs
   - Anyone can see and join public sessions

## Implementation Details

### Services Created

1. **CloudKitUserService** (`Services/CloudKitUserService.swift`)
   - Manages user authentication
   - Gets CloudKit user record ID (unique per Apple ID)
   - Retrieves user display name
   - Falls back to device identifier if CloudKit unavailable

2. **CloudKitPublicSyncService** (`Services/CloudKitPublicSyncService.swift`)
   - Syncs sessions to public CloudKit database
   - Fetches public sessions from other users
   - Handles participants and messages
   - Sets up push notifications for real-time updates

### Key Changes

1. **User Identification**
   ```swift
   // OLD: Device UUID (only works for same device)
   let userId = UIDevice.current.identifierForVendor?.uuidString
   
   // NEW: CloudKit Record ID (unique per Apple ID)
   let userId = CloudKitUserService.shared.userIdentifier
   ```

2. **Session Creation**
   - Sessions saved to SwiftData (local)
   - **Also** synced to CloudKit Public Database
   - Other users can see public sessions

3. **Session Discovery**
   - Loads local sessions (SwiftData)
   - **Also** fetches public sessions from CloudKit
   - Combines and removes duplicates
   - Updates via pull-to-refresh or subscriptions

4. **Chat Messages**
   - Messages saved locally (SwiftData)
   - **Also** synced to public database
   - All participants see messages from all users

## CloudKit Setup Required

### In Xcode CloudKit Dashboard

1. **Enable CloudKit Capability**
   - Project → Signing & Capabilities
   - Add "CloudKit" capability
   - Container: `iCloud.com.ronellbradley.FaithJournal` (or default)

2. **Create Schema in CloudKit Dashboard**
   
   **Record Type: `LiveSession`**
   - `title` (String)
   - `details` (String)
   - `hostId` (String, Indexed)
   - `startTime` (Date/Time, Indexed)
   - `endTime` (Date/Time, Optional)
   - `isActive` (Int(64))
   - `maxParticipants` (Int(64))
   - `currentParticipants` (Int(64))
   - `category` (String, Indexed)
   - `tags` (String List)
   - `isPrivate` (Int(64))
   - `createdAt` (Date/Time)

   **Record Type: `LiveSessionParticipant`**
   - `sessionId` (String, Indexed)
   - `userId` (String, Indexed)
   - `userName` (String)
   - `joinedAt` (Date/Time)
   - `leftAt` (Date/Time, Optional)
   - `isHost` (Int(64))
   - `isActive` (Int(64))

   **Record Type: `ChatMessage`**
   - `sessionId` (String, Indexed)
   - `userId` (String, Indexed)
   - `userName` (String)
   - `message` (String)
   - `timestamp` (Date/Time, Indexed)
   - `messageType` (String)

3. **Set Security Roles**
   - All record types: **Public** (anyone can read/write)
   - OR implement custom security rules for private sessions

4. **Enable Subscriptions**
   - Set up for push notifications
   - Record Type: `LiveSession` (create/update/delete)
   - Record Type: `ChatMessage` (create/update)
   - Predicate: Based on active sessions

## How It Works for Users

### User A (Apple ID: john@example.com)
1. Creates "Morning Prayer" session
2. Session saved to CloudKit Public Database
3. Session appears in their app immediately

### User B (Apple ID: jane@example.com)
1. Opens Live Sessions tab
2. App fetches public sessions from CloudKit
3. Sees "Morning Prayer" session from User A
4. Can join and participate

### User C (Apple ID: bob@example.com)
1. Sees same public sessions
2. Joins "Morning Prayer" session
3. All participants see updated count
4. Can chat with User A and User B

## Privacy Options

### Public Sessions (Default)
- Visible to all users
- Anyone can join
- Messages visible to all participants
- Best for: Community prayer, open Bible study

### Private Sessions
- Only visible to invited users (future feature)
- Requires invitation link/code
- Messages only visible to participants
- Best for: Small groups, confidential prayer

## Real-Time Updates

### Current Implementation
- **Push Notifications**: CloudKit subscriptions notify app of changes
- **Pull-to-Refresh**: Manual refresh loads latest data
- **Auto-Refresh**: On view appear, fetches public sessions

### Latency
- **Best Case**: 1-3 seconds (push notification)
- **Typical**: 3-5 seconds
- **Manual Refresh**: Immediate when user pulls to refresh

### Future Enhancement
For true real-time (< 100ms), consider:
- WebSocket server
- Firebase Realtime Database
- Pusher/Ably service

## User Experience Flow

```
┌─────────────────────────────────────────────────────┐
│ User A Creates Session                              │
│                                                      │
│ 1. Fill out session form                           │
│ 2. Tap "Create"                                     │
│ 3. Session saved to SwiftData (instant)            │
│ 4. Session synced to CloudKit Public DB (2-5s)     │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│ User B Opens Live Sessions                          │
│                                                      │
│ 1. View loads                                       │
│ 2. Fetches public sessions from CloudKit            │
│ 3. Sees User A's session (if public)               │
│ 4. Can join session                                 │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│ User B Joins Session                                │
│                                                      │
│ 1. Taps "Join"                                      │
│ 2. Participant record created locally              │
│ 3. Participant synced to public DB (2-5s)          │
│ 4. User A sees updated participant count            │
│ 5. Both users can chat                              │
└─────────────────────────────────────────────────────┘
```

## Testing Multi-User

### Setup Test Users

1. **Test User 1** (Apple ID 1)
   - Device: iPhone
   - Create session: "Test Prayer Session"

2. **Test User 2** (Apple ID 2)
   - Device: iPad (different Apple ID)
   - Should see "Test Prayer Session"
   - Can join and chat

3. **Test User 3** (Apple ID 3)
   - Device: Another iPhone
   - Should see same session
   - All three can participate

### Verification

- ✅ Sessions created by User 1 appear for User 2 & 3
- ✅ Participant count updates for all users
- ✅ Messages sent by one user appear for all
- ✅ User names display correctly
- ✅ Private sessions only visible to creator (if implemented)

## Troubleshooting

### Sessions Not Appearing

1. **Check CloudKit Authentication**
   ```swift
   CloudKitUserService.shared.isAuthenticated  // Should be true
   ```

2. **Verify CloudKit Schema**
   - Record types exist in CloudKit Dashboard
   - Fields match SwiftData model properties
   - Security roles allow public read/write

3. **Check Network**
   - iCloud account signed in
   - Internet connection active
   - CloudKit service available

4. **Manual Refresh**
   - Pull down to refresh sessions list
   - Check for errors in console

### Messages Not Syncing

1. **Check Session Privacy**
   - Private sessions don't sync messages to public DB
   - Only public sessions share messages

2. **Verify Subscriptions**
   - CloudKit subscriptions should be active
   - Check CloudKit Dashboard → Subscriptions

3. **Check User Authentication**
   - User must be signed into iCloud
   - CloudKit account status must be `.available`

## Security Considerations

### Current Implementation
- Public sessions: Anyone can read/write
- No authentication required to join
- User identification via CloudKit Record ID

### Recommended Enhancements
- Implement session invitations for private sessions
- Add rate limiting for message sending
- Implement user blocking/reporting
- Add moderation tools for hosts

## Next Steps

1. **Set up CloudKit Schema** (in Xcode CloudKit Dashboard)
2. **Test with multiple Apple IDs** (simulators or real devices)
3. **Monitor CloudKit usage** (quota limits)
4. **Consider WebSocket upgrade** (for true real-time if needed)

---

## Summary

✅ **Multi-User Support**: Different Apple IDs can share sessions  
✅ **Public Database**: Sessions visible to all users  
✅ **CloudKit Integration**: Uses CloudKit Public Database  
✅ **Real-Time-ish**: 1-5 second sync latency  
✅ **Automatic Sync**: Push notifications for updates  
⚠️ **Requires Setup**: CloudKit schema configuration needed  

