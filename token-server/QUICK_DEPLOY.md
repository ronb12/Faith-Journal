# Quick Deploy to Vercel - Step by Step

## Step 1: Login to Vercel

Run this command (it will open your browser):
```bash
cd "/Users/ronellbradley/Desktop/Faith Journal/token-server"
vercel login
```

Choose your login method (GitHub recommended if you have a Vercel account linked to GitHub).

## Step 2: Deploy

After logging in, run:
```bash
vercel
```

Answer the prompts:
- **Set up and deploy?** → Yes
- **Which scope?** → ronell-bradley (or your account)
- **Link to existing project?** → No
- **What's your project's name?** → agora-token-server (or any name)
- **In which directory is your code located?** → ./

## Step 3: Set Environment Variables

After deployment, set the credentials:

```bash
# Set App ID
vercel env add AGORA_APP_ID production
# When prompted, enter: 89fdd88c9b594cf0947a48a8730e5f62

# Set App Certificate
vercel env add AGORA_APP_CERTIFICATE production
# When prompted, enter: d082915a4058446e8537acf5df266736
```

## Step 4: Deploy to Production

```bash
vercel --prod
```

## Step 5: Get Your URL

After deployment, Vercel will show you the URL. It will look like:
```
https://agora-token-server.vercel.app
```

Your token endpoint will be:
```
https://agora-token-server.vercel.app/api/agora/token
```

## All-in-One Script

After logging in, you can run:
```bash
./deploy.sh
```

This will deploy and remind you to set environment variables.
