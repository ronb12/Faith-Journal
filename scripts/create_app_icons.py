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
    
    # Draw praying ha