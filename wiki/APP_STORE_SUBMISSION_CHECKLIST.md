# App Store Submission Checklist - Version 3.8+

## ✅ Required Updates for New Features

You've added major new features that require App Store listing updates:

### 1. **Privacy Permission Descriptions** ✅ UPDATED
- ✅ Camera: Updated to mention live streaming
- ✅ Microphone: Updated to mention live streaming
- Location: Already correct
- Photo Library: Already correct

### 2. **Version Number** 
- **Current**: 3.7 (Build 31)
- **Recommended**: 3.8 or 4.0 (for major features)
  - **3.8** if these are feature additions
  - **4.0** if you consider this a major version update

### 3. **App Store Description** 📝 REQUIRES UPDATE

Update your App Store description to highlight:
- ✨ **Full Bible Feature**: Complete Bible text access
- 📹 **Live Streaming**: Real-time video/audio streaming for sessions
- 🔄 **Multi-participant**: Support for multiple users in live sessions

**Suggested description addition:**
```
NEW IN THIS UPDATE:
• Complete Bible - Access the full Bible text with search and highlights
• Live Streaming - Join or host live video sessions with fellow believers
• Multi-participant Sessions - Connect with multiple people in real-time
```

### 4. **App Store Screenshots** 📸 CONSIDER UPDATING

Consider adding screenshots showing:
- Bible view/search
- Live streaming session
- Multi-participant video layout

### 5. **App Store Privacy Questionnaire** 🔒 REQUIRES UPDATE

In App Store Connect, update the Privacy section to declare:

**Data Types Collected:**
- ✅ Audio Data (for live streaming)
- ✅ Video Data (for live streaming)
- ✅ User Content (chat messages during streams)

**Usage Purposes:**
- ✅ App Functionality (live streaming)
- ✅ Analytics (if you track stream analytics)

**Third-Party Partners:**
- ✅ Agora (for live streaming services)
- ✅ Firebase (for data sync)

**Privacy Policy Updates Needed:**
Your privacy policy should mention:
- Live streaming data handling
- Agora SDK integration
- Video/audio data transmission
- User-generated content in streams

### 6. **What's New Section** 📝 REQUIRES UPDATE

In App Store Connect, update "What's New in This Version":

**Suggested text:**
```
Version 3.8 - Major Feature Update

✨ NEW: Complete Bible
Access the full Bible text with powerful search, highlights, and notes.

📹 NEW: Live Streaming
Host or join live video sessions with fellow believers. Real-time video and audio streaming with support for multiple participants.

🔗 Enhanced: Session Invitations
Share invite codes or QR codes to join live sessions easily.

🎯 Improved: Better performance and stability
```

### 7. **App Store Keywords** 🔑 CONSIDER UPDATING

Add keywords if space permits:
- "live streaming"
- "video chat"
- "Bible study"
- "live sessions"

### 8. **Support URL** ✅ VERIFIED
- Privacy Policy: `https://faithjournal.app/privacy` ✅
- Terms: `https://faithjournal.app/terms` ✅

**Make sure these pages are updated** to mention:
- Live streaming features
- Video/audio data handling
- Agora integration

### 9. **TestFlight Notes** 📝 REQUIRES UPDATE

If using TestFlight, update internal/beta testing notes to mention:
- Live streaming testing
- Agora integration
- New Bible features

## 🚨 Critical App Store Review Considerations

### Live Streaming Features

App Store reviewers will check:
1. ✅ **Privacy permissions** - Must clearly state live streaming use
2. ✅ **Content moderation** - How you handle inappropriate content in streams
3. ✅ **User safety** - Reporting mechanisms, blocking users
4. ✅ **Terms of service** - Must cover live streaming use

### Recommendations:

1. **Content Moderation:**
   - Document how you handle inappropriate content
   - Have reporting mechanisms in place
   - Consider age restrictions if needed

2. **Terms of Service:**
   - Update terms to cover live streaming
   - Include acceptable use policy for streams
   - Mention recording policies (if any)

3. **App Review Notes:**
   - Mention that live streaming requires authentication
   - Note that Agora SDK handles infrastructure
   - Explain that sessions are invitation-based

## 📋 Submission Checklist

- [ ] Update Info.plist privacy descriptions ✅ DONE
- [ ] Increment version number (3.8 or 4.0)
- [ ] Update App Store description
- [ ] Update "What's New" section
- [ ] Update App Store Privacy questionnaire
- [ ] Update Privacy Policy webpage (mention live streaming)
- [ ] Update Terms of Service webpage (mention live streaming)
- [ ] Add new screenshots (optional but recommended)
- [ ] Update TestFlight notes
- [ ] Prepare App Review notes explaining new features

## 🎯 Quick Action Items

### Priority 1 (Before Submission):
1. Update version number in Xcode
2. Update App Store description
3. Update Privacy questionnaire in App Store Connect
4. Update Privacy Policy and Terms on your website

### Priority 2 (Recommended):
1. Add new screenshots
2. Update keywords
3. Prepare detailed App Review notes

## 📞 Support

If App Store reviewers have questions about:
- **Live streaming**: Explain it's invitation-based, authenticated, and uses Agora SDK
- **Privacy**: Point to your updated privacy policy
- **Safety**: Explain content moderation and reporting features
