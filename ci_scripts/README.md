# Xcode Cloud CI Scripts

This directory contains scripts for Xcode Cloud continuous integration.

## Scripts

### `ci_pre_xcodebuild.sh`
Runs before Xcode builds your project. This script:
- Verifies required tools are available
- Checks project structure
- Prints environment information
- Validates Swift and Xcode versions

### `ci_post_xcodebuild.sh`
Runs after Xcode builds your project. This script:
- Verifies build artifacts were created
- Prints build summary information
- Checks archive path

## Xcode Cloud Configuration

To use Xcode Cloud with this project:

1. **Enable Xcode Cloud** in App Store Connect
2. **Create a Workflow** in Xcode:
   - Open the project in Xcode
   - Go to Product > Xcode Cloud > Create Workflow
   - Select the repository and branch
   - Configure build settings

3. **Required Settings**:
   - Scheme: "Faith Journal"
   - Configuration: Release
   - Destination: iOS Simulator or Generic iOS Device

## Environment Variables

Xcode Cloud provides these environment variables:
- `CI`: Set to "true" when running in Xcode Cloud
- `XCODE_CLOUD`: Set to "true" in Xcode Cloud
- `CI_BUILD_NUMBER`: Build number
- `CI_WORKSPACE`: Workspace path
- `CI_ARCHIVE_PATH`: Archive output path
- `CI_DERIVED_DATA_PATH`: Derived data path
- `CI_XCODE_SCHEME`: Selected scheme
- `CI_XCODEBUILD_CONFIGURATION`: Build configuration

## Troubleshooting

If builds fail in Xcode Cloud:

1. **Check Script Permissions**: Ensure scripts are executable (`chmod +x`)
2. **Verify Project Structure**: Ensure all files are in the correct locations
3. **Check Build Settings**: Verify code signing and provisioning profiles
4. **Review Logs**: Check Xcode Cloud build logs for specific errors

## Notes

- Scripts use `set -e` to exit on any error
- All paths should be relative to the repository root
- Scripts are automatically executed by Xcode Cloud

