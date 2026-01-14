#!/bin/bash

# Deployment script that uses environment variables
# Usage: SSH_USER=youruser SSH_PASS=yourpass ./deploy-with-env.sh
# Or: SSH_USER=youruser ./deploy-with-env.sh (will prompt for password)

ORACLE_SERVER="129.213.114.10"
SSH_USER=${SSH_USER:-opc}

echo "🚀 Deploying to Oracle Server"
echo "=============================="
echo "Server: $ORACLE_SERVER"
echo "User: $SSH_USER"
echo ""

# Check if sshpass is available for password auth
if [ -n "$SSH_PASS" ] && command -v sshpass &> /dev/null; then
    echo "📤 Uploading with password authentication..."
    sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no token-server.tar.gz "$SSH_USER@$ORACLE_SERVER:~/"
    
    echo "🔧 Deploying on server..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$ORACLE_SERVER" 'bash -s' << 'ENDSSH'
cd ~
mkdir -p token-server
tar -xzf token-server.tar.gz -C token-server
cd token-server

if ! command -v node &> /dev/null; then
    echo "📦 Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

echo "📦 Installing dependencies..."
npm install --production

cat > .env << 'ENVEOF'
AGORA_APP_ID=89fdd88c9b594cf0947a48a8730e5f62
AGORA_APP_CERTIFICATE=d082915a4058446e8537acf5df266736
PORT=3000
ENVEOF

sudo npm install -g pm2 2>/dev/null || npm install -g pm2
pm2 stop agora-token-server 2>/dev/null || true
pm2 delete agora-token-server 2>/dev/null || true
PORT=3000 pm2 start server.js --name agora-token-server
pm2 save
sudo ufw allow 3000/tcp 2>/dev/null || echo "Firewall: Check manually"

echo "✅ Deployment complete!"
curl -s http://localhost:3000/health || echo "Server starting..."
ENDSSH
else
    echo "⚠️  SSH password authentication requires 'sshpass'"
    echo "Install it with: brew install hudochenkov/sshpass/sshpass"
    echo ""
    echo "Or use SSH keys, or run the interactive script manually."
    exit 1
fi
