# Content Moderation Policy for Live Streaming

## Overview

Faith Journal implements comprehensive content moderation and user safety features for live streaming sessions to ensure a positive, respectful, and safe environment for all users.

## Content Moderation Features

### 1. **Automated Filtering**

The app includes keyword filtering to automatically flag potentially inappropriate content:

- **Filtered Keywords**: Spam, advertisements, promotional content, inappropriate language
- **Real-time Filtering**: Messages containing filtered keywords are flagged automatically
- **Customizable Filters**: Hosts can add custom keywords to their session filters

**Implementation**: `StreamModerationService.swift` - `shouldFilterMessage()` method

### 2. **User Reporting System**

Users can report inappropriate content or behavior:

- **Report Messages**: Users can report specific messages with reasons
- **Report Reasons**: Inappropriate content, harassment, spam, etc.
- **Report Tracking**: All reports are tracked with timestamps and status
- **Review Process**: Reports are reviewed and appropriate action is taken

**Implementation**: `StreamModerationService.swift` - `reportMessage()` method

### 3. **User Blocking**

Users can block other users who engage in inappropriate behavior:

- **Block Users**: Prevents blocked users from interacting with you
- **Auto-Mute**: Blocked users are automatically muted
- **Persistent Blocks**: Blocked users remain blocked across sessions
- **Unblock Option**: Users can unblock previously blocked users if desired

**Implementation**: `StreamModerationService.swift` - `blockUser()` method

### 4. **Host Controls**

Session hosts have enhanced moderation capabilities:

- **Remove Participants**: Hosts can remove participants from sessions
- **Mute Participants**: Hosts can mute participants' audio
- **Disable Video**: Hosts can disable participants' video
- **End Sessions**: Hosts can end sessions at any time

## User Safety Features

### 1. **Reporting Mechanisms**

**In-App Reporting:**
- Users can report inappropriate messages, behavior, or users
- Reports include: message content, user information, reason for report, timestamp
- Reports are reviewed and action is taken

**Contact Support:**
- Users can contact support directly through the app
- Support email: ronellbradley@gmail.com
- Support can investigate and take action on reports

### 2. **Privacy Controls**

- **Session Invitations**: Sessions require invitation codes (not public)
- **Participant Control**: Users control who can join their sessions
- **Block Users**: Users can block problematic users
- **Leave Sessions**: Users can leave sessions at any time

### 3. **Content Guidelines**

Users are required to follow content guidelines:

**Prohibited Content:**
- Inappropriate or offensive language
- Harassment, bullying, or threats
- Spam or promotional content
- Illegal activities
- Content that violates others' privacy or rights

**Consequences:**
- First offense: Warning and content removal
- Repeated offenses: Temporary suspension
- Serious violations: Permanent account termination

## Technical Implementation

### Services

1. **StreamModerationService** (`StreamModerationService.swift`)
   - Manages blocked users list
   - Manages muted users list
   - Handles keyword filtering
   - Processes user reports
   - Tracks moderation actions

2. **Session Management**
   - Session hosts have moderation controls
   - Invitation-only access prevents public abuse
   - Participant management capabilities

### Data Handling

- **Reports**: Stored locally and can be sent to support
- **Blocked Users**: Stored locally per user
- **Content**: Filtered in real-time before display
- **Logs**: Moderation actions are logged for review

## App Store Compliance

This content moderation policy ensures compliance with App Store guidelines:

- ✅ **Safety**: Users can report and block inappropriate behavior
- ✅ **Content Moderation**: Automated filtering and manual review
- ✅ **User Controls**: Users have tools to protect themselves
- ✅ **Transparency**: Clear guidelines and consequences
- ✅ **Accountability**: Reports are tracked and reviewed

## For App Store Review

**Content Moderation Approach:**
1. **Preventive**: Invitation-only sessions, keyword filtering
2. **Reactive**: User reporting, host controls, blocking
3. **Enforcement**: Account suspension/termination for violations

**User Safety Measures:**
1. **Reporting**: In-app reporting system for inappropriate content
2. **Blocking**: Users can block problematic users
3. **Host Controls**: Session hosts can remove/mute participants
4. **Support**: Direct support contact for serious issues

**Transparency:**
- Terms of Service clearly state live streaming rules
- Privacy Policy explains data handling
- In-app reporting and blocking features are visible
- Clear consequences for violations

## Contact

For questions or concerns about content moderation:
- In-App Support: Settings → Contact Support
- Email: ronellbradley@gmail.com
- Reports: Use in-app reporting feature
