#!/bin/bash

# Crash Test Script for Faith Journal App
# Tests critical paths that could cause crashes

echo "🔍 Starting Crash Test for Faith Journal App..."
echo ""

APP_BUNDLE="com.ronellbradley.FaithJournal"
SIMULATOR_ID=$(xcrun simctl list devices booted | grep -o '[A-F0-9-]\{36\}' | head -1)

if [ -z "$SIMULATOR_ID" ]; then
    echo "❌ No booted simulator found. Please boot a simulator first."
    exit 1
fi

echo "📱 Testing on Simulator: $SIMULATOR_ID"
echo ""

# Test 1: App Launch
echo "Test 1: App Launch..."
xcrun simctl launch "$SIMULATOR_ID" "$APP_BUNDLE" 2>&1
LAUNCH_EXIT=$?

if [ $LAUNCH_EXIT -eq 0 ]; then
    echo "✅ App launched successfully"
else
    echo "❌ App launch failed with exit code: $LAUNCH_EXIT"
fi

sleep 3

# Test 2: Check for crash logs
echo ""
echo "Test 2: Checking for crash logs..."
CRASH_LOGS=$(xcrun simctl spawn booted log show --predicate 'eventMessage contains "crash" OR eventMessage contains "exception" OR eventMessage contains "fatal"' --last 5m 2>&1 | grep -i "Faith Journal" || echo "No crash logs found")

if [ -n "$CRASH_LOGS" ] && [ "$CRASH_LOGS" != "No crash logs found" ]; then
    echo "⚠️ Potential crash detected:"
    echo "$CRASH_LOGS" | head -10
else
    echo "✅ No crash logs found"
fi

# Test 3: Check for fatal errors in console
echo ""
echo "Test 3: Checking console for fatal errors..."
CONSOLE_ERRORS=$(xcrun simctl spawn booted log stream --predicate 'processImagePath contains "Faith Journal" AND (eventMessage contains "fatal" OR eventMessage contains "FATAL" OR eventMessage contains "CRITICAL")' --level error --style compact --timeout 2 2>&1 || echo "No fatal errors")

if [ -n "$CONSOLE_ERRORS" ] && [ "$CONSOLE_ERRORS" != "No fatal errors" ]; then
    echo "⚠️ Fatal errors detected:"
    echo "$CONSOLE_ERRORS" | head -10
else
    echo "✅ No fatal errors in console"
fi

# Test 4: Check ModelContainer initialization
echo ""
echo "Test 4: Checking ModelContainer initialization..."
MODEL_ERRORS=$(xcrun simctl spawn booted log stream --predicate 'processImagePath contains "Faith Journal" AND (eventMessage contains "ModelContainer" OR eventMessage contains "SwiftData")' --level error --style compact --timeout 2 2>&1 || echo "No ModelContainer errors")

if [ -n "$MODEL_ERRORS" ] && [ "$MODEL_ERRORS" != "No ModelContainer errors" ]; then
    echo "⚠️ ModelContainer errors detected:"
    echo "$MODEL_ERRORS" | head -10
else
    echo "✅ No ModelContainer errors"
fi

# Test 5: Check app process status
echo ""
echo "Test 5: Checking app process status..."
sleep 2
PROCESS_STATUS=$(xcrun simctl spawn booted ps aux | grep "Faith Journal" | grep -v grep || echo "Process not running")

if [ "$PROCESS_STATUS" != "Process not running" ]; then
    echo "✅ App process is running"
else
    echo "❌ App process is not running (may have crashed)"
fi

echo ""
echo "🏁 Crash test completed!"
echo ""
echo "📋 Summary:"
echo "- App Launch: $([ $LAUNCH_EXIT -eq 0 ] && echo "✅ PASS" || echo "❌ FAIL")"
echo "- Crash Logs: $([ "$CRASH_LOGS" = "No crash logs found" ] && echo "✅ PASS" || echo "⚠️ CHECK")"
echo "- Fatal Errors: $([ "$CONSOLE_ERRORS" = "No fatal errors" ] && echo "✅ PASS" || echo "⚠️ CHECK")"
echo "- ModelContainer: $([ "$MODEL_ERRORS" = "No ModelContainer errors" ] && echo "✅ PASS" || echo "⚠️ CHECK")"
echo "- Process Status: $([ "$PROCESS_STATUS" != "Process not running" ] && echo "✅ PASS" || echo "❌ FAIL")"

