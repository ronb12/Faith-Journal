const express = require('express');
// Use agora-token (newer package) or agora-access-token (deprecated but still works)
let RtcTokenBuilder, RtcRole;
try {
    const agoraToken = require('agora-token');
    RtcTokenBuilder = agoraToken.RtcTokenBuilder;
    RtcRole = agoraToken.RtcRole;
} catch (e) {
    // Fallback to deprecated package if agora-token not available
    const agoraAccessToken = require('agora-access-token');
    RtcTokenBuilder = agoraAccessToken.RtcTokenBuilder;
    RtcRole = agoraAccessToken.RtcRole;
}
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(cors());
app.use(express.json());

// Agora credentials - UPDATE THESE with your actual values
// Get these from: https://console.agora.io/ → Your Project → Edit
const APP_ID = process.env.AGORA_APP_ID || '89fdd88c9b594cf0947a48a8730e5f62';
const APP_CERTIFICATE = process.env.AGORA_APP_CERTIFICATE || 'YOUR_APP_CERTIFICATE_HERE';

// Validate configuration
if (!APP_CERTIFICATE || APP_CERTIFICATE === 'YOUR_APP_CERTIFICATE_HERE') {
    console.warn('⚠️  WARNING: APP_CERTIFICATE not set!');
    console.warn('⚠️  Please set AGORA_APP_CERTIFICATE environment variable or update server.js');
    console.warn('⚠️  Get your App Certificate from: https://console.agora.io/ → Your Project → Edit');
}

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        appId: APP_ID.substring(0, 8) + '...',
        hasCertificate: APP_CERTIFICATE && APP_CERTIFICATE !== 'YOUR_APP_CERTIFICATE_HERE'
    });
});

// Token generation endpoint
app.post('/api/agora/token', (req, res) => {
    try {
        const { channelName, uid, role } = req.body;

        // Validate required fields
        if (!channelName) {
            return res.status(400).json({ 
                error: 'channelName is required' 
            });
        }

        // Validate App Certificate
        if (!APP_CERTIFICATE || APP_CERTIFICATE === 'YOUR_APP_CERTIFICATE_HERE') {
            return res.status(500).json({ 
                error: 'Server configuration error: App Certificate not set',
                message: 'Please configure AGORA_APP_CERTIFICATE environment variable'
            });
        }

        // Parse UID (default to 0 for auto-assigned)
        const userId = uid !== undefined ? parseInt(uid) : 0;

        // Determine role
        const roleStr = role || 'publisher';
        const rtcRole = roleStr === 'publisher' ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;

        // Calculate expiration time (1 hour from now)
        const currentTime = Math.floor(Date.now() / 1000);
        const expirationTimeInSeconds = currentTime + 3600; // 1 hour

        // Generate token
        let token;
        if (userId === 0) {
            // Generate token with auto-assigned UID
            token = RtcTokenBuilder.buildTokenWithUid(
                APP_ID,
                APP_CERTIFICATE,
                channelName,
                userId,
                rtcRole,
                expirationTimeInSeconds
            );
        } else {
            // Generate token with specific UID
            token = RtcTokenBuilder.buildTokenWithUid(
                APP_ID,
                APP_CERTIFICATE,
                channelName,
                userId,
                rtcRole,
                expirationTimeInSeconds
            );
        }

        console.log(`✅ Token generated for channel: ${channelName}, UID: ${userId}, Role: ${roleStr}`);

        // Return token
        res.json({
            token: token,
            expiresIn: 3600,
            channelName: channelName,
            uid: userId,
            role: roleStr
        });

    } catch (error) {
        console.error('❌ Error generating token:', error);
        res.status(500).json({ 
            error: 'Failed to generate token',
            message: error.message 
        });
    }
});

// Start server
app.listen(PORT, () => {
    console.log('🚀 Agora Token Server running on port', PORT);
    console.log('📡 Endpoint: http://localhost:' + PORT + '/api/agora/token');
    console.log('🔑 App ID:', APP_ID.substring(0, 8) + '...');
    console.log('🔐 Certificate:', APP_CERTIFICATE && APP_CERTIFICATE !== 'YOUR_APP_CERTIFICATE_HERE' ? '✅ Set' : '❌ Not set');
    console.log('');
    console.log('⚠️  To get your App Certificate:');
    console.log('   1. Go to https://console.agora.io/');
    console.log('   2. Select your project');
    console.log('   3. Click "Edit"');
    console.log('   4. Copy the "App Certificate"');
    console.log('   5. Set it as: export AGORA_APP_CERTIFICATE="your-certificate-here"');
    console.log('');
});
