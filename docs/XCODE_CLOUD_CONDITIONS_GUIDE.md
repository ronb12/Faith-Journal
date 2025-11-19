# How to Add Conditions in Xcode Cloud

This guide shows you exactly how to add conditions to your Xcode Cloud workflow for TestFlight distribution.

## Step-by-Step: Adding Conditions

### Step 1: Access Xcode Cloud Workflows

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Sign in with your Apple Developer account
3. Click **My Apps**
4. Select **Faith Journal** (or your app)
5. Click the **Xcode Cloud** tab (or **TestFlight** > **Xcode Cloud**)

### Step 2: Create or Edit a Workflow

**If you don't have a workflow yet:**
1. Click **Create Workflow** or **Get Started**
2. Follow the setup wizard:
   - Connect your GitHub repository: `ronb12/Faith-Journal`
   - Select branch: `main`
   - Choose scheme: **Faith Journal**
   - Select configuration: **Release**

**If you already have a workflow:**
1. Find your workflow in the list
2. Click on it to open
3. Click **Edit Workflow** (pencil icon)

### Step 3: Add the Distribute Action

1. In the workflow editor, you'll see your current actions (usually just "Build")
2. Click **+ Add Action** or the **+** button
3. Select **Distribute** from the list
4. The Distribute action will appear in your workflow

### Step 4: Configure Distribution Settings

1. Click on the **Distribute** action you just added
2. A configuration panel will open on the right side
3. Configure basic settings:
   - **Destination**: Select **TestFlight**
   - **Automatic Distribution**: Toggle **ON** (enables automatic distribution)
   - **Beta Groups**: Select which TestFlight groups to distribute to
   - **What to Distribute**: Select **Archive**

### Step 5: Add Conditions

This is the key part! In the Distribute action configuration:

1. Look for the **Conditions** section (usually at the bottom of the configuration panel)
2. Click **+ Add Condition** or the **Conditions** dropdown
3. You'll see options like:
   - **Skip if**: Conditions that prevent distribution
   - **Only distribute if**: Conditions that must be met

### Step 6: Configure Specific Conditions

#### Option A: Skip if Errors Exist (Recommended)

1. Click **+ Add Condition**
2. Select **Skip if**
3. Choose **Build Status**
4. Select **Has Errors**
5. This will skip distribution if the build has any errors

#### Option B: Only Distribute if Build Succeeds

1. Click **+ Add Condition**
2. Select **Only distribute if**
3. Choose **Build Status**
4. Select **Succeeded**
5. This ensures distribution only happens on successful builds

#### Option C: Skip if Warnings Exceed Threshold (Optional)

1. Click **+ Add Condition**
2. Select **Skip if**
3. Choose **Build Warnings**
4. Set threshold (e.g., **Greater than 0**)
5. ⚠️ **Note**: This is optional - warnings usually don't block distribution

### Step 7: Advanced Conditions (Optional)

You can also add conditions based on:

- **Branch**: Only distribute from specific branches (e.g., `main`, `release/*`)
- **Tag**: Only distribute when specific tags are present
- **Build Number**: Only distribute certain build numbers
- **Custom Script Result**: Use output from your CI scripts

**Example - Branch Condition:**
```
Only distribute if:
  Branch matches: main
```

**Example - Custom Script Result:**
```
Only distribute if:
  Script output contains: "✅ Ready for distribution"
```

### Step 8: Save Your Workflow

1. Review all your conditions
2. Click **Save** or **Done** in the top right
3. Xcode Cloud will validate your workflow
4. If valid, the workflow is saved

## Visual Guide: What You'll See

```
Workflow Editor:
┌─────────────────────────────────────┐
│  Workflow: Faith Journal            │
├─────────────────────────────────────┤
│  [Build]                            │
│    ↓                                │
│  [Distribute] ← Click to configure  │
│    • Destination: TestFlight        │
│    • Automatic: ON                  │
│    • Conditions:                    │
│      ✓ Skip if: Has Errors          │
│      ✓ Only if: Build Succeeded     │
└─────────────────────────────────────┘
```

## Recommended Condition Setup

For automatic TestFlight distribution with quality checks, use:

```
Distribute Action:
  Destination: TestFlight
  Automatic: ON
  
  Conditions:
    ✅ Only distribute if: Build Status = Succeeded
    ✅ Skip if: Build Status = Has Errors
    ⚠️  (Optional) Skip if: Build Warnings > 0
```

## Testing Your Conditions

1. **Make a commit** that will trigger a build
2. **Push to GitHub** (to the branch your workflow monitors)
3. **Monitor the workflow** in Xcode Cloud:
   - Go to Xcode Cloud tab
   - Click on your workflow
   - Watch the build progress
4. **Check the results**:
   - If conditions are met → Distribution happens automatically
   - If conditions fail → Distribution is skipped (check logs)

## Troubleshooting

### Condition Not Working?

1. **Check build logs**: Look for "Skipping distribution" messages
2. **Verify condition syntax**: Make sure conditions are properly configured
3. **Check build status**: Ensure build actually succeeded
4. **Review script output**: If using custom conditions, check script output

### Distribution Happening When It Shouldn't?

1. **Review conditions**: Make sure "Skip if" conditions are set correctly
2. **Check build status**: Verify errors are being detected
3. **Test conditions**: Try a build with errors to verify it's skipped

### Distribution Not Happening?

1. **Check conditions**: Ensure "Only distribute if" conditions are met
2. **Verify build succeeded**: Check build logs for success status
3. **Check archive**: Ensure archive was created successfully
4. **Review TestFlight settings**: Verify TestFlight is properly configured

## Example: Complete Workflow Configuration

```
Workflow Name: Faith Journal - Main Branch
Repository: ronb12/Faith-Journal
Branch: main
Scheme: Faith Journal
Configuration: Release

Actions:
  1. Build
     - Configuration: Release
     - Destination: Generic iOS Device
     
  2. Distribute
     - Destination: TestFlight
     - Automatic: ON
     - Beta Groups: Internal Testers, External Testers
     - Conditions:
       • Only distribute if: Build Status = Succeeded
       • Skip if: Build Status = Has Errors
       • Skip if: Build Warnings > 10 (optional)
```

## Integration with Your Scripts

Your `auto_testflight_distribute.sh` script verifies conditions and reports status. The script output can be used in custom conditions:

**In Xcode Cloud Condition:**
```
Only distribute if:
  Script output contains: "✅ Conditions met for TestFlight distribution"
```

**In your script:**
```bash
# At the end of auto_testflight_distribute.sh
if [ "$ERROR_COUNT" -eq 0 ]; then
    echo "✅ Conditions met for TestFlight distribution"
    exit 0
else
    echo "❌ Conditions not met - errors found"
    exit 1
fi
```

## Quick Reference

| Condition Type | When to Use | Example |
|---------------|-------------|---------|
| **Skip if** | Prevent distribution | Skip if errors exist |
| **Only if** | Require condition | Only if build succeeded |
| **Branch** | Control by branch | Only from `main` branch |
| **Tag** | Control by tag | Only with `v*` tags |
| **Script** | Custom logic | Based on script output |

## Next Steps

1. ✅ Set up your workflow in Xcode Cloud
2. ✅ Add the Distribute action
3. ✅ Configure conditions (recommended: Skip if errors)
4. ✅ Save and test
5. ✅ Monitor first build to verify conditions work

## Need Help?

- Check Xcode Cloud documentation: https://developer.apple.com/documentation/xcode
- Review workflow logs in App Store Connect
- Test conditions with a small change first

