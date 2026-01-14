# Why Vercel Can't Handle Live Streaming

## The Short Answer

**No, Vercel cannot be used for HLS or LiveKit streaming.**

## Technical Limitations

### HLS (HTTP Live Streaming)
- ❌ **No FFmpeg support** - Vercel serverless functions don't support video transcoding
- ❌ **Execution time limits** - Serverless functions have max execution time (can't handle continuous streaming)
- ❌ **No persistent connections** - Can't maintain long-lived streaming connections
- ❌ **Resource constraints** - Video processing requires too much CPU/memory

### LiveKit/WebRTC
- ❌ **No WebSocket support** - Vercel doesn't support WebSocket connections
- ❌ **Stateless architecture** - Serverless functions are stateless, WebRTC needs stateful connections
- ❌ **No real-time processing** - Can't handle real-time media processing

## The Solution: Use Agora for Everything

Since Agora already works globally (via Vercel token server), we've configured the app to use **Agora for ALL streaming modes**:

- ✅ **Broadcast Mode** → Uses Agora (one presenter, many viewers)
- ✅ **Conference Mode** → Uses Agora (all participants can stream)
- ✅ **Multi-Participant Mode** → Uses Agora (already configured)

## Benefits

- ✅ **Works globally** - Agora's infrastructure is worldwide
- ✅ **No server setup** - Token server on Vercel (free)
- ✅ **Scalable** - Handles unlimited users
- ✅ **Reliable** - Professional-grade streaming
- ✅ **Free tier available** - Agora has generous free tier

## What Changed

The app now routes all streaming modes to `MultiParticipantStreamView`, which uses Agora. This means:
- All users can stream from anywhere
- No Oracle server configuration needed
- No firewall setup required
- Everything works globally automatically
