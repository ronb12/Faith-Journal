# App Store Review Notes - Live Streaming Features

## For App Store Review Team

This document provides information about the live streaming features added in version 3.8+ to help with the review process.

## New Features Overview

### 1. **Full Bible Feature**
- Complete Bible text access
- Search, highlights, and notes
- Daily verse features
- No user-generated content issues

### 2. **Live Streaming Feature** ⚠️ REQUIRES ATTENTION
- Real-time video/audio streaming
- Multi-participant support
- Session-based (invitation-only)
- Content moderation implemented

## Live Streaming Details

### Architecture
- **SDK**: Agora RTC SDK (industry-standard, App Store approved)
- **Infrastructure**: Agora's global CDN
- **Token Server**: Vercel serverless functions (for authentication)
- **Data**: Video/audio streams processed in real-time, not permanently stored

### Privacy Permissions

**Camera Permission:**
- Purpose: Live streaming sessions and journal photos
- Usage Description: "Faith Journal uses the camera to take photos for journal entries, profile pictures, and live streaming sessions."

**Microphone Permission:**
- Purpose: Live streaming sessions and voice notes
- Usage Description: "Faith Journal uses the microphone to record voice notes and prayers for your journal entries, and for live streaming sessions."

### Content Moderation ✅

**Automated Filtering:**
- Keyword filtering for spam/inappropriate content
- Real-time message filtering
- Customizable filters for session hosts

**User Reporting:**
- In-app reporting system
- Report inappropriate messages/behavior
- Reports tracked and reviewed
- Action taken on violations

**User Blocking:**
- Users can block problematic users
- Blocked users cannot interact
- Blocks persist across sessions
- Auto-mute for blocked users

**Host Controls:**
- Session hosts can remove participants
- Hosts can mute/disable video
- Hosts can end sessions
- Invitation-only access (not public)

### User Safety ✅

**Reporting Mechanisms:**
- In-app message reporting
- User reporting system
- Support contact: ronellbradley@gmail.com
- Reports logged with timestamps and details

**Privacy Controls:**
- Invitation-only sessions (not publicly listed)
- Users control session access
- QR code invitations (secure sharing)
- Users can leave sessions anytime

**Account Actions:**
- Warnings for violations
- Temporary suspensions
- Permanent bans for serious violations
- Content removal for inappropriate material

### Terms of Service ✅

Updated Terms of Service include:
- Live streaming rules and guidelines
- Prohibited content (inappropriate, offensive, illegal)
- Content moderation policies
- User safety features
- Reporting and blocking procedures
- Session invitation rules
- Video/audio data handling

**Location**: In-app Terms of Service view and website: https://faithjournal.app/terms

### Privacy Policy ✅

Privacy Policy covers:
- Video/audio data collection for streaming
- Agora SDK integration
- Real-time data transmission
- User-generated content handling
- Third-party services (Agora, Firebase)

**Location**: In-app Privacy Policy view and website: https://faithjournal.app/privacy

## Testing Instructions

### To Test Live Streaming:

1. **Create Account**: Sign in with Apple ID
2. **Create Session**: Go to Live Sessions → Create Session
3. **Start Stream**: Tap "Start Streaming"
4. **Grant Permissions**: Allow camera and microphone access
5. **Share Invite**: Generate invitation code or QR code
6. **Join Session**: Use invite code from another device/user
7. **Test Moderation**: 
   - Block a user (tap user → Block)
   - Report a message (long-press message → Report)
   - Host controls (host can remove/mute participants)

### Test Credentials (if needed):
- Use any Apple ID for testing
- Sessions are invitation-only (no public access)
- All features work with standard user accounts

## Compliance Statements

### App Store Guidelines Compliance:

✅ **1.1 Safety - Objectionable Content**
- Content moderation implemented
- User reporting available
- User blocking available
- Terms of Service prohibit inappropriate content
- Account actions for violations

✅ **1.2 User Generated Content**
- Terms of Service cover user content
- Content moderation policies clear
- Reporting mechanisms in place
- Host controls available

✅ **2.1 Performance - App Completeness**
- All features functional
- No placeholder content
- Complete implementation

✅ **5.1.1 Privacy - Data Collection and Use**
- Privacy permissions clearly explained
- Privacy Policy updated
- Data handling transparent
- Third-party services disclosed

✅ **5.1.2 Privacy - Data Use and Sharing**
- Data use clearly stated
- Sharing with Agora disclosed
- User consent obtained
- No unexpected data sharing

## Support Information

- **Support Email**: ronellbradley@gmail.com
- **Privacy Policy**: https://faithjournal.app/privacy
- **Terms of Service**: https://faithjournal.app/terms
- **App Store ID**: 6746383133

## Additional Notes

- **Invitation-Only**: Sessions are not publicly accessible (requires invite code)
- **Authenticated Users**: All streaming requires user authentication (Sign in with Apple)
- **Content Safety**: Multiple layers of moderation (automated filtering, user reporting, host controls)
- **User Control**: Users can block, report, and leave sessions at any time
- **Industry Standard**: Uses Agora SDK (widely used, App Store approved SDK)

## Questions?

If reviewers have questions about:
- **Live Streaming Implementation**: Uses Agora RTC SDK, industry-standard solution
- **Content Moderation**: Multiple layers (filtering, reporting, blocking, host controls)
- **Privacy**: All data handling disclosed in Privacy Policy
- **Safety**: Comprehensive user safety features implemented

Please contact: ronellbradley@gmail.com
