#!/bin/bash

# Create temporary directory for icons
mkdir -p tmp_icons

# Copy the source icon
cp "Faith Journal/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png" tmp_icons/

# Generate all required sizes
cd tmp_icons

# iPhone icons (20pt, 29pt, 40pt, 60pt)
sips -z 40 40 AppIcon1024.png --out "AppIcon1024 1.png"  # 20pt@2x
sips -z 60 60 AppIcon1024.png --out "AppIcon1024 2.png"  # 20pt@3x
sips -z 58 58 AppIcon1024.png --out "AppIcon1024 3.png"  # 29pt@2x
sips -z 87 87 AppIcon1024.png --out "AppIcon1024 4.png"  # 29pt@3x
sips -z 80 80 AppIcon1024.png --out "AppIcon1024 5.png"  # 40pt@2x
sips -z 120 120 AppIcon1024.png --out "AppIcon1024 6.png" # 40pt@3x
sips -z 120 120 AppIcon1024.png --out "AppIcon1024 7.png" # 60pt@2x
sips -z 180 180 AppIcon1024.png --out "AppIcon1024 8.png" # 60pt@3x

# iPad icons (20pt, 29pt, 40pt, 76pt, 83.5pt)
sips -z 20 20 AppIcon1024.png --out "AppIcon1024 9.png"   # 20pt@1x
sips -z 40 40 AppIcon1024.png --out "AppIcon1024 10.png"  # 20pt@2x
sips -z 29 29 AppIcon1024.png --out "AppIcon1024 11.png"  # 29pt@1x
sips -z 58 58 AppIcon1024.png --out "AppIcon1024 12.png"  # 29pt@2x
sips -z 40 40 AppIcon1024.png --out "AppIcon1024 13.png"  # 40pt@1x
sips -z 80 80 AppIcon1024.png --out "AppIcon1024 14.png"  # 40pt@2x
sips -z 76 76 AppIcon1024.png --out "AppIcon1024 15.png"  # 76pt@1x
sips -z 152 152 AppIcon1024.png --out "AppIcon1024 16.png" # 76pt@2x
sips -z 167 167 AppIcon1024.png --out "AppIcon1024 17.png" # 83.5pt@2x

# Move generated icons to asset catalog
mv *.png ../Faith\ Journal/Assets.xcassets/AppIcon.appiconset/

# Clean up
cd ..
rmdir tmp_icons 