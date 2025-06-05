#!/bin/bash

cd "Faith Journal/Assets.xcassets/AppIcon.appiconset"

# iPhone icons
sips -z 40 40 "AppIcon1024 1.png"    # iPhone Notification 20pt@2x
sips -z 60 60 "AppIcon1024 2.png"    # iPhone Notification 20pt@3x
sips -z 58 58 "AppIcon1024 3.png"    # iPhone Settings 29pt@2x
sips -z 87 87 "AppIcon1024 4.png"    # iPhone Settings 29pt@3x
sips -z 80 80 "AppIcon1024 5.png"    # iPhone Spotlight 40pt@2x
sips -z 120 120 "AppIcon1024 6.png"  # iPhone Spotlight 40pt@3x
sips -z 120 120 "AppIcon1024 7.png"  # iPhone App 60pt@2x
sips -z 180 180 "AppIcon1024 8.png"  # iPhone App 60pt@3x

# iPad icons
sips -z 20 20 "AppIcon1024 9.png"    # iPad Notifications 20pt@1x
sips -z 40 40 "AppIcon1024 10.png"   # iPad Notifications 20pt@2x
sips -z 29 29 "AppIcon1024 11.png"   # iPad Settings 29pt@1x
sips -z 58 58 "AppIcon1024 12.png"   # iPad Settings 29pt@2x
sips -z 40 40 "AppIcon1024 13.png"   # iPad Spotlight 40pt@1x
sips -z 80 80 "AppIcon1024 14.png"   # iPad Spotlight 40pt@2x
sips -z 76 76 "AppIcon1024 15.png"   # iPad App 76pt@1x
sips -z 152 152 "AppIcon1024 16.png" # iPad App 76pt@2x
sips -z 167 167 "AppIcon1024 17.png" # iPad Pro App 83.5pt@2x

echo "App icons have been resized to their correct dimensions" 