#!/bin/bash
# Fix screenshots: add macOS window frame, scale-to-fit content (no cutoff), output 1280x800

set -e
OUTPUT_DIR="${1:-$HOME/Desktop/AppStore-Screenshots}"
mkdir -p "$OUTPUT_DIR"

# Content area (below title bar): 1280 x 730
CONTENT_W=1280
CONTENT_H=730
TITLE_H=38
TOTAL_W=1280
TOTAL_H=800

# macOS title bar colors (dark mode - matches Faith Journal)
TITLE_BG="#2d2d2d"
RED="#ff5f57"
YELLOW="#febc2e"
GREEN="#28c840"

fix_one() {
  local input="$1"
  local base=$(basename "$input" | sed 's/-[a-f0-9-]*\.png$//' | sed 's/_/ /g')
  local output="$OUTPUT_DIR/${base}.png"
  
  [ -f "$input" ] || return 1
  
  # Create temp files
  local tmp_content=$(mktemp).png
  local tmp_title=$(mktemp).png
  local tmp_composite=$(mktemp).png
  trap "rm -f ${tmp_content} ${tmp_title} ${tmp_composite}" RETURN
  
  # 1. Scale content to FIT within content area (no crop - letterbox with dark bg)
  magick "$input" -resize ${CONTENT_W}x${CONTENT_H}\> -background '#1a1a1a' -gravity center -extent ${CONTENT_W}x${CONTENT_H} "$tmp_content"
  
  # 2. Create macOS title bar with traffic lights (red, yellow, green)
  magick -size ${TOTAL_W}x${TITLE_H} xc:"$TITLE_BG" \
    -fill "$RED"    -draw "circle 20,19 26,19" \
    -fill "$YELLOW" -draw "circle 44,19 50,19" \
    -fill "$GREEN"  -draw "circle 68,19 74,19" \
    "$tmp_title"
  
  # 3. Stack title bar + content
  magick "$tmp_title" "$tmp_content" -append "$tmp_composite"
  
  # 4. Fit to 1280x800 with letterbox (light gray background)
  magick "$tmp_composite" \
    -resize ${TOTAL_W}x${TOTAL_H}\> -background '#e8e8ed' -gravity center -extent ${TOTAL_W}x${TOTAL_H} \
    "$output"
  
  echo "Fixed: $output"
}

# Process the 4 screenshots from assets
ASSETS="/Users/ronellbradley/.cursor/projects/Users-ronellbradley-Projects-Faith-Journal/assets"
for f in \
  "$ASSETS/Screenshot_2026-02-15_at_8.10.47_AM-fe15beb1-79c4-4791-a76b-be9e512b70b5.png" \
  "$ASSETS/Screenshot_2026-02-15_at_8.10.57_AM-bb018f2c-858b-47c7-96d3-72280128064a.png" \
  "$ASSETS/Screenshot_2026-02-15_at_8.11.18_AM-c27998bc-6b5b-41c7-a1bb-63c22c10a6a8.png" \
  "$ASSETS/Screenshot_2026-02-15_at_8.11.25_AM-b474ce50-6e4c-4fb7-ae9e-4d63ca1eb10a.png"; do
  fix_one "$f" || true
done

# Also process any in AppStore-Screenshots that need fixing
for f in "$OUTPUT_DIR"/*.png; do
  [ -f "$f" ] || continue
  # Skip if already processed by assets (avoid double process)
  [[ "$f" == *"Screenshot 2026-02-15"* ]] && continue
  # Could add more source files here
done

echo ""
echo "Done. Screenshots saved to: $OUTPUT_DIR"
