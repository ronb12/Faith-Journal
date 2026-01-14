#!/bin/bash
echo "🚀 Interactive Oracle Deployment"
echo "================================"
echo ""
read -p "Oracle SSH Username [opc]: " SSH_USER
SSH_USER=${SSH_USER:-opc}

echo ""
echo "📤 Uploading token-server.tar.gz..."
scp token-server.tar.gz "$SSH_USER@129.213.114.10:~/"

echo ""
echo "🔧 Running deployment commands on server..."
ssh "$SSH_USER@129.213.114.10" 'bash -s' << 'ENDSSH'
cd ~
mkdir -p token-server
tar -xzf token-server.tar.gz -C token-server
cd token-server

# Install Node.js if needed
if ! command -v node &> /dev/null; then
    echo "📦 Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

echo "📦 Installing dependencies..."
npm install --production

echo "📝 Creating .env..."
cat > .env << 'ENVEOF'
AGORA_APP_ID=89fdd88c9b594cf0947a48a8730e5f62
AGORA_APP_CERTIFICATE=d082915a4058446e8537acf5df266736
PORT=3000
ENVEOF

echo "🔧 Installing PM2..."
sudo npm install -g pm2 2>/dev/null || npm install -g pm2

echo "🛑 Stopping old instance..."
pm2 stop agora-token-server 2>/dev/null || true
pm2 delete agora-token-server 2>/dev/null || true

echo "🚀 Starting server..."
PORT=3000 pm2 start server.js --name agora-token-server
pm2 save

echo "🔓 Opening firewall..."
sudo ufw allow 3000/tcp 2>/dev/null || echo "⚠️  Firewall: May need manual setup"

echo ""
echo "✅ Deployment complete!"
echo "📍 Server: http://129.213.114.10:3000/api/agora/token"
echo ""
echo "🧪 Testing..."
sleep 2
curl -s http://localhost:3000/health || echo "⚠️  Health check failed (server may be starting)"
ENDSSH

echo ""
echo "✅ Done! Server should be running."
