# Installation Guide

This guide will help you set up the Faith Journal project on your development machine.

## Prerequisites

Before you begin, ensure you have the following installed:

- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 16.2 or later
- **iOS SDK**: 17.0 or later
- **Swift**: 5.0 or later
- **Git**: For version control
- **Apple Developer Account**: For device testing and App Store distribution

## Step 1: Clone the Repository

```bash
git clone https://github.com/ronb12/Faith-Journal.git
cd Faith-Journal
```

## Step 2: Open the Project

1. Navigate to the project directory
2. Open `Faith Journal/Faith Journal.xcodeproj` in Xcode
3. Wait for Xcode to index the project

## Step 3: Configure Signing & Capabilities

1. Select the **Faith Journal** target in Xcode
2. Go to **Signing & Capabilities** tab
3. Select your development team
4. Ensure the following capabilities are enabled:
   - **CloudKit**: For data synchronization
   - **Push Notifications**: For reminders and updates
   - **Background Modes**: For background sync

## Step 4: Configure CloudKit

1. In Xcode, go to **Signing & Capabilities**
2. Click **+ Capability** and add **CloudKit**
3. Ensure the CloudKit container is configured: `iCloud.com.ronellbradley.FaithJournal`
4. The entitlements file should be automatically configured

## Step 5: Build the Project

1. Select a simulator or connected device
2. Press `Cmd + B` to build the project
3. Resolve any build errors (see [Troubleshooting](Development/Troubleshooting.md))

## Step 6: Run the App

1. Press `Cmd + R` to run the app
2. The app should launch on the selected simulator or device

## Common Issues

### Build Errors

If you encounter build errors:

1. **Clean Build Folder**: `Product > Clean Build Folder` (Shift + Cmd + K)
2. **Delete Derived Data**: 
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
3. **Reset Package Dependencies**: In Xcode, go to `File > Packages > Reset Package Caches`

### CloudKit Errors

If CloudKit setup fails:

1. Verify your Apple Developer account has CloudKit enabled
2. Check that the bundle identifier matches your App ID
3. Ensure the CloudKit container is created in App Store Connect

### Simulator Issues

If the simulator doesn't launch:

1. Reset the simulator: `Device > Erase All Content and Settings`
2. Restart Xcode
3. Try a different simulator

## Next Steps

- Read the [Project Setup](Project-Setup.md) guide
- Review the [Architecture](Architecture.md) documentation
- Check out [Development Environment](Development-Environment.md) for IDE configuration

## Getting Help

If you encounter issues not covered here:

1. Check the [Troubleshooting](Development/Troubleshooting.md) guide
2. Search existing [GitHub Issues](https://github.com/ronb12/Faith-Journal/issues)
3. Create a new issue with detailed information about your problem

