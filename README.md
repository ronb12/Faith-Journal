# Faith Journal - iOS App

<div align="center">

**A comprehensive spiritual journaling app for iOS that helps users deepen their faith journey through journaling, prayer tracking, Bible study, and community features.**

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://developer.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-green.svg)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-Personal-lightgrey.svg)](LICENSE)

</div>

## 📱 Overview

Faith Journal is a feature-rich iOS application designed to help believers document their spiritual journey, track prayers, study scripture, and connect with a faith community. Built with modern SwiftUI and SwiftData, the app provides a beautiful, intuitive interface for daily spiritual practices.

## ✨ Features

### 📖 Core Features

- **📝 Journal Entries**: Create, edit, and organize spiritual reflections with rich text formatting
- **🙏 Prayer Requests**: Track prayer requests with status updates (Active, Answered, Archived)
- **📜 Bible Verse of the Day**: Daily inspirational verses with refresh functionality
- **💝 Devotionals**: 50+ curated devotional content across multiple categories
- **😊 Mood Tracking**: Monitor spiritual and emotional well-being with intensity ratings
- **📎 Media Attachments**: Add photos, audio recordings, and drawings to entries
- **✏️ Apple Pencil Support**: Full drawing support with PencilKit integration

### 🎨 Personalization

- **🎨 9 Color Themes**: Default, Sunset, Ocean, Forest, Lavender, Golden, Midnight, Spring, and Pink
- **👤 User Profiles**: Personalized welcome messages and profile management
- **🔒 Privacy Controls**: Mark entries and prayers as private
- **🔐 Biometric Security**: Face ID/Touch ID authentication

### 📊 Analytics & Insights

- **📈 Statistics Dashboard**: Comprehensive analytics on journal entries, prayers, and mood trends
- **📉 Mood Analytics**: Visual charts and trends for emotional well-being tracking
- **🏷️ Tag Management**: Organize content with custom tags
- **🔍 Advanced Search**: Search by title, content, tags, dates, and more

### 👥 Community Features

- **🌐 Live Sessions**: Create and join real-time prayer and study sessions
- **💬 Chat System**: Text messaging within live sessions
- **📧 Invitation System**: Invite users via code, email, or shareable links
- **☁️ CloudKit Sync**: Multi-user support with CloudKit public database
- **📤 Community Sharing**: Share journal entries, prayers, and devotionals

### 🔧 Advanced Features

- **☁️ iCloud Sync**: Automatic data synchronization across all your devices
- **📤 Data Export**: Export all your data in a readable format
- **🔔 Daily Reminders**: Customizable notification reminders
- **📱 Universal App**: Optimized for iPhone and iPad
- **🌙 Dark Mode Support**: Beautiful appearance in light and dark modes

### 📋 Legal & Privacy

- **📄 Terms of Service**: Comprehensive terms and conditions
- **🔒 Privacy Policy**: Detailed privacy and data protection information
- **🛡️ Data Security**: Encrypted storage and secure authentication

## 🛠️ Technical Stack

- **Framework**: SwiftUI 5.0
- **Data Persistence**: SwiftData + CloudKit
- **Authentication**: LocalAuthentication (Face ID/Touch ID)
- **Media**: AVFoundation, PhotosUI, PencilKit
- **Charts**: Swift Charts
- **Networking**: CloudKit Public Database for multi-user features
- **UI**: Custom theme system with global color management

## 📁 Project Structure

```
Faith Journal/
├── Faith Journal/
│   ├── Models/              # SwiftData models
│   │   ├── JournalEntry.swift
│   │   ├── PrayerRequest.swift
│   │   ├── MoodEntry.swift
│   │   ├── LiveSession.swift
│   │   ├── UserProfile.swift
│   │   └── ...
│   ├── Views/                # SwiftUI views
│   │   ├── ContentView.swift
│   │   ├── JournalView.swift
│   │   ├── PrayerView.swift
│   │   ├── StatisticsView.swift
│   │   ├── MoodAnalyticsView.swift
│   │   ├── LiveSessionsView.swift
│   │   ├── SettingsView.swift
│   │   ├── TermsOfServiceView.swift
│   │   ├── PrivacyPolicyView.swift
│   │   └── ...
│   ├── Services/             # Business logic
│   │   ├── BibleVerseOfTheDayManager.swift
│   │   ├── DevotionalManager.swift
│   │   ├── CloudKitUserService.swift
│   │   └── CloudKitPublicSyncService.swift
│   ├── Utils/               # Utilities
│   │   └── ThemeManager.swift
│   └── Resources/           # Assets and resources
│       └── Assets.xcassets/
├── scripts/                 # Helper scripts
│   ├── create_app_icons.py
│   ├── generate_screenshots.sh
│   └── ...
└── docs/                    # Documentation
    ├── FEATURE_ANALYSIS.md
    ├── LIVE_SESSIONS_EXPLAINED.md
    └── MULTI_USER_SETUP.md
```

