# Xcode Cloud Setup Guide

## ✅ Configuration Files Added

### 1. `.xcode-version`
Specifies the Xcode version (15.0) for Xcode Cloud builds.

### 2. `ci_scripts/` Directory
Contains CI scripts that run during Xcode Cloud builds:

- **`ci_pre_xcodebuild.sh`**: Runs before the build
  - Verifies required tools (Swift, xcodebuild)
  - Checks project structure
  - Validates environment

- **`ci_post_xcodebuild.sh`**: Runs after the build
  - Verifies build artifacts
  - Prints build summary
  - Checks archive path

### 3. `.github/workflows/xcode-cloud-check.yml`
GitHub Actions workflow to verify Xcode Cloud configuration on every push.

## 🔧 Xcode Cloud Setup Steps

### 1. Enable Xcode Cloud in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to your app
3. Go to **TestFlight** > **Xcode Cloud**
4. Click **Get Started** or **Create Workflow**

### 2. Create Workflow in Xcode

1. Open the project in Xcode
2. Go to **Product** > **Xcode Cloud** > **Create Workflow**
3. Select your repository: `ronb12/Faith-Journal`
4. Select branch: `main`
5. Configure the workflow:
   - **Scheme**: `Faith Journal`
   - **Configuration**: `Release`
   - **Destination**: `iOS Simulator` or `Generic iOS Device`

### 3. Configure Build Settings

In Xcode Cloud workflow settings:

- **Pre-actions**: Automatically runs `ci_scripts/ci_pre_xcodebuild.sh`
- **Post-actions**: Automatically runs `ci_scripts/ci_post_xcodebuild.sh`
- **Code Signing**: Configure with your Apple Developer account
- **Provisioning Profiles**: Set up for App Store distribution

## ⚠️ Common Issues and Solutions

### Issue: Build Fails with "Scheme Not Found"
**Solution**: Ensure the scheme "Faith Journal" is shared:
1. In Xcode: **Product** > **Scheme** > **Manage Schemes**
2. Check "Shared" for "Faith Journal"
3. Commit the scheme to git

### Issue: Code Signing Errors
**Solution**: 
1. Configure code signing in Xcode Cloud workflow
2. Add your Apple Developer team
3. Select appropriate provisioning profiles

### Issue: Missing Dependencies
**Solution**: 
- Ensure all dependencies are properly configured
- Check Swift Package Manager dependencies
- Verify all files are committed to git

### Issue: Script Execution Errors
**Solution**:
- Ensure scripts have execute permissions: `chmod +x ci_scripts/*.sh`
- Check script syntax: `bash -n ci_scripts/*.sh`
- Verify script paths are correct

## 📋 Checklist

Before using Xcode Cloud, verify:

- [x] `.xcode-version` file exists
- [x] `ci_scripts/` directory exists
- [x] CI scripts are executable
- [x] Scheme "Faith Journal" exists
- [x] Project builds locally
- [ ] Scheme is shared (check in Xcode)
- [ ] Code signing configured
- [ ] Provisioning profiles set up
- [ ] All dependencies committed

## 🔍 Verifying Configuration

Run these commands to verify:

```bash
# Check Xcode Cloud files
test -f .xcode-version && echo "✅ .xcode-version exists"
test -d ci_scripts && echo "✅ ci_scripts exists"
test -x ci_scripts/ci_pre_xcodebuild.sh && echo "✅ Pre-build script executable"
test -x ci_scripts/ci_post_xcodebuild.sh && echo "✅ Post-build script executable"

# Check scheme
xcodebuild -list -project "Faith Journal/Faith Journal.xcodeproj"
```

## 📚 Additional Resources

- [Xcode Cloud Documentation](https://developer.apple.com/documentation/xcode)
- [Xcode Cloud Workflow Guide](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)
- [CI Scripts Reference](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)

## 🆘 Support

If you encounter issues:

1. Check Xcode Cloud build logs in App Store Connect
2. Review script output in build logs
3. Verify all files are committed to git
4. Ensure project builds successfully locally
5. Check Xcode Cloud status page for service issues

