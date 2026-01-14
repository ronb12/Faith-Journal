#!/bin/bash

cd "$(dirname "$0")"

echo "🚀 Deploying Agora Token Server to Vercel"
echo ""

# Check if logged in
if ! vercel whoami &>/dev/null; then
    echo "⚠️  Not logged in to Vercel"
    echo "📝 Please log in first:"
    echo "   vercel login"
    echo ""
    echo "Then run this script again."
    exit 1
fi

echo "✅ Logged in to Vercel"
echo ""

# Deploy
echo "📤 Deploying to Vercel..."
vercel --yes

echo ""
echo "✅ Deployment initiated!"
echo ""
echo "📝 Next steps:"
echo "1. Set environment variables in Vercel dashboard:"
echo "   - Go to your project settings"
echo "   - Add: AGORA_APP_ID = 89fdd88c9b594cf0947a48a8730e5f62"
echo "   - Add: AGORA_APP_CERTIFICATE = d082915a4058446e8537acf5df266736"
echo ""
echo "2. Or set via CLI:"
echo "   vercel env add AGORA_APP_ID production"
echo "   vercel env add AGORA_APP_CERTIFICATE production"
echo ""
echo "3. Redeploy: vercel --prod"
echo ""
