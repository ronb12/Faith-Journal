#!/bin/bash

# Deploy Agora Token Server to Oracle Cloud
# Oracle Server: 129.213.114.10

set -e

ORACLE_SERVER="129.213.114.10"
ORACLE_USER="${ORACLE_USER:-opc}"  # Default to 'opc' for Oracle, change if different
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"
REMOTE_DIR="~/token-server"
PORT=3000

echo "🚀 Deploying Agora Token Server to Oracle Cloud"
echo "================================================"
echo ""
echo "Server: $ORACLE_SERVER"
echo "User: $ORACLE_USER"
echo "Port: $PORT"
echo ""

# Check if SSH key exists
if [ ! -f ~/.ssh/id_rsa ] && [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "⚠️  No SSH key found. You may need to enter password."
    echo ""
fi

# Step 1: Upload files
echo "📤 Step 1: Uploading files to Oracle server..."
rsync -avz --exclude 'node_modules' --exclude '.git' --exclude '.vercel' \
    "$LOCAL_DIR/" "$ORACLE_USER@$ORACLE_SERVER:$REMOTE_DIR/" || {
    echo "❌ Upload failed. Trying with scp..."
    scp -r "$LOCAL_DIR" "$ORACLE_USER@$ORACLE_SERVER:~/"
}

echo "✅ Files uploaded"
echo ""

# Step 2: SSH and setup
echo "📦 Step 2: Setting up on Oracle server..."
echo ""

ssh "$ORACLE_USER@$ORACLE_SERVER" << 'ENDSSH'
set -e

cd ~/token-server || cd ~/token-server

echo "🔍 Checking Node.js..."
if ! command -v node &> /dev/null; then
    echo "📦 Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "✅ Node.js already installed: $(node --version)"
fi

echo ""
echo "📦 Installing dependencies..."
npm install --production

echo ""
echo "📝 Creating .env file..."
cat > .env << 'ENVEOF'
AGORA_APP_ID=89fdd88c9b594cf0947a48a8730e5f62
AGORA_APP_CERTIFICATE=d082915a4058446e8537acf5df266736
PORT=3000
ENVEOF

echo "✅ .env file created"
echo ""

echo "🔧 Installing PM2 (process manager)..."
if ! command -v pm2 &> /dev/null; then
    sudo npm install -g pm2
else
    echo "✅ PM2 already installed"
fi

echo ""
echo "🛑 Stopping existing token server if running..."
pm2 stop agora-token-server 2>/dev/null || true
pm2 delete agora-token-server 2>/dev/null || true

echo ""
echo "🚀 Starting token server with PM2..."
PORT=3000 pm2 start server.js --name agora-token-server
pm2 save

echo ""
echo "📋 PM2 Status:"
pm2 list

echo ""
echo "🔓 Configuring firewall..."
sudo ufw allow 3000/tcp 2>/dev/null || echo "⚠️  Firewall command failed (may need manual setup)"

echo ""
echo "✅ Token server deployed and running!"
echo "📍 Endpoint: http://129.213.114.10:3000/api/agora/token"
echo ""
echo "🧪 Testing server..."
sleep 2
curl -s http://localhost:3000/health || echo "⚠️  Health check failed (server may still be starting)"

ENDSSH

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📍 Token Server URL: http://129.213.114.10:3000/api/agora/token"
echo ""
echo "🧪 Test the server:"
echo "   curl http://129.213.114.10:3000/health"
echo ""
echo "📊 Monitor with PM2:"
echo "   ssh $ORACLE_USER@$ORACLE_SERVER 'pm2 list'"
echo "   ssh $ORACLE_USER@$ORACLE_SERVER 'pm2 logs agora-token-server'"
