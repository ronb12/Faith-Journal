# Deploy to Oracle Server - Step by Step

## Quick Deployment Steps

### Step 1: Accept SSH Host Key (First Time Only)

```bash
ssh-keyscan -H 129.213.114.10 >> ~/.ssh/known_hosts
```

Or when you SSH for the first time, type "yes" when prompted.

### Step 2: Upload Files

From your Mac terminal:

```bash
cd "/Users/ronellbradley/Desktop/Faith Journal/token-server"
scp token-server.tar.gz your-username@129.213.114.10:~/
```

Replace `your-username` with your Oracle server username (usually `opc` for Oracle Cloud).

### Step 3: SSH into Server

```bash
ssh your-username@129.213.114.10
```

### Step 4: Extract and Setup (Run on Oracle Server)

```bash
# Extract files
mkdir -p ~/token-server
cd ~
tar -xzf token-server.tar.gz -C token-server

cd ~/token-server

# Install Node.js (if not installed)
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Install dependencies
npm install --production

# Create .env file
cat > .env << 'EOF'
AGORA_APP_ID=89fdd88c9b594cf0947a48a8730e5f62
AGORA_APP_CERTIFICATE=YOUR_AGORA_APP_CERTIFICATE
PORT=3000
EOF

# Install PM2
sudo npm install -g pm2

# Start server
PORT=3000 pm2 start server.js --name agora-token-server
pm2 save

# Setup PM2 to start on boot
pm2 startup
# Copy and run the command it outputs

# Open firewall
sudo ufw allow 3000/tcp
```

### Step 5: Test

```bash
# On Oracle server
curl http://localhost:3000/health

# From your Mac
curl http://129.213.114.10:3000/health
```

### Step 6: Verify It's Running

```bash
pm2 list
pm2 logs agora-token-server
```

## All-in-One Command (Copy & Paste)

If you're already SSH'd into the server, you can run this all at once:

```bash
cd ~ && \
mkdir -p token-server && \
tar -xzf token-server.tar.gz -C token-server && \
cd token-server && \
(command -v node >/dev/null || (curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs)) && \
npm install --production && \
echo "AGORA_APP_ID=89fdd88c9b594cf0947a48a8730e5f62
AGORA_APP_CERTIFICATE=YOUR_AGORA_APP_CERTIFICATE
PORT=3000" > .env && \
sudo npm install -g pm2 && \
PORT=3000 pm2 start server.js --name agora-token-server && \
pm2 save && \
sudo ufw allow 3000/tcp && \
echo "✅ Server deployed! Test with: curl http://localhost:3000/health"
```

## Troubleshooting

### Port Already in Use
Change PORT in .env to something else (like 3001) and update iOS app.

### Permission Denied
Use `sudo` for npm install -g and ufw commands.

### Can't Connect
Check firewall: `sudo ufw status`
Check if server is running: `pm2 list`
