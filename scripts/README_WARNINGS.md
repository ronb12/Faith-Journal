# Xcode Warnings Checker & Fixer

This script automatically checks for Xcode warnings and can fix common warning patterns.

## Usage

### Check for warnings only:
```bash
./scripts/check_and_fix_warnings.sh
```

### Check and automatically fix warnings:
```bash
./scripts/check_and_fix_warnings.sh --fix
```

### Strict mode (exit with error if warnings found):
```bash
./scripts/check_and_fix_warnings.sh --strict
```

### Combine options:
```bash
./scripts/check_and_fix_warnings.sh --fix --strict
```

## What it fixes

The script automatically fixes these common warning patterns:

1. **Unused variables**: Replaces `let variable = ...` with `let _ = ...`
2. **Unused guard variables**: Replaces `guard let variable = ...` with `guard let _ = ...`
3. **Deprecated string interpolation**: Replaces `Text("\(value)")` with `Text(String(describing: value))`
4. **Unused guard bindings**: Replaces `guard let var = expr else` with `guard expr != nil else`
5. **Unused if-let bindings**: Replaces `if let var = expr` with `if (expr) != nil`

## Integration with Xcode Cloud

To use this script in Xcode Cloud, add it to your `ci_scripts/ci_post_xcodebuild.sh`:

```bash
#!/bin/bash

# Check and fix warnings after build
if [ -f "scripts/check_and_fix_warnings.sh" ]; then
    chmod +x scripts/check_and_fix_warnings.sh
    ./scripts/check_and_fix_warnings.sh --fix
fi
```

Or add it as a pre-commit hook to catch warnings before pushing:

```bash
#!/bin/bash
# .git/hooks/pre-commit

./scripts/check_and_fix_warnings.sh --strict
```

## Examples

### Example 1: Unused variable warning
**Before:**
```swift
let createdAt = record["createdAt"] as? Date ?? startTime
```

**After:**
```swift
let _ = record["createdAt"] as? Date ?? startTime
```

### Example 2: Deprecated string interpolation
**Before:**
```swift
Text("\(value)")
```

**After:**
```swift
Text(String(describing: value))
```

### Example 3: Unused guard binding
**Before:**
```swift
guard let sessionId = UUID(uuidString: record.recordID.recordName) else {
    return nil
}
```

**After:**
```swift
guard UUID(uuidString: record.recordID.recordName) != nil else {
    return nil
}
```

## Notes

- The script makes backup copies before modifying files (via sed -i '')
- Always review changes before committing
- Some warnings may require manual fixes
- The script focuses on common Swift/Xcode warning patterns