## 🚀 Getting Started

### Prerequisites

- Xcode 15.0 or later
- iOS 17.0+ deployment target
- macOS 14.0+ for development
- Apple Developer account (for device testing and App Store distribution)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/ronb12/Faith-Journal.git
cd Faith-Journal
```

2. Open the project in Xcode:
```bash
open "Faith Journal/Faith Journal.xcodeproj"
```

3. Select your target device or simulator

4. Build and run (⌘R)

### Configuration

1. **CloudKit Setup**: 
   - Enable CloudKit in Xcode project settings
   - Configure CloudKit container in App Store Connect
   - See `MULTI_USER_SETUP.md` for detailed instructions

2. **App Icons**:
   - App icons are generated using `scripts/create_app_icons.py`
   - Icons feature praying hands design with "Faith Journal" text

3. **Screenshots**:
   - Use `scripts/generate_screenshots.sh` for App Store screenshots
   - See `scripts/README_SCREENSHOTS.md` for details

## 📱 App Screens

1. **Home**: Welcome screen with Bible verse of the day and today's devotional
2. **Journal**: Create and manage journal entries with media attachments
3. **Prayer**: Track prayer requests and answered prayers
4. **Devotionals**: Browse curated devotional content by category
5. **Statistics**: View analytics and insights on your spiritual journey
6. **Live**: Join or create live prayer and study sessions
7. **Settings**: Manage profile, themes, privacy, and app preferences

## 🔐 Privacy & Security

- **Biometric Authentication**: Secure your app with Face ID or Touch ID
- **Private Entries**: Mark journal entries and prayers as private
- **iCloud Encryption**: All data encrypted in transit and at rest
- **Local Storage**: Data stored securely on device
- **Privacy Policy**: Comprehensive privacy information available in-app

## 🌐 Multi-User Support

Faith Journal supports multiple independent users through CloudKit's public database:

- **Live Sessions**: Share sessions across different Apple IDs
- **Invitations**: Send invitations via code, email, or shareable links
- **Chat**: Real-time messaging within sessions
- **CloudKit Sync**: Automatic synchronization across devices

See `LIVE_SESSIONS_EXPLAINED.md` and `MULTI_USER_SETUP.md` for detailed information.

## 🎨 Themes

The app includes 9 beautiful color themes:

- **Default**: Classic purple and blue
- **Sunset**: Warm oranges and reds
- **Ocean**: Cool blues and teals
- **Forest**: Natural greens
- **Lavender**: Soft purples
- **Golden**: Rich yellows and golds
- **Midnight**: Dark mode optimized
- **Spring**: Fresh pinks and greens
- **Pink**: Vibrant pink tones

All themes apply globally across the entire app interface.

## 📊 Development Status

### ✅ Fully Implemented

- Core journaling functionality
- Prayer request tracking
- Bible verse integration
- Devotional content (50+ devotionals)
- Theme system (9 themes)
- Search and filtering
- Privacy features
- Cloud sync (iCloud)
- Live sessions with multi-user support
- Media attachments (photos, audio, drawings)
- Analytics and statistics
- Mood tracking and analytics
- User profiles
- Terms of Service and Privacy Policy
- Invitation system
- Community sharing

### 🔄 In Progress

- Enhanced live session features
- Additional devotional content
- Performance optimizations

## 📝 Documentation

- **FEATURE_ANALYSIS.md**: Comprehensive feature analysis and status
- **LIVE_SESSIONS_EXPLAINED.md**: Detailed explanation of live sessions architecture
- **MULTI_USER_SETUP.md**: Setup guide for multi-user features
- **scripts/README_SCREENSHOTS.md**: Screenshot generation guide

## 🤝 Contributing

This is a personal project for spiritual development. Contributions and suggestions are welcome!

## 📄 License

This project is for personal use and spiritual development. 

## 👨‍💻 Author

**Bradley Virtual Solutions, LLC**

- GitHub: [@ronb12](https://github.com/ronb12)
- Repository: [Faith-Journal](https://github.com/ronb12/Faith-Journal)

## 🙏 Acknowledgments

- Built with love for the faith community
- Inspired by the need for better spiritual journaling tools
- Powered by Apple's SwiftUI and SwiftData frameworks

## 📞 Support

For support, feature requests, or questions:
- Open an issue on GitHub
- Contact through App Store Connect (when published)

---

<div align="center">

**Made with ❤️ for the faith community**

⭐ Star this repo if you find it helpful!

</div>
