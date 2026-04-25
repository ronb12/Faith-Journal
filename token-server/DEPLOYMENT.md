# Token Server Deployment Guide

## Current Status: Development Only ⚠️

The current setup (`http://localhost:8080`) only works for:
- ✅ Local development on your Mac
- ✅ iOS Simulator (can access localhost)
- ❌ **NOT for App Store users**
- ❌ **NOT for physical devices** (unless on same WiFi)
- ❌ **NOT for production**

## For All App Users: Deploy to Production

### Option 1: Deploy to Heroku (Easiest)

1. **Install Heroku CLI**:
   ```bash
   brew install heroku/brew/heroku
   ```

2. **Login and create app**:
   ```bash
   cd token-server
   heroku login
   heroku create faith-journal-token-server
   ```

3. **Set environment variables**:
   ```bash
   heroku config:set AGORA_APP_ID=89fdd88c9b594cf0947a48a8730e5f62
   heroku config:set AGORA_APP_CERTIFICATE=YOUR_AGORA_APP_CERTIFICATE
   ```

4. **Deploy**:
   ```bash
   git init
   git add .
   git commit -m "Initial token server"
   git push heroku main
   ```

5. **Get your production URL**:
   ```bash
   heroku info
   # Your URL will be: https://faith-journal-token-server.herokuapp.com
   ```

### Option 2: Deploy to Railway

1. Go to https://railway.app/
2. Sign up with GitHub
3. Click "New Project" → "Deploy from GitHub repo"
4. Select your token-server directory
5. Add environment variables:
   - `AGORA_APP_ID=89fdd88c9b594cf0947a48a8730e5f62`
   - `AGORA_APP_CERTIFICATE=YOUR_AGORA_APP_CERTIFICATE`
6. Railway will give you a URL like: `https://your-app.railway.app`

### Option 3: Deploy to DigitalOcean App Platform

1. Go to https://cloud.digitalocean.com/apps
2. Create new app → Connect GitHub
3. Select token-server directory
4. Add environment variables
5. Deploy

### Option 4: Deploy to AWS Lambda (Serverless)

Use serverless framework for auto-scaling.

## Update iOS App for Production

Once deployed, update `AgoraTokenService.swift`:

```swift
private var tokenServerURL: String {
    // Try environment variable first
    if let envURL = ProcessInfo.processInfo.environment["AGORA_TOKEN_SERVER_URL"], !envURL.isEmpty {
        return envURL
    }
    
    // Production URL - UPDATE THIS with your deployed server URL
    #if DEBUG
    // Development: use local server
    return "http://localhost:8080/api/agora/token"
    #else
    // Production: use deployed server
    return "https://your-token-server.herokuapp.com/api/agora/token"
    #endif
}
```

## Security Considerations

For production, consider adding:

1. **Rate Limiting**: Prevent abuse
2. **Authentication**: Require API keys or user tokens
3. **HTTPS Only**: Always use HTTPS in production
4. **CORS Configuration**: Restrict to your app's domain
5. **Monitoring**: Track usage and errors

## Testing Production Setup

1. Deploy server to cloud
2. Test endpoint:
   ```bash
   curl -X POST https://your-server.com/api/agora/token \
     -H "Content-Type: application/json" \
     -d '{"channelName":"test","uid":0,"role":"publisher"}'
   ```
3. Update iOS app with production URL
4. Test in TestFlight before App Store release

## Cost Estimates

- **Heroku**: Free tier available, $7/month for production
- **Railway**: $5/month starter plan
- **DigitalOcean**: $5/month
- **AWS Lambda**: Pay per request (very cheap for low traffic)

## Current vs Production

| Feature | Development (localhost) | Production (Deployed) |
|---------|------------------------|------------------------|
| Works for Simulator | ✅ Yes | ✅ Yes |
| Works for Physical Devices | ❌ No | ✅ Yes |
| Works for App Store Users | ❌ No | ✅ Yes |
| Scalability | Single user | Unlimited users |
| HTTPS | ❌ No | ✅ Yes |
| Always Available | ❌ No (only when running) | ✅ Yes (24/7) |
