#!/usr/bin/env python3
"""
Script to update App Store Connect metadata using the App Store Connect API
Requires: API Key (.p8 file), Key ID, and Issuer ID
"""

import os
import sys
import json
from pathlib import Path

# Try to load credentials from environment or .env file
def load_credentials():
    """Load App Store Connect API credentials"""
    credentials = {}
    
    # Check for .env file
    env_file = Path(".env")
    if env_file.exists():
        print("📄 Found .env file, loading credentials...")
        with open(env_file) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    credentials[key.strip()] = value.strip().strip('"').strip("'")
    
    # Also check environment variables
    credentials.update({
        "ASC_KEY_ID": os.getenv("ASC_KEY_ID", credentials.get("ASC_KEY_ID")),
        "ASC_ISSUER_ID": os.getenv("ASC_ISSUER_ID", credentials.get("ASC_ISSUER_ID")),
        "ASC_KEY_PATH": os.getenv("ASC_KEY_PATH", credentials.get("ASC_KEY_PATH")),
        "ASC_APP_ID": os.getenv("ASC_APP_ID", credentials.get("ASC_APP_ID")),
    })
    
    return credentials

def check_credentials(credentials):
    """Verify all required credentials are present"""
    required = ["ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_PATH"]
    missing = [key for key in required if not credentials.get(key)]
    
    if missing:
        print("❌ Missing required credentials:")
        for key in missing:
            print(f"   - {key}")
        print("\n💡 To use this script, you need:")
        print("   1. Create an API key in App Store Connect:")
        print("      https://appstoreconnect.apple.com/access/api")
        print("   2. Download the .p8 key file")
        print("   3. Create a .env file with:")
        print("      ASC_KEY_ID=your_key_id")
        print("      ASC_ISSUER_ID=your_issuer_id")
        print("      ASC_KEY_PATH=path/to/AuthKey_XXXXX.p8")
        print("      ASC_APP_ID=your_app_id (optional, will be detected)")
        return False
    
    # Check if key file exists
    key_path = Path(credentials["ASC_KEY_PATH"])
    if not key_path.exists():
        print(f"❌ API key file not found: {key_path}")
        return False
    
    print("✅ All credentials found!")
    return True

def main():
    print("🔐 App Store Connect Metadata Updater")
    print("=" * 50)
    
    credentials = load_credentials()
    
    if not check_credentials(credentials):
        print("\n📝 For now, please use the manual method:")
        print("   1. Open: APP_STORE_CONNECT_SETUP_GUIDE.md")
        print("   2. Follow the step-by-step instructions")
        print("   3. Copy text from: COPY_PASTE_TEXT.txt")
        return 1
    
    print("\n✅ Credentials loaded successfully!")
    print("\n📋 To update metadata via API, you would need:")
    print("   - App Store Connect API Python library")
    print("   - Proper API endpoints for metadata updates")
    print("   - App ID from App Store Connect")
    
    print("\n💡 Recommendation:")
    print("   The App Store Connect web interface is the easiest way")
    print("   to update promotional text. Use APP_STORE_CONNECT_SETUP_GUIDE.md")
    print("   for step-by-step instructions.")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())

