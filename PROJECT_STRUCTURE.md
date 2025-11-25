# Faith Journal - Project Structure

This document describes the professional organization of the Faith Journal project repository.

## 📁 Root Directory

The root directory contains only essential project files:

- **README.md** - Main project documentation and getting started guide
- **Package.swift** - Swift package configuration
- **.gitignore** - Git ignore rules for iOS/Xcode projects
- **.xcode-version** - Xcode version specification

### Main Directories

```
Faith Journal/
├── Faith Journal/          # Main iOS app project (Xcode project)
├── Sources/                # Additional Swift source files
├── Tests/                  # Unit tests
├── UITests/                # UI tests
├── docs/                   # Project documentation (organized by category)
├── scripts/                # Build and utility scripts
├── assets/                 # Project assets (icons, images)
├── wiki/                   # Comprehensive project wiki
├── ci_scripts/             # CI/CD scripts
└── webhook/                # Webhook configurations
```

## 📚 Documentation Structure (`docs/`)

All documentation is organized into logical categories:

### `docs/app-store/`
App Store Connect submission and management documentation:
- Submission guides and checklists
- App Store metadata (descriptions, keywords, promotional text)
- Review documentation
- Compliance & legal documents (privacy policy, content rights)
- Accessibility and age rating information

### `docs/development/`
Developer guides and setup documentation:
- Build and installation instructions
- Feature implementation guides
- Testing guides (iPad, simulator)
- API key configuration
- Screenshot and icon setup

### `docs/fixes/`
Bug fixes and troubleshooting documentation:
- View and UI fixes
- Drawing and journal fixes
- System compatibility fixes
- Asset and build fixes

## 🛠️ Scripts (`scripts/`)

All utility and build scripts are organized in the `scripts/` directory:
- Build scripts
- Screenshot automation
- Icon generation
- Cleanup utilities
- Helper scripts

## 🎨 Assets (`assets/`)

Project assets are organized in the `assets/` directory:
- `assets/icons/` - App icon files and variations

## 📖 Wiki (`wiki/`)

Comprehensive project wiki with detailed technical documentation:
- Architecture documentation
- API documentation
- Data models
- Feature documentation
- Contributing guidelines

## ✅ Best Practices

1. **Keep root directory clean** - Only essential project files at root
2. **Organize by purpose** - Group related files in appropriate directories
3. **Documentation in docs/** - All documentation categorized in docs/
4. **Scripts in scripts/** - All utility scripts in scripts/
5. **Assets in assets/** - All project assets in assets/

## 🔄 Maintenance

When adding new files:
- **Documentation** → `docs/` (categorize appropriately)
- **Scripts** → `scripts/`
- **Assets** → `assets/`
- **Tests** → `Tests/` or `UITests/`

---

*Last updated: November 2024*

