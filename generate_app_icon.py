#!/usr/bin/env python3
"""
Generate app icon with cross and "Faith Journal" text
"""
from PIL import Image, ImageDraw, ImageFont
import os
import sys

# Purple color from theme: Color(red: 0.4, green: 0.2, blue: 0.8)
PURPLE_RGB = (102, 51, 204)
WHITE_RGB = (255, 255, 255)

def create_app_icon(size, output_path):
    """Create an app icon with smaller cross and fancy text"""
    # Create image with purple background
    img = Image.new('RGB', (size, size), PURPLE_RGB)
    draw = ImageDraw.Draw(img)
    
    # Smaller, more subtle cross
    cross_thickness = max(size // 10, 4)  # Thinner cross
    center = size // 2
    cross_length = size // 3  # Shorter cross arms
    
    # Draw smaller cross in upper portion
    cross_y = size // 3  # Position cross in upper third
    # Vertical line
    draw.rectangle(
        [center - cross_thickness // 2, cross_y - cross_length // 2, 
         center + cross_thickness // 2, cross_y + cross_length // 2],
        fill=WHITE_RGB
    )
    # Horizontal line
    draw.rectangle(
        [center - cross_length // 2, cross_y - cross_thickness // 2,
         center + cross_length // 2, cross_y + cross_thickness // 2],
        fill=WHITE_RGB
    )
    
    # Add fancy text "Faith Journal" - make it prominent
    # Scale font size based on icon size - make text larger
    font_size = max(size // 5, 12)  # Larger base font size
    bold_font_size = max(size // 4, 14)  # Even larger for emphasis
    
    # Try to find elegant fonts (serif fonts look fancier)
    font = None
    bold_font = None
    
    # Try various fancy system fonts
    font_paths = [
        # macOS/iOS elegant fonts
        "/System/Library/Fonts/Supplemental/Georgia.ttf",
        "/System/Library/Fonts/Supplemental/Palatino.ttc",
        "/System/Library/Fonts/Supplemental/Baskerville.ttc",
        "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
        "/System/Library/Fonts/Supplemental/Apple Chancery.ttf",
        # Standard fonts with different weights
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    
    for font_path in font_paths:
        try:
            font = ImageFont.truetype(font_path, font_size)
            bold_font = ImageFont.truetype(font_path, bold_font_size)
            break
        except:
            continue
    
    if font is None:
        # Fallback to default font
        font = ImageFont.load_default()
        bold_font = font
    
    # Text positioning - make it prominent in center/lower area
    if size >= 120:
        text_lines = ["Faith", "Journal"]
        line_spacing = max(font_size // 3, 4)
        total_text_height = (bold_font_size * len(text_lines)) + (line_spacing * (len(text_lines) - 1))
    else:
        # For very small icons, use initials
        text_lines = ["FJ"]
        total_text_height = bold_font_size
    
    # Center text vertically in lower 2/3 of icon
    text_y_start = size * 2 // 3 - total_text_height // 2
    
    for i, line in enumerate(text_lines):
        # Use bold font for "Faith", regular for "Journal"
        current_font = bold_font if i == 0 else font
        current_size = bold_font_size if i == 0 else font_size
        
        # Get text dimensions
        bbox = draw.textbbox((0, 0), line, font=current_font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        
        # Center text horizontally
        text_x = (size - text_width) // 2
        
        # Calculate y position
        if i == 0:
            text_y = text_y_start
        else:
            text_y = text_y_start + bold_font_size + line_spacing
        
        # Draw text shadow for depth (slight offset)
        shadow_offset = max(size // 100, 1)
        draw.text((text_x + shadow_offset, text_y + shadow_offset), line, 
                 fill=(60, 30, 120), font=current_font)  # Darker purple shadow
        
        # Draw main text in white
        draw.text((text_x, text_y), line, fill=WHITE_RGB, font=current_font)
    
    # Save icon
    img.save(output_path, 'PNG')
    print(f"Created {output_path} ({size}x{size})")

def main():
    # Icon sizes needed (in points, @1x, @2x, @3x)
    icon_sizes = {
        # iPhone App Icons
        "AppIcon-20x20.png": 20,
        "AppIcon-20x20@2x.png": 40,
        "AppIcon-29x29.png": 29,
        "AppIcon-29x29@2x.png": 58,
        "AppIcon-29x29@3x.png": 87,
        "AppIcon-40x40.png": 40,
        "AppIcon-40x40@2x.png": 80,
        "AppIcon-40x40@3x.png": 120,
        "AppIcon-60x60@2x.png": 120,
        "AppIcon-60x60@3x.png": 180,
        
        # iPad App Icons
        "AppIcon-76x76.png": 76,
        "AppIcon-76x76@2x.png": 152,
        "AppIcon-83.5x83.5@2x.png": 167,
        
        # App Store
        "AppIcon-1024x1024.png": 1024,
    }
    
    # Output directory
    output_dir = "Faith Journal/Faith Journal/Resources/Assets.xcassets/AppIcon.appiconset"
    
    if not os.path.exists(output_dir):
        # Try alternative path
        output_dir = "Faith Journal/Faith Journal/Faith Journal/Resources/Assets.xcassets/AppIcon.appiconset"
    
    if not os.path.exists(output_dir):
        print(f"Error: AppIcon directory not found. Tried: {output_dir}")
        sys.exit(1)
    
    # Generate all icon sizes
    for filename, size in icon_sizes.items():
        output_path = os.path.join(output_dir, filename)
        create_app_icon(size, output_path)
    
    print("\nAll app icons generated successfully!")

if __name__ == "__main__":
    main()
