# Agora Token Server Setup Guide

This guide explains how to set up a token server for Agora RTC authentication in production.

## Overview

Agora requires tokens for secure channel access in production. The app automatically fetches tokens from your token server when configured.

## Quick Start

### 1. Set Up Token Server URL

Configure the token server URL using one of these methods:

#### Option A: Environment Variable (Recommended for CI/CD)
```bash
export AGORA_TOKEN_SERVER_URL="https://your-server.com/api/agora/token"
```

#### Option B: Update AgoraTokenService.swift
Edit `AgoraTokenService.swift` and update the default `tokenServerURL`:
```swift
private var tokenServerURL: String {
    return "https://your-token-server.com/api/agora/token"
}
```

### 2. Token Server Requirements

Your token server must implement a POST endpoint that accepts:

**Request:**
```json
{
  "channelName": "faith-journal-{session-id}",
  "uid": 0,
  "role": "publisher" // or "subscriber"
}
```

**Response:**
```json
{
  "token": "your-agora-token-string",
  "expiresIn": 3600  // Optional: expiration time in seconds
}
```

Or simply return the token as a plain string.

### 3. Token Server Implementation Examples

#### Node.js Example

```javascript
const express = require('express');
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

const app = express();
app.use(express.json());

const APP_ID = 'your-agora-app-id';
const APP_CERTIFICATE = 'your-agora-app-certificate';

app.post('/api/agora/token', (req, res) => {
  const { channelName, uid, role } = req.body;
  
  // Calculate expiration time (1 hour from now)
  const expirationTimeInSeconds = Math.floor(Date.now() / 1000) + 3600;
  
  // Determine role
  const rtcRole = role === 'publisher' ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;
  
  // Generate token
  const token = RtcTokenBuilder.buildTokenWithUid(
    APP_ID,
    APP_CERTIFICATE,
    channelName,
    uid,
    rtcRole,
    expirationTimeInSeconds
  );
  
  res.json({
    token: token,
    expiresIn: 3600
  });
});

app.listen(8080, () => {
  console.log('Token server running on port 8080');
});
```

#### Python Example

```python
from flask import Flask, request, jsonify
from agora_token_builder import RtcTokenBuilder, Role

app = Flask(__name__)

APP_ID = 'your-agora-app-id'
APP_CERTIFICATE = 'your-agora-app-certificate'

@app.route('/api/agora/token', methods=['POST'])
def generate_token():
    data = request.json
    channel_name = data.get('channelName')
    uid = data.get('uid', 0)
    role_str = data.get('role', 'publisher')
    
    # Determine role
    role = Role.PUBLISHER if role_str == 'publisher' else Role.SUBSCRIBER
    
    # Calculate expiration (1 hour from now)
    expiration_time = int(time.time()) + 3600
    
    # Generate token
    token = RtcTokenBuilder.build_token_with_uid(
        APP_ID,
        APP_CERTIFICATE,
        channel_name,
        uid,
        role,
        expiration_time
    )
    
    return jsonify({
        'token': token,
        'expiresIn': 3600
    })

if __name__ == '__main__':
    app.run(port=8080)
```

#### Go Example

```go
package main

import (
    "encoding/json"
    "net/http"
    "time"
    "github.com/AgoraIO/Tools/DynamicKey/AgoraDynamicKey/go/src/rtctokenbuilder"
)

const (
    APP_ID        = "your-agora-app-id"
    APP_CERTIFICATE = "your-agora-app-certificate"
)

type TokenRequest struct {
    ChannelName string `json:"channelName"`
    UID         uint32 `json:"uid"`
    Role        string `json:"role"`
}

type TokenResponse struct {
    Token     string `json:"token"`
    ExpiresIn int    `json:"expiresIn"`
}

func generateToken(w http.ResponseWriter, r *http.Request) {
    var req TokenRequest
    json.NewDecoder(r.Body).Decode(&req)
    
    // Determine role
    role := rtctokenbuilder.RolePublisher
    if req.Role == "subscriber" {
        role = rtctokenbuilder.RoleSubscriber
    }
    
    // Calculate expiration (1 hour from now)
    expirationTime := uint32(time.Now().Unix()) + 3600
    
    // Generate token
    token, err := rtctokenbuilder.BuildTokenWithUID(
        APP_ID,
        APP_CERTIFICATE,
        req.ChannelName,
        req.UID,
        role,
        expirationTime,
    )
    
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    
    response := TokenResponse{
        Token:     token,
        ExpiresIn: 3600,
    }
    
    json.NewEncoder(w).Encode(response)
}

func main() {
    http.HandleFunc("/api/agora/token", generateToken)
    http.ListenAndServe(":8080", nil)
}
```

## Security Best Practices

1. **Never expose App Certificate in client code** - Keep it server-side only
2. **Use HTTPS** - Always use HTTPS for token server endpoints
3. **Add authentication** - Require API keys or user authentication for token requests
4. **Set appropriate expiration** - Tokens should expire (recommended: 1 hour)
5. **Validate requests** - Verify channel names and user IDs before generating tokens

## Testing

### Local Testing

1. Start your token server locally (e.g., `http://localhost:8080/api/agora/token`)
2. Set environment variable:
   ```bash
   export AGORA_TOKEN_SERVER_URL="http://localhost:8080/api/agora/token"
   ```
3. Run the app - it will automatically fetch tokens from your local server

### Production

1. Deploy token server to your production environment
2. Set `AGORA_TOKEN_SERVER_URL` environment variable in your app's build configuration
3. Or update `AgoraTokenService.swift` with production URL

## Troubleshooting

### Error: "Invalid token server URL"
- Verify `AGORA_TOKEN_SERVER_URL` is set correctly
- Check that the URL is accessible from your device/simulator
- Ensure the URL uses `http://` or `https://` protocol

### Error: "Token server error (500)"
- Check your token server logs
- Verify App ID and App Certificate are correct
- Ensure token generation library is properly installed

### Error: "Network error"
- Check network connectivity
- Verify token server is running and accessible
- Check firewall/security settings

## Additional Resources

- [Agora Token Server Documentation](https://docs.agora.io/en/voice-calling/token-authentication/deploy-token-server)
- [Agora Token Generator Libraries](https://github.com/AgoraIO/Tools/tree/master/DynamicKey)
- [Agora Console](https://console.agora.io/)
