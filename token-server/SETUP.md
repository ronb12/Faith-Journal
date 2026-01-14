# Quick Setup Guide

## Step 1: Install Node.js (if not already installed)

Check if Node.js is installed:
```bash
node --version
npm --version
```

If not installed, download from: https://nodejs.org/

## Step 2: Install Dependencies

```bash
cd token-server
npm install
```

## Step 3: Get Your App Certificate

1. Go to https://console.agora.io/
2. Sign in to your account
3. Select your project (or create one)
4. Click "Edit" on the project
5. Find "App Certificate" and copy it

## Step 4: Set Environment Variable

```bash
export AGORA_APP_CERTIFICATE="your-app-certificate-here"
```

**Important:** Replace `your-app-certificate-here` with your actual App Certificate from Agora Console.

## Step 5: Start the Server

```bash
npm start
```

Or use the convenience script:
```bash
./start.sh
```

You should see:
```
🚀 Agora Token Server running on port 8080
📡 Endpoint: http://localhost:8080/api/agora/token
```

## Step 6: Test the Server

Open another terminal and test:
```bash
curl -X POST http://localhost:8080/api/agora/token \
  -H "Content-Type: application/json" \
  -d '{"channelName":"test-channel","uid":0,"role":"publisher"}'
```

You should get a JSON response with a token.

## Step 7: Run Your iOS App

The iOS app is already configured to use `http://localhost:8080/api/agora/token` by default.

Just make sure:
1. The token server is running
2. You're testing on the iOS Simulator (localhost works)
3. For physical devices, you'll need to use your computer's IP address

## Troubleshooting

### "App Certificate not set" error
- Make sure you exported the `AGORA_APP_CERTIFICATE` environment variable
- Verify the certificate is correct in Agora Console

### "Cannot connect" in iOS app
- Make sure the server is running (`npm start`)
- For iOS Simulator: `http://localhost:8080` should work
- For physical device: Use your Mac's IP address (e.g., `http://192.168.1.100:8080`)

### Port 8080 already in use
- Change the port: `PORT=3000 npm start`
- Update the URL in `AgoraTokenService.swift` to match
