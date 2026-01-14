// Vercel Serverless Function for Agora Token Generation
// This file will be deployed as: /api/agora/token

// Use agora-token (newer package) or agora-access-token (deprecated but still works)
let RtcTokenBuilder, RtcRole;
try {
    // Try newer agora-token package first
    const agoraToken = require('agora-token');
    // Check if it's the new structure (v2.x) or old structure
    if (agoraToken.RtcTokenBuilder) {
        RtcTokenBuilder = agoraToken.RtcTokenBuilder;
        RtcRole = agoraToken.RtcRole;
        console.log('✅ Using agora-token package (v2.x structure)');
    } else if (agoraToken.default && agoraToken.default.RtcTokenBuilder) {
        // Some versions export as default
        RtcTokenBuilder = agoraToken.default.RtcTokenBuilder;
        RtcRole = agoraToken.default.RtcRole;
        console.log('✅ Using agora-token package (default export)');
    } else {
        throw new Error('agora-token structure not recognized');
    }
} catch (e) {
    try {
        // Fallback to deprecated package if agora-token not available
        const agoraAccessToken = require('agora-access-token');
        RtcTokenBuilder = agoraAccessToken.RtcTokenBuilder;
        RtcRole = agoraAccessToken.RtcRole;
        console.log('✅ Using agora-access-token package (fallback)');
    } catch (e2) {
        console.error('❌ Both agora-token packages failed to load:', e.message, e2?.message);
        throw new Error('Failed to load Agora token builder. Please ensure agora-token is installed.');
    }
}

export default async function handler(req, res) {
    // Enable CORS
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    
    // Handle preflight requests
    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }
    
    // Only allow POST requests
    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed. Use POST.' });
    }
    
    try {
        const { channelName, uid, role } = req.body;

        // Validate required fields
        if (!channelName) {
            return res.status(400).json({ 
                error: 'channelName is required' 
            });
        }

        // Get credentials from environment variables (trim whitespace)
        const APP_ID = (process.env.AGORA_APP_ID || '89fdd88c9b594cf0947a48a8730e5f62').trim();
        const APP_CERTIFICATE = (process.env.AGORA_APP_CERTIFICATE || 'd082915a4058446e8537acf5df266736').trim();

        // Validate credentials
        if (!APP_ID || APP_ID.length !== 32) {
            return res.status(500).json({ 
                error: 'Server configuration error: Invalid App ID',
                message: `APP_ID length is ${APP_ID.length}, expected 32. Please check AGORA_APP_ID environment variable in Vercel`,
                receivedLength: APP_ID.length
            });
        }
        
        if (!APP_CERTIFICATE || APP_CERTIFICATE.length !== 32 || APP_CERTIFICATE === 'YOUR_APP_CERTIFICATE_HERE') {
            return res.status(500).json({ 
                error: 'Server configuration error: Invalid App Certificate',
                message: `APP_CERTIFICATE length is ${APP_CERTIFICATE.length}, expected 32. Please check AGORA_APP_CERTIFICATE environment variable in Vercel`,
                receivedLength: APP_CERTIFICATE.length
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
        try {
            token = RtcTokenBuilder.buildTokenWithUid(
                APP_ID,
                APP_CERTIFICATE,
                channelName,
                userId,
                rtcRole,
                expirationTimeInSeconds
            );
            
            if (!token || token.length === 0) {
                throw new Error('Token generation returned empty string');
            }
            
            console.log(`✅ Token generated for channel: ${channelName}, UID: ${userId}, Role: ${roleStr}, Token length: ${token.length}`);
        } catch (tokenError) {
            console.error('❌ Token generation error:', tokenError);
            return res.status(500).json({ 
                error: 'Failed to generate token',
                message: tokenError.message,
                details: `APP_ID length: ${APP_ID?.length || 0}, APP_CERTIFICATE length: ${APP_CERTIFICATE?.length || 0}`
            });
        }

        // Return token
        return res.status(200).json({
            token: token,
            expiresIn: 3600,
            channelName: channelName,
            uid: userId,
            role: roleStr
        });

    } catch (error) {
        console.error('❌ Error generating token:', error);
        return res.status(500).json({ 
            error: 'Failed to generate token',
            message: error.message 
        });
    }
}
