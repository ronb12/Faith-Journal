# Firestore Security Rules Setup

## Problem
You're getting the error: `❌ [FIREBASE] Failed to sync session invitation: Missing or insufficient permissions.`

This happens because Firestore security rules don't allow writes to the session invitation collections.

## Solution

### Step 1: Update Firestore Security Rules

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **faith-journal-d2a32**
3. Navigate to **Firestore Database** → **Rules** tab
4. Replace the existing rules with the rules from `firestore.rules` file in this directory

### Step 2: Deploy the Rules

**Option A: Using Firebase Console (Easiest)**
1. Copy the contents of `firestore.rules`
2. Paste into the Firebase Console Rules editor
3. Click **Publish**

**Option B: Using Firebase CLI**
```bash
# If you have Firebase CLI installed
firebase deploy --only firestore:rules
```

### Step 3: Verify Rules

After deploying, test the rules:
1. Try creating a session invitation in the app
2. Check the console logs - you should see:
   - `✅ [FIREBASE] Synced session invitation: ...`
   - No more permission errors

## What the Rules Allow

### ✅ Allowed Operations:

1. **User Collections** (`users/{userId}/...`)
   - Users can read/write their own data
   - Includes: journal entries, prayer requests, mood entries, etc.

2. **Public Session Invitations** (`sessionInvitations/{inviteCode}`)
   - **Read**: Anyone (for joining by code)
   - **Write**: Only authenticated users who are the host
   - **Update/Delete**: Only the host can modify their invitations

3. **Public Sessions** (`publicSessions/{sessionId}`)
   - **Read**: Anyone (for joining sessions)
   - **Write**: Only authenticated users who are the host
   - **Update/Delete**: Only the host can modify their sessions

### 🔒 Security Features:

- Users can only create invitations where `hostId` matches their `auth.uid`
- Users can only update/delete invitations they created
- Public collections are readable by anyone (needed for joining by code)
- All writes require authentication

## Testing

After deploying rules, test:
1. Generate an invitation code → Should sync successfully
2. Join by code → Should work from any device
3. Regenerate code → Should update old invitation status

## Troubleshooting

If you still get permission errors:

1. **Check Authentication**: Make sure user is signed in with Firebase Auth
   - Look for: `✅ [FIREBASE] User authenticated: ...` in logs

2. **Check User ID Match**: The `hostId` in the invitation must match `request.auth.uid`
   - Look for: `🔑 [FIREBASE] Firebase Auth User authenticated:` in logs

3. **Verify Rules Deployed**: Check Firebase Console → Firestore → Rules
   - Should show the new rules with timestamp

4. **Check Rule Syntax**: Make sure there are no syntax errors in the rules
   - Firebase Console will highlight errors in red

## Need Help?

If issues persist:
1. Check Firebase Console → Firestore → Usage tab for denied requests
2. Enable Firestore debug logging in Xcode
3. Check that `getCurrentUserId()` returns a valid Firebase Auth UID
