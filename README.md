# Faith Journal

A comprehensive iOS application designed to help users deepen their spiritual journey through journaling, prayer tracking, Bible study, and community engagement.

## 📱 Features

- **Personal Journaling**: Create, organize, and search through journal entries with rich media support
- **Prayer Management**: Track prayer requests, mark answers, and maintain a prayer journal
- **Bible Study**: Access daily verses, devotionals, and Bible study topics
- **Live Sessions**: Join or host live faith-based sessions with other users
- **Mood Tracking**: Track emotional states and spiritual growth over time
- **Reading Plans**: Follow structured Bible reading plans
- **Cloud Sync**: Seamless data synchronization across devices using CloudKit

## 🚀 Getting Started

### Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 16.2 or later
- iOS SDK 17.0 or later
- Swift 5.0 or later
- Apple Developer Account

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

3. Configure signing and capabilities in Xcode
4. Build and run the project

For detailed setup instructions, see the [Installation Guide](wiki/Installation-Guide.md).

## 📚 Documentation

### Quick Links
- **[Documentation Index](docs/README.md)** - Browse all documentation by category
- **[Wiki](wiki/README.md)** - Comprehensive project wiki with architecture details

### Documentation Categories

**App Store Submission** (`docs/app-store/`)
- App Store Connect setup guides
- Submission checklists and review notes
- Privacy policy and content rights

**Development Guides** (`docs/development/`)
- Build instructions and setup
- Feature implementation guides
- Testing and debugging guides
- API key configuration

**Fixes & Troubleshooting** (`docs/fixes/`)
- Bug fix documentation
- Issue resolution guides
- Compatibility fixes

**Project Wiki** (`wiki/`)
- [Installation Guide](wiki/Installation-Guide.md)
- [Architecture](wiki/Architecture.md)
- [Data Models](wiki/Data-Models.md)
- [Features Documentation](wiki/Features/)
- [API Documentation](wiki/API/)
- [Development Guides](wiki/Development/)
- [Contributing Guidelines](wiki/Contributing.md)

## 🏗️ Architecture

Faith Journal follows a **MVVM (Model-View-ViewModel)** architecture pattern with SwiftUI, leveraging SwiftData for data persistence and CloudKit for cloud synchronization.

### Key Technologies

- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Data persistence framework
- **CloudKit**: Cloud synchronization
- **PencilKit**: Drawing support
- **AVFoundation**: Audio recording

## 📖 Project Structure

```
Faith Journal/
├── Faith Journal/              # Main iOS app project
│   ├── Models/                 # SwiftData models
│   ├── Views/                  # SwiftUI views
│   ├── Services/               # Business logic services
│   └── Utils/                  # Utility classes
├── Faith JournalTests/          # Unit tests
├── Faith JournalUITests/        # UI tests
├── docs/                       # Project documentation
│   ├── app-store/              # App Store submission docs
│   ├── development/            # Development guides
│   └── fixes/                  # Bug fixes and troubleshooting
├── scripts/                    # Build and utility scripts
├── assets/                     # Project assets (icons, images)
│   └── icons/                  # App icon files
├── wiki/                       # Comprehensive project wiki
└── Sources/                    # Additional Swift source files
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](wiki/Contributing.md) for details.

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

This project is licensed under the terms specified in the repository.

## 🔗 Links

- **Repository**: [GitHub](https://github.com/ronb12/Faith-Journal)
- **Wiki**: [Documentation](wiki/README.md)
- **Issues**: [Report Issues](https://github.com/ronb12/Faith-Journal/issues)

## 🙏 Acknowledgments

Thank you to all contributors and users of Faith Journal!

---

*Built with ❤️ for the faith community*

