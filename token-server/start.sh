#!/bin/bash

# Agora Token Server Startup Script

echo "🚀 Starting Agora Token Server..."
echo ""

# Check if node is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first:"
    echo "   https://nodejs.org/"
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm first."
    exit 1
fi

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
    echo ""
fi

# Load .env file if it exists
if [ -f ".env" ]; then
    echo "📝 Loading configuration from .env file..."
    export $(cat .env | grep -v '^#' | xargs)
    echo ""
fi

# Check if App Certificate is set (either from .env or environment)
if [ -z "$AGORA_APP_CERTIFICATE" ]; then
    echo "⚠️  WARNING: AGORA_APP_CERTIFICATE not found!"
    echo ""
    echo "The server will use the default certificate from server.js"
    echo ""
else
    echo "✅ App Certificate configured: ${AGORA_APP_CERTIFICATE:0:8}..."
    echo ""
fi

# Start the server
echo "✅ Starting server on http://localhost:8080"
echo ""
npm start
