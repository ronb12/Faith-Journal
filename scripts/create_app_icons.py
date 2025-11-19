#!/usr/bin/env python3
"""
Create app icons for Faith Journal app
Purple and white theme with praying hands design
"""

from PIL import Image, ImageDraw, ImageFont
import os
import math

# Purple color palette
PURPLE_DARK = (75, 0, 130)  # Indigo purple
PURPLE_MEDIUM = (138, 43, 226)  # Blue violet
PURPLE_LIGHT = (186, 85, 211)  # Medium orchid
WHITE = (255, 255, 255)
CREAM = (255, 250, 240)  # Slight cream for warmth

def draw_praying_hands(draw, center_x, center_y, size, color):
    """Draw stylized praying hands"""
    # Hand dimensions
    hand_width = int(size * 0.35)
    hand_height = int(size * 0.5)
    
    # Calculate position - hands together in center
    left_hand_x = center_x - hand_width // 2 - int(size * 0.02)
    right_hand_x = center_x + int(size * 0.02)
    hands_top = center_y - hand_height // 2
    
    # Draw shadow for depth
    shadow_offset = max(2, int(size * 0.015))
    shadow_color = tuple(max(0, c - 80) for c in color[:3]) if len(color) >= 3 else (150, 150, 150)
    
    # Draw left hand (shadow)
    left_shadow_points = []
    right_shadow_points = []
    
    # Simplified hand shape - create points for palm and fingers
    # Palm/base
    palm_width = int(hand_width * 0.5)
    palm_height = int(hand_height * 0.4)
    
    # Fingers
    finger_count = 4
    finger_width = int(hand_width * 0.15)
    finger_spacing = int(hand_width * 0.1)
    
    # Left hand points
    for i in range(finger_count):
        finger_x = left_hand_x + int(hand_width * 0.25) + i * (finger_width + finger_spacing)
        finger_top = hands_top
        finger_bottom = hands_top + int(hand_height * 0.6)
        
        # Draw finger with rounded top
        finger_center_x = finger_x + finger_width // 2
        draw.ellipse(
            [finger_center_x - finger_width // 2 + shadow_offset, finger_top + shadow_offset,
             finger_center_x + finger_width // 2 + shadow_offset, finger_top + finger_width + shadow_offset],
            fill=shadow_color,
            outline=None
        )
        draw.rectangle(
            [finger_x + shadow_offset, finger_top + finger_width // 2 + shadow_offset,
             finger_x + finger_width + shadow_offset, finger_bottom + shadow_offset],
            fill=shadow_color,
            outline=None
        )
    
    # Left hand palm
    draw.ellipse(
        [left_hand_x + shadow_offset, hands_top + int(hand_height * 0.4) + shadow_offset,
         left_hand_x + palm_width + shadow_offset, hands_top + hand_height + shadow_offset],
        fill=shadow_color,
        outline=None
    )
    
    # Right hand (mirrored)
    for i in range(finger_count):
        finger_x = right_hand_x + int(hand_width * 0.1) - i * (finger_width + finger_spacing)
        finger_top = hands_top
        finger_bottom = hands_top + int(hand_height * 0.6)
        
        finger_center_x = finger_x + finger_width // 2
        draw.ellipse(
            [finger_center_x - finger_width // 2 + shadow_offset, finger_top + shadow_offset,
             finger_center_x + finger_width // 2 + shadow_offset, finger_top + finger_width + shadow_offset],
            fill=shadow_color,
            outline=None
        )
        draw.rectangle(
            [finger_x + shadow_offset, finger_top + finger_width // 2 + shadow_offset,
             finger_x + finger_width + shadow_offset, finger_bottom + shadow_offset],
            fill=shadow_color,
            outline=None
        )
    
    # Right hand palm
    draw.ellipse(
        [right_hand_x + hand_width - palm_width + shadow_offset, hands_top + int(hand_height * 0.4) + shadow_offset,
         right_hand_x + hand_width + shadow_offset, hands_top + hand_height + shadow_offset],
        fill=shadow_color,
        outline=None
    )
    
    # Draw left hand (main)
    for i in range(finger_count):
        finger_x = left_hand_x + int(hand_width * 0.25) + i * (finger_width + finger_spacing)
        finger_top = hands_top
        finger_bottom = hands_top + int(hand_height * 0.6)
        
        # Draw finger with rounded top
        finger_center_x = finger_x + finger_width // 2
        # Rounded top
        draw.ellipse(
            [finger_center_x - finger_width // 2, finger_top,
             finger_center_x + finger_width // 2, finger_top + finger_width],
            fill=color,
            outline=None
        )
        # Finger body
        draw.rectangle(
            [finger_x, finger_top + finger_width // 2,
             finger_x + finger_width, finger_bottom],
            fill=color,
            outline=None
        )
    
    # Left hand palm
    draw.ellipse(
        [left_hand_x, hands_top + int(hand_height * 0.4),
         left_hand_x + palm_width, hands_top + hand_height],
        fill=color,
        outline=None
    )
    
    # Draw right hand (main, mirrored)
    for i in range(finger_count):
        finger_x = right_hand_x + int(hand_width * 0.1) - i * (finger_width + finger_spacing)
        finger_top = hands_top
        finger_bottom = hands_top + int(hand_height * 0.6)
        
        finger_center_x = finger_x + finger_width // 2
        # Rounded top
        draw.ellipse(
            [finger_center_x - finger_width // 2, finger_top,
             finger_center_x + finger_width // 2, finger_top + finger_width],
            fill=color,
            outline=None
        )
        # Finger body
        draw.rectangle(
            [finger_x, finger_top + finger_width // 2,
             finger_x + finger_width, finger_bottom],
            fill=color,
            outline=None
        )
    
    # Right hand palm
    draw.ellipse(
        [right_hand_x + hand_width - palm_width, hands_top + int(hand_height * 0.4),
         right_hand_x + hand_width, hands_top + hand_height],
        fill=color,
        outline=None
    )
    
    # Draw wrists connection (where hands meet)
    wrist_width = int(size * 0.08)
    wrist_height = int(hand_height * 0.15)
    wrist_top = hands_top + int(hand_height * 0.85)
    
    draw.ellipse(
        [center_x - wrist_width // 2, wrist_top,
         center_x + wrist_width // 2, wrist_top + wrist_height],
        fill=color,
        outline=None
    )
    
    # Add subtle lines between fingers for detail (on larger sizes)
    if size >= 100:
        line_color = tuple(max(0, c - 30) for c in color[:3]) if len(color) >= 3 else (200, 200, 200)
        for i in range(finger_count - 1):
            # Left hand finger separation
            line_x = left_hand_x + int(hand_width * 0.25) + (i + 1) * (finger_width + finger_spacing)
            draw.line(
                [(line_x, hands_top + finger_width),
                 (line_x, hands_top + int(hand_height * 0.5))],
                fill=line_color,
                width=max(1, int(size * 0.003))
            )
            
            # Right hand finger separation
            line_x = right_hand_x + int(hand_width * 0.1) - (i + 1) * (finger_width + finger_spacing)
            draw.line(
                [(line_x, hands_top + finger_width),
                 (line_x, hands_top + int(hand_height * 0.5))],
                fill=line_color,
                width=max(1, int(size * 0.003))
            )

def create_icon(size, filename):
    """Create an app icon of specified size"""
    # Create image with purple gradient background
    img = Image.new('RGB', (size, size), PURPLE_DARK)
    draw = ImageDraw.Draw(img)
    
    # Create gradient effect (simplified)
    for y in range(size):
        ratio = y / size
        r = int(PURPLE_DARK[0] * (1 - ratio * 0.3) + PURPLE_MEDIUM[0] * ratio * 0.3)
        g = int(PURPLE_DARK[1] * (1 - ratio * 0.3) + PURPLE_MEDIUM[1] * ratio * 0.3)
        b = int(PURPLE_DARK[2] * (1 - ratio * 0.3) + PURPLE_MEDIUM[2] * ratio * 0.3)
        draw.line([(0, y), (size, y)], fill=(r, g, b))
    
    # Draw praying hands (in upper portion)
    hands_center_y = int(size * 0.4)
    draw_praying_hands(draw, size // 2, hands_center_y, size, WHITE)
    
    # Try to use system font, fallback to default
    try:
        # Try to find a nice font
        font_size_large = max(12, int(size * 0.13))
        font_size_small = max(8, int(size * 0.09))
        
        # Try different font paths
        font_paths = [
            '/System/Library/Fonts/Helvetica.ttc',
            '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
            '/Library/Fonts/Arial.ttf',
        ]
        
        font_large = None
        font_small = None
        
        for font_path in font_paths:
            try:
                if os.path.exists(font_path):
                    font_large = ImageFont.truetype(font_path, font_size_large)
                    font_small = ImageFont.truetype(font_path, font_size_small)
                    break
            except:
                pass
        
        if font_large is None:
            font_large = ImageFont.load_default()
            font_small = ImageFont.load_default()
    except:
        font_large = ImageFont.load_default()
        font_small = ImageFont.load_default()
    
    # Add text "Faith Journal" underneath the hands
    text_y = int(size * 0.72)
    
    # Get text dimensions
    try:
        bbox = draw.textbbox((0, 0), "FAITH", font=font_large)
        text_width = bbox[2] - bbox[0]
        text_x = (size - text_width) // 2
        draw.text((text_x, text_y), "FAITH", fill=WHITE, font=font_large, anchor="lt")
        
        bbox2 = draw.textbbox((0, 0), "JOURNAL", font=font_small)
        text_width2 = bbox2[2] - bbox2[0]
        text_x2 = (size - text_width2) // 2
        text_y2 = text_y + int(size * 0.16)
        draw.text((text_x2, text_y2), "JOURNAL", fill=CREAM, font=font_small, anchor="lt")
    except:
        # Fallback if text drawing fails
        text = "FAITH\nJOURNAL"
        text_x = size // 2
        draw.multiline_text((text_x, text_y), text, fill=WHITE, font=font_large, anchor="mm", align="center")
    
    # Save the icon
    iconset_path = "/Users/ronellbradley/Desktop/Faith Journal/Faith Journal/Resources/Assets.xcassets/AppIcon.appiconset"
    output_path = f"{iconset_path}/{filename}"
    img.save(output_path, 'PNG')
    print(f"Created: {filename} ({size}x{size})")

def main():
    """Create all required app icon sizes"""
    iconset_path = "/Users/ronellbradley/Desktop/Faith Journal/Faith Journal/Resources/Assets.xcassets/AppIcon.appiconset"
    
    # Ensure directory exists
    os.makedirs(iconset_path, exist_ok=True)
    
    # Define all required icon sizes based on Contents.json
    icon_sizes = [
        # iPad icons
        (20, "AppIcon-20x20.png"),
        (40, "AppIcon-20x20@2x.png"),  # 20pt @2x = 40px
        (29, "AppIcon-29x29.png"),
        (58, "AppIcon-29x29@2x.png"),  # 29pt @2x = 58px
        (40, "AppIcon-40x40.png"),
        (80, "AppIcon-40x40@2x.png"),  # 40pt @2x = 80px
        (76, "AppIcon-76x76.png"),
        (152, "AppIcon-76x76@2x.png"),  # 76pt @2x = 152px
        (167, "AppIcon-83.5x83.5@2x.png"),  # 83.5pt @2x = 167px
        
        # iPhone icons
        (58, "AppIcon-29x29@2x.png"),  # 29pt @2x = 58px (same as iPad)
        (87, "AppIcon-29x29@3x.png"),  # 29pt @3x = 87px
        (80, "AppIcon-40x40@2x.png"),  # 40pt @2x = 80px (same as iPad)
        (120, "AppIcon-40x40@3x.png"),  # 40pt @3x = 120px
        (120, "AppIcon-60x60@2x.png"),  # 60pt @2x = 120px (REQUIRED)
        (180, "AppIcon-60x60@3x.png"),  # 60pt @3x = 180px
        
        # App Store
        (1024, "AppIcon-1024x1024.png"),  # REQUIRED
    ]
    
    # Remove duplicates (some filenames are used multiple times)
    seen = set()
    unique_sizes = []
    for size, filename in icon_sizes:
        if filename not in seen:
            seen.add(filename)
            unique_sizes.append((size, filename))
    
    print("Creating app icons for Faith Journal...")
    print(f"Output directory: {iconset_path}\n")
    
    for size, filename in unique_sizes:
        create_icon(size, filename)
    
    print(f"\n✅ Successfully created {len(unique_sizes)} icon files!")
    print("Icons are ready in the AppIcon.appiconset folder.")

if __name__ == "__main__":
    main()
