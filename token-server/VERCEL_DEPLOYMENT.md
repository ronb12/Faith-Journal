# Deploy Token Server to Vercel

## Quick Deploy (Recommended)

### Option 1: Deploy via Vercel CLI (Fastest)

1. **Install Vercel CLI**:
   ```bash
   npm install -g vercel
   ```

2. **Login to Vercel**:
   ```bash
   cd token-server
   vercel login
   ```

3. **Deploy**:
   ```bash
   vercel
   ```
   
   Follow the prompts:
   - Set up and deploy? **Yes**
   - Which scope? **ronell-bradley** (or your account)
   - Link to existing project? **No**
   - Project name? **agora-token-server** (or any name)
   - Directory? **./** (current directory)
   - Override settings? **No**

4. **Set Environment Variables** (if not already in vercel.json):
   ```bash
   vercel env add AGORA_APP_ID
   # Enter: 89fdd88c9b594cf0947a48a8730e5f62
   
   vercel env add AGORA_APP_CERTIFICATE
   # Enter: d082915a4058446e8537acf5df266736
   ```

5. **Redeploy with environment variables**:
   ```bash
   vercel --prod
   ```

6. **Get your production URL**:
   ```bash
   vercel ls
   ```
   
   Your URL will be: `https://agora-token-server.vercel.app` (or similar)

### Option 2: Deploy via GitHub (Recommended for Production)

1. **Create a GitHub repository**:
   ```bash
   cd token-server
   git init
   git add .
   git commit -m "Initial commit - Agora token server"
   git branch -M main
   git remote add origin https://github.com/your-username/agora-token-server.git
   git push -u origin main
   ```

2. **Connect to Vercel**:
   - Go to https://vercel.com/ronell-bradleys-projects
   - Click "Add New..." → "Project"
   - Import your GitHub repository
   - Vercel will auto-detect the settings

3. **Configure Environment Variables**:
   - In Vercel dashboard → Your Project → Settings → Environment Variables
   - Add:
     - `AGORA_APP_ID` = `89fdd88c9b594cf0947a48a8730e5f62`
     - `AGORA_APP_CERTIFICATE` = `d082915a4058446e8537acf5df266736`

4. **Deploy**:
   - Click "Deploy"
   - Vercel will automatically deploy on every git push

## Update iOS App

After deployment, update `AgoraTokenService.swift`:

```swift
#else
// Production: use deployed Vercel server
return "https://your-project-name.vercel.app/api/agora/token"
#endif
```

Replace `your-project-name` with your actual Vercel project name.

## Test Your Deployment

Once deployed, test the endpoint:

```bash
curl -X POST https://your-project.vercel.app/api/agora/token \
  -H "Content-Type: application/json" \
  -d '{"channelName":"test-channel","uid":0,"role":"publisher"}'
```

You should get a JSON response with a token.

## Health Check

Test the health endpoint:

```bash
curl https://your-project.vercel.app/health
```

## Vercel Advantages

✅ **Free tier** - Generous limits for token generation  
✅ **Auto-scaling** - Handles traffic spikes automatically  
✅ **Global CDN** - Fast response times worldwide  
✅ **HTTPS included** - Secure by default  
✅ **Easy deployment** - Push to GitHub, auto-deploys  
✅ **Environment variables** - Secure credential management  

## Troubleshooting

### Error: "Module not found"
- Make sure `agora-token` is in `package.json` dependencies
- Vercel will install dependencies automatically

### Error: "Environment variable not set"
- Check Vercel dashboard → Settings → Environment Variables
- Make sure variables are set for "Production" environment
- Redeploy after adding variables

### CORS Issues
- The serverless function already includes CORS headers
- If issues persist, check the `Access-Control-Allow-Origin` header

## Production URL Format

Your production URL will be:
- `https://agora-token-server.vercel.app/api/agora/token`
- Or custom domain if configured: `https://tokens.yourdomain.com/api/agora/token`
