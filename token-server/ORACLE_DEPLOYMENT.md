# Deploy Token Server to Oracle Cloud

Since you already have an Oracle Cloud server running at `129.213.114.10`, you can host the Agora token server there instead of Vercel.

## Current Oracle Server Setup

- **IP**: `129.213.114.10`
- **LiveKit**: Port 7880
- **HLS Streaming**: Port 8080
- **Token Server**: Can use port 3000 (or any available port)

## Deployment Steps

### 1. SSH into Your Oracle Server

```bash
ssh your-user@129.213.114.10
```

### 2. Install Node.js (if not already installed)

```bash
# Check if Node.js is installed
node --version

# If not installed, install Node.js 18+
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 3. Upload Token Server Files

From your Mac, upload the token-server directory:

```bash
cd "/Users/ronellbradley/Desktop/Faith Journal"
scp -r token-server your-user@129.213.114.10:~/
```

Or use `rsync` for better sync:

```bash
rsync -avz token-server/ your-user@129.213.114.10:~/token-server/
```

### 4. On Oracle Server: Install Dependencies

```bash
cd ~/token-server
npm install
```

### 5. Set Environment Variables

Create `.env` file on the server:

```bash
nano ~/token-server/.env
```

Add:
```
AGORA_APP_ID=89fdd88c9b594cf0947a48a8730e5f62
AGORA_APP_CERTIFICATE=d082915a4058446e8537acf5df266736
PORT=3000
```

### 6. Run with PM2 (Recommended for Production)

```bash
# Install PM2 globally
sudo npm install -g pm2

# Start the server
cd ~/token-server
pm2 start server.js --name agora-token-server

# Save PM2 configuration
pm2 save

# Setup PM2 to start on boot
pm2 startup
# Follow the instructions it prints
```

### 7. Configure Firewall

Allow port 3000 (or your chosen port):

```bash
sudo ufw allow 3000/tcp
```

### 8. Test the Server

```bash
curl http://129.213.114.10:3000/health
curl -X POST http://129.213.114.10:3000/api/agora/token \
  -H "Content-Type: application/json" \
  -d '{"channelName":"test","uid":0,"role":"publisher"}'
```

## Update iOS App

Update `AgoraTokenService.swift`:

```swift
#else
// Production: use Oracle server
return "http://129.213.114.10:3000/api/agora/token"
#endif
```

Or use HTTPS if you have SSL configured:

```swift
return "https://129.213.114.10:3000/api/agora/token"
```

## Advantages of Using Oracle Server

✅ **One server for everything** - All backend services in one place  
✅ **No external dependencies** - Don't need Vercel  
✅ **Full control** - You manage the server  
✅ **Cost effective** - Use existing infrastructure  
✅ **Same network** - Faster communication  

## Optional: Use Nginx Reverse Proxy

If you want to use a subdomain or path, configure Nginx:

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location /api/agora/token {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Then update iOS app to use: `https://your-domain.com/api/agora/token`
