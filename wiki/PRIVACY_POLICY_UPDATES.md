# Privacy Policy Updates Needed for Live Streaming

## Required Privacy Policy Additions

Since you've added live streaming features, your privacy policy (`https://faithjournal.app/privacy`) should be updated to include:

### 1. Live Streaming Data Collection

Add a section explaining:

```
Live Streaming
When you use our live streaming features:
- We collect audio and video data from your device's camera and microphone
- Video and audio streams are transmitted using Agora SDK services
- Stream data is processed in real-time and not permanently stored
- Other participants in your session can see/hear your stream
```

### 2. Third-Party Services

Update the "Third-Party Services" section to include:

```
- Agora RTC SDK (for live streaming infrastructure)
  - Privacy Policy: https://www.agora.io/en/privacy-policy/
  - Agora processes video/audio streams during active sessions
```

### 3. User-Generated Content

Add section about live streaming content:

```
Live Streaming Content
- Chat messages sent during live sessions are stored as part of your account
- Video/audio streams are transmitted in real-time and not permanently recorded by us
- You are responsible for the content you share in live streams
- Other participants may record streams (we cannot prevent this)
```

### 4. Data Sharing

Clarify how streaming data is shared:

```
Data Sharing During Live Sessions
- Your video/audio is shared with other participants in your session
- Stream data is routed through Agora's infrastructure
- We do not record or store video/audio streams permanently
```

## Terms of Service Updates

Your Terms of Service (`https://faithjournal.app/terms`) should include:

### 1. Acceptable Use for Live Streaming

```
Live Streaming Rules
- You may not share inappropriate, offensive, or illegal content
- You must respect other participants' privacy and rights
- Harassment or abusive behavior is prohibited
- You are responsible for all content you share in streams
```

### 2. Session Invitations

```
Session Invitations
- Invitation codes are intended for specific sessions
- Do not share invitation codes publicly or with unauthorized users
- Report any misuse of invitation codes
```

## App Store Privacy Questionnaire

In App Store Connect → App Privacy, you'll need to declare:

### Data Types:
- ✅ **Audio Data** - Used for live streaming
- ✅ **Video Data** - Used for live streaming  
- ✅ **User Content** - Chat messages during streams

### Purposes:
- ✅ **App Functionality** - Required for live streaming feature
- ✅ **Analytics** (if you track stream analytics)

### Third-Party Partners:
- ✅ **Agora** - For live streaming infrastructure
- ✅ **Firebase** - For data synchronization

## Compliance Notes

- **GDPR**: Live streaming data is processed in real-time and not permanently stored
- **COPPA**: Ensure users are 13+ (already stated in your privacy policy)
- **CCPA**: Transparent about data sharing with Agora
