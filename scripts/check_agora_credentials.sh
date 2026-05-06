#!/usr/bin/env bash
# Check that Agora credentials match between the app and token-server.
# Run from repo root: ./scripts/check_agora_credentials.sh
# To verify against Agora Console: https://console.agora.io/ → Project Management → your project → App ID

set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_ID_EXPECTED="89fdd88c9b594cf0947a48a8730e5f62"

echo "=== Agora credentials check ==="
echo ""

# 1) App ID in Swift app (primary AgoraService used by the app)
echo "1. App (Swift)"
APP_ID_APP=""
if [ -f "Services/AgoraService.swift" ]; then
  APP_ID_APP=$(grep -E 'appId\s*=\s*"[a-f0-9]{32}"|return\s+"[a-f0-9]{32}"' Services/AgoraService.swift | head -1 | sed -n 's/.*"\([a-f0-9]\{32\}\)".*/\1/p')
fi
if [ -z "$APP_ID_APP" ]; then
  APP_ID_APP=$(grep -rhE 'appId\s*=\s*"[a-f0-9]{32}"|return\s+"[a-f0-9]{32}"' --include="*.swift" Services 2>/dev/null | head -1 | sed -n 's/.*"\([a-f0-9]\{32\}\)".*/\1/p')
fi
if [ -n "$APP_ID_APP" ]; then
  echo "   App ID: $APP_ID_APP"
else
  echo "   App ID: (not found in Services/AgoraService.swift)"
  APP_ID_APP="$APP_ID_EXPECTED"
fi
echo ""

# 2) Token server (.env or server default)
echo "2. Token server (token-server/)"
APP_ID_TOKEN=""
if [ -f "token-server/.env" ]; then
  APP_ID_TOKEN=$(grep -E '^AGORA_APP_ID=' token-server/.env 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d "'")
fi
if [ -z "$APP_ID_TOKEN" ]; then
  APP_ID_TOKEN=$(grep -E "AGORA_APP_ID|'[a-f0-9]{32}'" token-server/server.js 2>/dev/null | head -1 | sed -n "s/.*['\"]\\([a-f0-9]\\{32\\}\\)['\"].*/\\1/p")
fi
if [ -n "$APP_ID_TOKEN" ]; then
  echo "   App ID: $APP_ID_TOKEN"
  if [ -f "token-server/.env" ]; then
    HAS_CERT=$(grep -E '^AGORA_APP_CERTIFICATE=' token-server/.env 2>/dev/null | cut -d= -f2-)
    if [ -z "$HAS_CERT" ] || [ "$HAS_CERT" = "YOUR_APP_CERTIFICATE_HERE" ]; then
      echo "   App Certificate: not set (token server may fail in production)"
    else
      echo "   App Certificate: set"
    fi
  fi
else
  echo "   App ID: (not found; using server default)"
  APP_ID_TOKEN="$APP_ID_EXPECTED"
fi
echo ""

# 3) Compare
echo "3. Match"
if [ "$APP_ID_APP" = "$APP_ID_TOKEN" ]; then
  echo "   App and token-server App IDs match."
  if [ "$APP_ID_APP" = "$APP_ID_EXPECTED" ]; then
    echo "   Value matches expected: $APP_ID_EXPECTED"
  fi
else
  echo "   MISMATCH: app=$APP_ID_APP token-server=$APP_ID_TOKEN"
  exit 1
fi
echo ""

echo "To verify against Agora Console:"
echo "  https://console.agora.io/ → Project Management → your project → App ID"
echo "  (App Certificate is under Edit for the project.)"
