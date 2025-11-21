# App Store Reviewer Notes

## Testing Without Sign-In

**This app works fully without requiring sign-in.** All core features are available for testing without an Apple ID or iCloud account.

### ✅ Core Features (Available Without Sign-In):

1. **Journal Entries**
   - Create, edit, and delete journal entries
   - Add photos, audio, and drawings
   - View sample entries on first launch

2. **Prayer Requests**
   - Create and track prayer requests
   - Mark prayers as answered
   - View sample prayers on first launch

3. **Bible Study**
   - Browse 50+ Bible study topics
   - Read verses and answer study questions
   - Track progress and favorites
   - All content works offline

4. **Reading Plans**
   - View and start reading plans
   - Track daily readings
   - Complete readings

5. **Devotionals**
   - Read daily devotionals
   - Browse by category
   - All content is local

6. **Statistics**
   - View app usage statistics
   - Mood analytics
   - Activity tracking

7. **Settings**
   - Configure app preferences
   - Set reminders
   - Edit profile
   - Privacy policy and terms

### ℹ️ Optional Feature (Requires iCloud - Not Required for Testing):

**Live Sessions** - This feature enables multi-user Bible study sessions via CloudKit. It:
- Works locally without iCloud (creates local sessions)
- Only requires iCloud for sharing with other users
- Gracefully handles no authentication
- Does not block other features

### Testing Instructions:

1. **No Sign-In Required** - Simply open the app and start using it
2. **Sample Data** - The app automatically creates sample journal entries and prayers on first launch
3. **All Features Work** - Every core feature works without sign-in
4. **CloudKit is Optional** - iCloud sign-in is only needed for Live Sessions sharing feature

### Key Points for Reviewers:

- ✅ **No sign-in prompt** - App works immediately
- ✅ **All core features accessible** - No features are locked behind sign-in
- ✅ **Sample data provided** - Easy to test without creating content
- ✅ **Graceful degradation** - Live Sessions feature works locally without iCloud

---

**The app is designed to work fully offline and without sign-in. iCloud is purely optional for enhanced syncing features.**

