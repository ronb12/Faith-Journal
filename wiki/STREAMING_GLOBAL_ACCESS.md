# Global Streaming Access Configuration

This guide ensures live streaming works for users anywhere in the world.

## Current Setup

### ✅ Agora Multi-Participant Streaming
- **Status**: ✅ Configured for global access
- **Token Server**: Vercel (free, global CDN)
- **URL**: `https://token-server.vercel.app/api/agora/token`
- **Access**: Works from anywhere automatically

### ⚠️ HLS Streaming (Oracle Server)
- **Server**: `129.213.114.10:8080`
- **Status**: Requires public access configuration
- **URL Format**: `http://129.213.114.10:8080/hls/{sessionId}/index.m3u8`

### ⚠️ LiveKit Streaming (Oracle Server)
- **Server**: `129.213.114.10:7880`
- **Status**: Requires public access configuration
- **URL**: `ws://129.213.114.10:7880`

## Requirements for Global Access

### Oracle Server Configuration

For users to access streams from anywhere, ensure:

1. **Firewall Rules** (on Oracle server):
   ```bash
   sudo ufw allow 8080/tcp  # HLS streaming
   sudo ufw allow 7880/tcp  # LiveKit WebSocket
   sudo ufw allow 3000/tcp  # Token server (if deployed)
   ```

2. **Network Security Groups** (Oracle Cloud Console):
   - Allow inbound traffic on ports 8080, 7880, 3000
   - Source: 0.0.0.0/0 (all IPs) for public access

3. **Server Services Running**:
   - HLS streaming service on port 8080
   - LiveKit server on port 7880

## How It Works

### For Multi-Participant Streams (Agora)
✅ **Already works globally!**
- Uses Agora's global infrastructure
- Token server on Vercel (global CDN)
- No additional configuration needed

### For HLS Broadcast Streams
⚠️ **Requires Oracle server to be publicly accessible**
- Stream URL: `http://129.213.114.10:8080/hls/{sessionId}/index.m3u8`
- Users can watch from anywhere IF:
  - Oracle server firewall allows port 8080
  - Network security groups allow inbound traffic
  - HLS service is running

### For LiveKit Conference Streams
⚠️ **Requires Oracle server to be publicly accessible**
- WebSocket URL: `ws://129.213.114.10:7880`
- Users can join from anywhere IF:
  - Oracle server firewall allows port 7880
  - Network security groups allow inbound traffic
  - LiveKit server is running

## Testing Global Access

### Test from Your Mac:
```bash
# Test HLS endpoint
curl http://129.213.114.10:8080/health

# Test LiveKit
curl http://129.213.114.10:7880/health
```

### Test from Mobile Device:
1. Connect to a different network (mobile data)
2. Try to join a live stream
3. If it works, global access is configured correctly

## Troubleshooting

### "Cannot connect to stream"
- **Cause**: Firewall blocking ports
- **Fix**: Open ports 8080, 7880 in Oracle Cloud Console

### "Connection timeout"
- **Cause**: Network security group not configured
- **Fix**: Add inbound rules for ports 8080, 7880

### "Stream not found"
- **Cause**: HLS service not running
- **Fix**: Start HLS streaming service on Oracle server

## Alternative: Use Cloud Streaming Services

If Oracle server access is problematic, consider:

1. **Cloudflare Stream** (paid, but reliable)
2. **AWS MediaLive** (scalable, pay-per-use)
3. **Mux** (developer-friendly, pay-per-use)
4. **Agora** (already integrated, works globally)

## Current Status

- ✅ **Agora**: Fully configured for global access
- ⚠️ **HLS**: Requires Oracle server public access
- ⚠️ **LiveKit**: Requires Oracle server public access

The app will automatically use Agora for multi-participant streams (works globally), and HLS/LiveKit for other modes (requires Oracle server configuration).
