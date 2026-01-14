#!/bin/bash
echo "🧪 Testing token server setup..."
echo ""

# Check if server file exists
if [ ! -f "server.js" ]; then
    echo "❌ server.js not found"
    exit 1
fi

# Check if dependencies are installed
if [ ! -d "node_modules" ]; then
    echo "❌ Dependencies not installed. Run: npm install"
    exit 1
fi

# Check if required packages are installed
if ! npm list express &>/dev/null; then
    echo "❌ express not installed"
    exit 1
fi

echo "✅ Server file exists"
echo "✅ Dependencies installed"
echo ""
echo "📝 To start the server:"
echo "   1. Set your App Certificate:"
echo "      export AGORA_APP_CERTIFICATE=\"your-certificate-here\""
echo "   2. Start the server:"
echo "      npm start"
echo ""
echo "   Or use: ./start.sh"
