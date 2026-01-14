#!/bin/bash

echo "🚀 Agora Token Server - Vercel Deployment"
echo "=========================================="
echo ""

cd "$(dirname "$0")"

# Step 1: Check login
echo "1️⃣  Checking Vercel login..."
if vercel whoami &>/dev/null; then
    USER=$(vercel whoami)
    echo "   ✅ Logged in as: $USER"
else
    echo "   ⚠️  Not logged in"
    echo ""
    echo "   Please run: vercel login"
    echo "   (This will open your browser for authentication)"
    exit 1
fi

echo ""

# Step 2: Deploy
echo "2️⃣  Deploying to Vercel..."
vercel --yes

echo ""

# Step 3: Check if env vars are set
echo "3️⃣  Checking environment variables..."
PROJECT_NAME=$(cat .vercel/project.json 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ -n "$PROJECT_NAME" ]; then
    echo "   Project: $PROJECT_NAME"
    echo ""
    echo "4️⃣  Setting environment variables..."
    echo ""
    echo "   Run these commands to set credentials:"
    echo ""
    echo "   vercel env add AGORA_APP_ID production"
    echo "   # Enter: 89fdd88c9b594cf0947a48a8730e5f62"
    echo ""
    echo "   vercel env add AGORA_APP_CERTIFICATE production"
    echo "   # Enter: d082915a4058446e8537acf5df266736"
    echo ""
    echo "   Then deploy to production:"
    echo "   vercel --prod"
else
    echo "   ⚠️  Project not found. Deployment may have failed."
fi

echo ""
echo "✅ Done! Check the output above for your deployment URL."
