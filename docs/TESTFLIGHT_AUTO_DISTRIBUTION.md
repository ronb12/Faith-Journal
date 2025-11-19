# Automatic TestFlight Distribution Setup

This guide explains how to configure Xcode Cloud to automatically distribute builds to TestFlight when there are no errors or warnings.

## Current Setup

The project includes scripts that:
1. ✅ Check for warnings and errors
2. ✅ Automatically fix common warnings
3. ✅ Verify build is ready for distribution

However, **automatic TestFlight distribution must be configured in Xcode Cloud settings** - it's not handled by scripts alone.

## How to Enable Automatic TestFlight Distribution

### Step 1: Configure Xcode Cloud Workflow

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **My Apps** > Select your app
3. Go to **Xcode Cloud** tab
4. Select your workflow (or create a new one)
5. Click **Edit Workflow**

### Step 2: Add Distribution Action

1. In the workflow editor, click **+ Add Action**
2. Select **Distribute**
3. Configure the distribution:
   - **Destination**: TestFlight
   - **Automatic Distribution**: Enable
   - **Beta Groups**: Select which groups to distribute to
   - **What to Distribute**: Archive

### Step 3: Set Conditions (Optional)

You can configure conditions for distribution:
- **Only distribute if**: Build succeeds
- **Skip if**: Build has errors (default)
- **Skip if**: Build has warnings (optional - not recommended)

### Step 4: Save and Test

1. Click **Save** to save the workflow
2. Push a commit to trigger a build
3. Monitor the workflow in Xcode Cloud dashboard

## Current Script Behavior

The `auto_testflight_distribute.sh` script:
- ✅ Verifies no errors exist (blocks distribution if errors found)
- ✅ Checks warning count (warns but doesn't block)
- ✅ Verifies archive exists
- ✅ Reports readiness status

**Note**: The script doesn't actually push to TestFlight - it only verifies conditions. Xcode Cloud handles the actual distribution based on workflow configuration.

## Manual Distribution

If you prefer manual control:

1. Disable automatic distribution in workflow settings
2. After each build, manually distribute from:
   - App Store Connect > Xcode Cloud > Workflows > Select build > Distribute

## Troubleshooting

### Distribution Not Happening

1. **Check workflow configuration**: Ensure "Distribute" action is added
2. **Check conditions**: Verify no conditions are blocking distribution
3. **Check build status**: Build must succeed (no errors)
4. **Check archive**: Archive must be created successfully

### Distribution Happening Despite Warnings

- This is expected behavior - warnings don't block distribution by default
- To block on warnings, configure workflow condition: "Skip if warnings > 0"
- Or modify `auto_testflight_distribute.sh` to exit with error code when warnings exist

### Script Not Running

- Ensure script has execute permissions: `chmod +x scripts/auto_testflight_distribute.sh`
- Check `ci_post_xcodebuild.sh` includes the script call
- Verify script path is correct in Xcode Cloud

## Recommended Configuration

For automatic distribution with quality checks:

```
Workflow:
  - Build (required)
  - Test (optional but recommended)
  - Distribute:
      - Destination: TestFlight
      - Automatic: Yes
      - Conditions:
        - Build succeeds
        - No errors
        - (Optional) Warnings < threshold
```

## Example Workflow

1. Developer pushes code to `main` branch
2. Xcode Cloud triggers build
3. `ci_post_xcodebuild.sh` runs:
   - Checks for warnings
   - Fixes common warnings automatically
   - Verifies build is ready
4. If build succeeds:
   - Xcode Cloud distributes to TestFlight automatically
   - Testers receive notification
5. If build fails:
   - Distribution is skipped
   - Developer receives notification

## Summary

**To answer your question**: The scripts verify conditions (0 errors, 0 warnings), but **Xcode Cloud workflow settings** control whether distribution happens automatically. You need to:

1. ✅ Configure "Distribute" action in Xcode Cloud workflow
2. ✅ Enable automatic distribution
3. ✅ Set conditions (build succeeds, no errors)
4. ✅ Scripts will verify readiness and report status

The scripts ensure quality, but Xcode Cloud handles the actual TestFlight push.

