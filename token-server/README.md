# Agora Token Server

Simple Node.js token server for generating Agora RTC tokens.

## Quick Start

### 1. Install Dependencies

```bash
cd token-server
npm install
```

### 2. Get Your App Certificate

1. Go to https://console.agora.io/
2. Sign in and select your project
3. Click "Edit" on your project
4. Copy the "App Certificate" value

### 3. Set Environment Variables

```bash
export AGORA_APP_ID="89fdd88c9b594cf0947a48a8730e5f62"
export AGORA_APP_CERTIFICATE="your-app-certificate-here"
```

Or create a `.env` file (recommended):

```bash
AGORA_APP_ID=89fdd88c9b594cf0947a48a8730e5f62
AGORA_APP_CERTIFICATE=your-app-certificate-here
```

### 4. Start the Server

```bash
npm start
```

The server will run on `http://localhost:8080`

## Endpoints

### POST `/api/agora/token`

Generates an Agora RTC token.

**Request Body:**
```json
{
  "channelName": "faith-journal-{session-id}",
  "uid": 0,
  "role": "publisher"
}
```

**Response:**
```json
{
  "token": "your-agora-token",
  "expiresIn": 3600,
  "channelName": "faith-journal-{session-id}",
  "uid": 0,
  "role": "publisher"
}
```

### GET `/health`

Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "appId": "89fdd88c...",
  "hasCertificate": true
}
```

## Configuration

The server uses these environment variables:

- `AGORA_APP_ID` - Your Agora App ID (defaults to the one in your Swift code)
- `AGORA_APP_CERTIFICATE` - Your Agora App Certificate (required)
- `PORT` - Server port (defaults to 8080)

## Production Deployment

For production, deploy this server to a hosting service like:

- **Heroku**: `git push heroku main`
- **Railway**: Connect your GitHub repo
- **AWS Lambda**: Use serverless framework
- **DigitalOcean**: Deploy as a Node.js app

Make sure to:
1. Set environment variables in your hosting platform
2. Use HTTPS (required for production)
3. Add authentication/rate limiting if needed
4. Update the URL in `AgoraTokenService.swift` to your production server

## Troubleshooting

### Error: "App Certificate not set"
- Make sure you've set the `AGORA_APP_CERTIFICATE` environment variable
- Verify the certificate is correct in Agora Console

### Error: "Invalid App ID"
- Check that your App ID matches the one in Agora Console
- Verify the App ID is active and not expired

### Connection Refused
- Make sure the server is running (`npm start`)
- Check that port 8080 is not in use
- For iOS Simulator, use `http://localhost:8080`
- For physical device, use your computer's IP address (e.g., `http://192.168.1.100:8080`)
