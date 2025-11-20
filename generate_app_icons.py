#!/usr/bin/env python3
"""
Echoelmusic App Icon Generator
Generates all required iOS app icon sizes with a professional gradient design
"""

from PIL import Image, ImageDraw, ImageFont
import os
import math

# Icon sizes required for iOS
ICON_SIZES = {
    # iPhone
    "icon-20@2x.png": 40,
    "icon-20@3x.png": 60,
    "icon-29@2x.png": 58,
    "icon-29@3x.png": 87,
    "icon-40@2x.png": 80,
    "icon-40@3x.png": 120,
    "icon-60@2x.png": 120,
    "icon-60@3x.png": 180,

    # iPad
    "icon-20.png": 20,
    "icon-20@2x-ipad.png": 40,
    "icon-29.png": 29,
    "icon-29@2x-ipad.png": 58,
    "icon-40.png": 40,
    "icon-40@2x-ipad.png": 80,
    "icon-76.png": 76,
    "icon-76@2x.png": 152,
    "icon-83.5@2x.png": 167,

    # App Store
    "icon-1024.png": 1024,
}

def create_gradient_background(size):
    """Create a beautiful gradient background"""
    image = Image.new('RGB', (size, size))
    draw = ImageDraw.Draw(image)

    # Professional blue-purple gradient
    for y in range(size):
        # Calculate color based on position
        ratio = y / size

        # Start color (vibrant blue)
        r1, g1, b1 = 41, 128, 185  # #2980b9

        # End color (deep purple)
        r2, g2, b2 = 142, 68, 173  # #8e44ad

        # Interpolate
        r = int(r1 + (r2 - r1) * ratio)
        g = int(g1 + (g2 - g1) * ratio)
        b = int(b1 + (b2 - b1) * ratio)

        draw.line([(0, y), (size, y)], fill=(r, g, b))

    return image

def draw_waveform(draw, size, color=(255, 255, 255, 200)):
    """Draw a stylized audio waveform"""
    center_y = size // 2
    points = []

    # Generate waveform points
    for x in range(0, size, 2):
        # Create a smooth waveform
        angle = (x / size) * 4 * math.pi
        amplitude = size * 0.15
        y = center_y + int(math.sin(angle) * amplitude)
        points.append((x, y))

    # Draw the waveform
    if len(points) > 1:
        draw.line(points, fill=color, width=max(2, size // 100))

def draw_heart_icon(draw, size, color=(255, 105, 180, 200)):
    """Draw a simple heart icon for bio-reactive feature"""
    center_x = size // 2
    center_y = size * 0.35
    heart_size = size * 0.15

    # Simple heart shape (two circles + triangle)
    # Left circle
    left_x = center_x - heart_size * 0.5
    draw.ellipse([
        left_x - heart_size, center_y - heart_size,
        left_x + heart_size, center_y + heart_size
    ], fill=color)

    # Right circle
    right_x = center_x + heart_size * 0.5
    draw.ellipse([
        right_x - heart_size, center_y - heart_size,
        right_x + heart_size, center_y + heart_size
    ], fill=color)

    # Triangle
    bottom_y = center_y + heart_size * 2.5
    draw.polygon([
        (center_x - heart_size * 1.5, center_y),
        (center_x + heart_size * 1.5, center_y),
        (center_x, bottom_y)
    ], fill=color)

def draw_musical_notes(draw, size, color=(255, 255, 255, 180)):
    """Draw musical notes"""
    note_size = size * 0.12

    # Note 1 (bottom left)
    x1, y1 = size * 0.25, size * 0.7
    draw.ellipse([x1 - note_size * 0.4, y1 - note_size * 0.4,
                  x1 + note_size * 0.4, y1 + note_size * 0.4], fill=color)
    draw.rectangle([x1 + note_size * 0.3, y1 - note_size * 1.5,
                    x1 + note_size * 0.5, y1], fill=color)

    # Note 2 (bottom right)
    x2, y2 = size * 0.75, size * 0.75
    draw.ellipse([x2 - note_size * 0.4, y2 - note_size * 0.4,
                  x2 + note_size * 0.4, y2 + note_size * 0.4], fill=color)
    draw.rectangle([x2 + note_size * 0.3, y2 - note_size * 1.8,
                    x2 + note_size * 0.5, y2], fill=color)

def create_app_icon(size):
    """Create a complete app icon at the specified size"""
    # Create gradient background
    image = create_gradient_background(size)
    draw = ImageDraw.Draw(image, 'RGBA')

    # Draw waveform
    draw_waveform(draw, size)

    # Draw heart icon (bio-reactive feature)
    draw_heart_icon(draw, size)

    # Draw musical notes
    draw_musical_notes(draw, size)

    # Add text for larger icons (1024px)
    if size >= 512:
        try:
            # Try to use a system font
            font_size = size // 12
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", font_size)
        except:
            font = ImageFont.load_default()

        text = "E"
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]

        text_x = (size - text_width) // 2
        text_y = size * 0.55

        # Draw text with shadow
        shadow_offset = max(2, size // 200)
        draw.text((text_x + shadow_offset, text_y + shadow_offset), text,
                  font=font, fill=(0, 0, 0, 100))
        draw.text((text_x, text_y), text, font=font, fill=(255, 255, 255, 255))

    return image

def generate_all_icons(output_dir):
    """Generate all required icon sizes"""
    os.makedirs(output_dir, exist_ok=True)

    print("🎨 Generating Echoelmusic app icons...")
    print(f"Output directory: {output_dir}")
    print()

    for filename, size in ICON_SIZES.items():
        print(f"  Creating {filename} ({size}x{size}px)...")
        icon = create_app_icon(size)

        # Apply corner radius for iOS icons (except 1024px)
        if size < 1024:
            # iOS uses rounded corners with specific radius
            radius = int(size * 0.2235)  # Apple's corner radius formula
            mask = Image.new('L', (size, size), 0)
            mask_draw = ImageDraw.Draw(mask)
            mask_draw.rounded_rectangle([(0, 0), (size, size)], radius=radius, fill=255)

            # Create rounded icon
            output = Image.new('RGBA', (size, size), (0, 0, 0, 0))
            output.paste(icon, (0, 0))
            output.putalpha(mask)
            icon = output

        # Save the icon
        filepath = os.path.join(output_dir, filename)
        icon.save(filepath, 'PNG')

    print()
    print(f"✅ Successfully generated {len(ICON_SIZES)} app icons!")
    print()
    print("Next steps:")
    print("1. Review the generated icons")
    print("2. (Optional) Replace with custom-designed icons")
    print("3. Build the app in Xcode")

if __name__ == '__main__':
    # Output to the Assets.xcassets directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_directory = os.path.join(script_dir, 'Assets.xcassets', 'AppIcon.appiconset')

    try:
        generate_all_icons(output_directory)
    except ImportError as e:
        if 'PIL' in str(e):
            print("❌ Error: Pillow (PIL) library not installed")
            print()
            print("To install Pillow, run:")
            print("  pip3 install Pillow")
            print()
            print("Or using conda:")
            print("  conda install pillow")
        else:
            raise
    except Exception as e:
        print(f"❌ Error generating icons: {e}")
        import traceback
        traceback.print_exc()
