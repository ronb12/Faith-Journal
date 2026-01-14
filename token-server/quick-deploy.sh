#!/bin/bash

# Quick deploy script - prompts for SSH details if needed

ORACLE_SERVER="129.213.114.10"
DEFAULT_USER="opc"

echo "🚀 Quick Deploy to Oracle Server"
echo "================================"
echo ""

# Get SSH user (default to opc for Oracle Cloud)
read -p "SSH Username [$DEFAULT_USER]: " SSH_USER
SSH_USER=${SSH_USER:-$DEFAULT_USER}

echo ""
echo "📤 Uploading files..."
scp -r token-server.tar.gz "$SSH_USER@$ORACLE_SERVER:~/"

echo ""
echo "🔧 Setting up on server..."
ssh "$SSH_USER@$ORACLE_SERVER" << 'ENDSSH'
cd ~
tar -xzf token-server.tar.gz -C token-server 2>/dev/null || {
    mkdir -p token-server
    tar -xzf token-server.tar.gz -C token-server
}

cd token-server

# Install Node.js if needed
if ! command -v node &> /dev/null; then
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Install dependencies
npm install --production

# Create .env
cat > .env << 'ENVEOF'
AGORA_APP_ID=89fdd88c9b594cf0947a48a8730e5f62
AGORA_APP_CERTIFICATE=d082915a4058446e8537acf5df266736
PORT=3000
ENVEOF

# Install PM2
sudo npm install -g pm2 2>/dev/null || npm install -g pm2

# Stop old instance
pm2 stop agora-token-server 2>/dev/null || true
pm2 delete agora-token-server 2>/dev/null || true

# Start server
PORT=3000 pm2 start server.js --name agora-token-server
pm2 save

# Firewall
sudo ufw allow 3000/tcp 2>/dev/null || echo "Firewall: Check manually"

echo ""
echo "✅ Server running on port 3000"
echo "Test: curl http://localhost:3000/health"
ENDSSH

echo ""
echo "✅ Deployment complete!"
echo "📍 URL: http://129.213.114.10:3000/api/agora/token"
