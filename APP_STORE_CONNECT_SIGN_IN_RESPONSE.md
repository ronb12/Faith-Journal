# App Store Connect - Sign-In Information Response

## Response for "Sign-In Information" Field

### ✅ Answer: **No sign-in required**

**For the App Store Connect "Sign-In Information" field, enter:**

```
N/A - This app does not require sign-in. All features work without authentication.

The app uses:
- Local storage (SwiftData) for all core features
- Optional iCloud sync (automatic - uses device's Apple ID if available)
- No username/password required
- No account creation needed

All features are accessible immediately upon app launch:
- Journal entries (works locally)
- Prayer requests (works locally)  
- Bible study (all content offline)
- Reading plans (works locally)
- Devotionals (all content offline)
- Statistics (works locally)

CloudKit/iCloud is optional and automatic - it uses the device's Apple ID if the user is already signed in to iCloud on their device. No separate authentication is required.
```

---

## Alternative Response (If Field Requires a Value):

If the field won't accept "N/A", you can enter:

```
Username: Not Required
Password: Not Required

Note: This app works fully without sign-in. CloudKit uses the device's Apple ID automatically if the user is signed in to iCloud. No separate credentials are needed.
```

---

## Why This Is Correct

1. **No Custom Authentication System**
   - The app doesn't have a username/password login screen
   - No account creation process
   - No separate authentication system

2. **CloudKit Is Automatic**
   - Uses the device's existing Apple ID
   - No sign-in prompt (only checks if iCloud is available)
   - Works perfectly without iCloud

3. **All Features Work Without Sign-In**
   - Core features use local storage
   - CloudKit is optional enhancement
   - App never blocks access based on authentication

4. **App Store Reviewers Can Test Everything**
   - Open app → all features work
   - No sign-in required
   - Sample data provided on first launch

---

## What to Select in App Store Connect

**Question: "Does your app require sign-in?"**
- ✅ **Select: NO**

**Question: "Sign-In Information" (if still shown)**
- Enter: **"N/A - No sign-in required. App works fully without authentication."**

---

## Notes for Reviewer (Add to Review Notes):

```
This app does not require sign-in. All features work without authentication.

Testing Instructions:
1. Open the app - no sign-in required
2. All features are immediately accessible
3. Sample data is provided on first launch (journal entries, prayers)
4. CloudKit/iCloud is optional and automatic (uses device Apple ID if available)

The app uses:
- Local storage for all core features (works offline)
- Optional iCloud sync (automatic, no credentials needed)
- No username/password system
- No account creation required
```

---

**Bottom Line:** The app doesn't require sign-in, so you can mark "No sign-in required" in App Store Connect. If they still ask for credentials, explain that no sign-in is needed as all features work locally.

