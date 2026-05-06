#!/bin/bash
# Setup LiveKit CLI and link your LiveKit Cloud project.
# See: https://docs.livekit.io/intro/basics/cli/

set -e

echo "LiveKit CLI setup"
echo "=================="
echo ""

# 1. Install LiveKit CLI (macOS)
if ! command -v lk &>/dev/null; then
    echo "Installing LiveKit CLI..."
    if command -v brew &>/dev/null; then
        brew install livekit-cli
    else
        echo "Homebrew not found. Install the CLI manually:"
        echo "  macOS: brew install livekit-cli"
        echo "  Or: https://github.com/livekit/livekit-cli/releases"
        exit 1
    fi
else
    echo "LiveKit CLI already installed: $(lk version 2>/dev/null || lk --version 2>/dev/null || true)"
fi

echo ""

# 2. Link LiveKit Cloud project (opens browser to sign in)
echo "Linking your LiveKit Cloud project (browser will open)..."
lk cloud auth

echo ""
echo "Done. You can now:"
echo "  • Create a test token:  lk token create --join --room test_room --identity cli_user --valid-for 1h"
echo "  • List rooms:           lk room list"
echo "  • Use your project from the Faith Journal app (server URL and API key are already in StreamingConfig)."
echo ""
echo "For the app, set your API Secret via environment variable (do not commit it):"
echo "  export LIVEKIT_API_SECRET=\"your_secret_from_cloud.livekit.io\""
echo ""
