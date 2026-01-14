#!/bin/bash
echo "🚀 Deploying to Vercel..."
echo ""

# Check if Vercel CLI is installed
if ! command -v vercel &> /dev/null; then
    echo "📦 Installing Vercel CLI..."
    npm install -g vercel
    echo ""
fi

# Deploy
echo "📤 Deploying..."
vercel

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📝 Next steps:"
echo "1. Set environment variables in Vercel dashboard:"
echo "   - AGORA_APP_ID = 89fdd88c9b594cf0947a48a8730e5f62"
echo "   - AGORA_APP_CERTIFICATE = d082915a4058446e8537acf5df266736"
echo ""
echo "2. Or set them via CLI:"
echo "   vercel env add AGORA_APP_ID"
echo "   vercel env add AGORA_APP_CERTIFICATE"
echo ""
echo "3. Redeploy: vercel --prod"
