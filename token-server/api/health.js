// Health check endpoint for Vercel
export default async function handler(req, res) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    
    const APP_ID = process.env.AGORA_APP_ID || '89fdd88c9b594cf0947a48a8730e5f62';
    const hasCertificate = process.env.AGORA_APP_CERTIFICATE && 
                          process.env.AGORA_APP_CERTIFICATE !== 'YOUR_APP_CERTIFICATE_HERE';
    
    return res.status(200).json({
        status: 'ok',
        appId: APP_ID.substring(0, 8) + '...',
        hasCertificate: hasCertificate,
        timestamp: new Date().toISOString()
    });
}
