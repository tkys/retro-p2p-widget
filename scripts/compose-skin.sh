#!/bin/bash
# Compose widget background images from Winamp .wsz skin parts
# Usage: ./scripts/compose-skin.sh <extracted_wsz_dir> <output_skin_name>
#
# Requires: ImageMagick (magick/magick)
#
# Produces 3 sizes per skin:
#   - bg-small.png   (169×169 pt equivalent, rendered at 338×338 @2x)
#   - bg-medium.png  (360×169 pt equivalent, rendered at 720×338 @2x)
#   - bg-large.png   (360×376 pt equivalent, rendered at 720×752 @2x)

set -euo pipefail

SRC="${1:?Usage: $0 <wsz_extracted_dir> <skin_name>}"
NAME="${2:?Usage: $0 <wsz_extracted_dir> <skin_name>}"
OUTDIR="Shared/Resources/Skins/${NAME}"

mkdir -p "$OUTDIR"

# --- Resolve case-insensitive filenames ---
find_bmp() {
    local base="$1"
    find "$SRC" -maxdepth 2 -iname "${base}" -print -quit 2>/dev/null
}

MAIN_BMP=$(find_bmp "main.bmp")
TITLEBAR_BMP=$(find_bmp "titlebar.bmp")
CBUTTONS_BMP=$(find_bmp "cbuttons.bmp")
POSBAR_BMP=$(find_bmp "posbar.bmp")
VOLUME_BMP=$(find_bmp "volume.bmp")
SHUFREP_BMP=$(find_bmp "shufrep.bmp")
NUMBERS_BMP=$(find_bmp "numbers.bmp")
NUMS_EX_BMP=$(find_bmp "nums_ex.bmp")
MONOSTER_BMP=$(find_bmp "monoster.bmp")
TEXT_BMP=$(find_bmp "text.bmp")

if [ -z "$MAIN_BMP" ]; then
    echo "ERROR: main.bmp not found in $SRC"
    exit 1
fi

echo "=== Composing skin: $NAME ==="
echo "Source: $SRC"

# --- Convert core assets to PNG ---
convert_png() {
    local src="$1" dst="$2"
    if [ -n "$src" ] && [ -f "$src" ]; then
        magick "$src" PNG32:"$dst"
        echo "  Converted: $(basename "$dst")"
    fi
}

convert_png "$MAIN_BMP" "$OUTDIR/main.png"
[ -n "$TITLEBAR_BMP" ] && convert_png "$TITLEBAR_BMP" "$OUTDIR/titlebar.png"

# Numbers: prefer nums_ex.bmp, fall back to numbers.bmp
if [ -n "$NUMS_EX_BMP" ] && [ -f "$NUMS_EX_BMP" ]; then
    convert_png "$NUMS_EX_BMP" "$OUTDIR/numbers.png"
elif [ -n "$NUMBERS_BMP" ] && [ -f "$NUMBERS_BMP" ]; then
    convert_png "$NUMBERS_BMP" "$OUTDIR/numbers.png"
fi

# --- Extract sprite regions ---

# Titlebar active state: first row, 275×14 from titlebar.bmp (top-left)
if [ -n "$TITLEBAR_BMP" ] && [ -f "$TITLEBAR_BMP" ]; then
    magick "$TITLEBAR_BMP" -crop 275x14+0+0 +repage PNG32:"$OUTDIR/_titlebar_active.png"
fi

# Control buttons: normal state, first row 136×18
if [ -n "$CBUTTONS_BMP" ] && [ -f "$CBUTTONS_BMP" ]; then
    magick "$CBUTTONS_BMP" -crop 136x18+0+0 +repage PNG32:"$OUTDIR/_cbuttons.png"
fi

# Position bar background: 248×10 crop
if [ -n "$POSBAR_BMP" ] && [ -f "$POSBAR_BMP" ]; then
    magick "$POSBAR_BMP" -crop 248x10+0+0 +repage PNG32:"$OUTDIR/_posbar.png"
fi

# Volume bar: single state, first row 68×13
if [ -n "$VOLUME_BMP" ] && [ -f "$VOLUME_BMP" ]; then
    magick "$VOLUME_BMP" -crop 68x13+0+0 +repage PNG32:"$OUTDIR/_volume.png"
fi

# Shuffle/Repeat: extract shuffle (47×15) and repeat (28×15) from first row
if [ -n "$SHUFREP_BMP" ] && [ -f "$SHUFREP_BMP" ]; then
    magick "$SHUFREP_BMP" -crop 47x15+0+0 +repage PNG32:"$OUTDIR/_shuffle.png"
    magick "$SHUFREP_BMP" -crop 28x15+0+15 +repage PNG32:"$OUTDIR/_repeat.png"
fi

# Mono/Stereo indicator
if [ -n "$MONOSTER_BMP" ] && [ -f "$MONOSTER_BMP" ]; then
    magick "$MONOSTER_BMP" -crop 58x12+0+0 +repage PNG32:"$OUTDIR/_monoster.png"
fi

# --- Detect background color from main.bmp ---
# Sample multiple interior pixels and pick the most common non-magenta color
# Avoids transparent key colors like #FF00FF/#FF01FF
BG_COLOR=$(magick "$MAIN_BMP" -crop 1x1+140+100 +repage -format "%[hex:u.p{0,0}]" info: 2>/dev/null || echo "2B2B2B")
# Strip alpha suffix if 8-char hex (e.g. "003D00FF" → "003D00")
BG_COLOR="${BG_COLOR:0:6}"
# Check for magenta (transparency key) and fall back to darker sample
if [[ "$BG_COLOR" == "FF00FF" ]] || [[ "$BG_COLOR" == "FF01FF" ]]; then
    BG_COLOR=$(magick "$MAIN_BMP" -crop 1x1+20+60 +repage -format "%[hex:u.p{0,0}]" info: 2>/dev/null || echo "2B2B2B")
    BG_COLOR="${BG_COLOR:0:6}"
fi
if [[ "$BG_COLOR" == "FF00FF" ]] || [[ "$BG_COLOR" == "FF01FF" ]]; then
    BG_COLOR="2B2B2B"
fi

echo "  Background color: #$BG_COLOR"

# =============================================
# systemMedium: 720×338 @2x (360×169 pt)
# Strategy: Scale main.bmp (275×116) to fill width, center vertically
# =============================================
echo "  Composing bg-medium.png (720x338)..."
SCALE_M=$(echo "scale=4; 720 / 275" | bc)  # ~2.618x

magick "$MAIN_BMP" \
    -filter Point -resize "720x" \
    -gravity center -background "#${BG_COLOR}" -extent 720x338 \
    PNG32:"$OUTDIR/bg-medium.png"

# =============================================
# systemSmall: 338×338 @2x (169×169 pt)
# Strategy: Crop center region of main.bmp (display area), scale up
# =============================================
echo "  Composing bg-small.png (338x338)..."

# Crop the display area from main.bmp: roughly 120×116 center portion
magick "$MAIN_BMP" \
    -crop 130x116+0+0 +repage \
    -filter Point -resize "338x338!" \
    -background "#${BG_COLOR}" -extent 338x338 \
    PNG32:"$OUTDIR/bg-small.png"

# =============================================
# systemLarge: 720×752 @2x (360×376 pt)
# Strategy: Full Winamp UI assembly at ~2.6x scale
#   - Titlebar (275×14 → 720×37)
#   - Main body (275×116 → 720×304)
#   - Extra: tiled background or additional elements
# =============================================
echo "  Composing bg-large.png (720x752)..."

# Scale main.bmp to 720 wide
magick "$MAIN_BMP" \
    -filter Point -resize "720x" \
    PNG32:"$OUTDIR/_main_scaled.png"

MAIN_H=$(identify -format "%h" "$OUTDIR/_main_scaled.png")

# Create canvas and composite
magick -size 720x752 "xc:#${BG_COLOR}" \
    "$OUTDIR/_main_scaled.png" -gravity North -geometry +0+0 -composite \
    PNG32:"$OUTDIR/bg-large.png"

# If we have extra parts, overlay them below main
Y_OFFSET=$MAIN_H

# Posbar below main
if [ -f "$OUTDIR/_posbar.png" ]; then
    magick "$OUTDIR/_posbar.png" -filter Point -resize "660x" PNG32:"$OUTDIR/_posbar_scaled.png"
    PB_H=$(identify -format "%h" "$OUTDIR/_posbar_scaled.png")
    magick "$OUTDIR/bg-large.png" \
        "$OUTDIR/_posbar_scaled.png" -gravity NorthWest -geometry "+30+${Y_OFFSET}" -composite \
        PNG32:"$OUTDIR/bg-large.png"
    Y_OFFSET=$((Y_OFFSET + PB_H + 8))
fi

# Control buttons
if [ -f "$OUTDIR/_cbuttons.png" ]; then
    magick "$OUTDIR/_cbuttons.png" -filter Point -resize "360x" PNG32:"$OUTDIR/_cbuttons_scaled.png"
    CB_H=$(identify -format "%h" "$OUTDIR/_cbuttons_scaled.png")
    magick "$OUTDIR/bg-large.png" \
        "$OUTDIR/_cbuttons_scaled.png" -gravity NorthWest -geometry "+30+${Y_OFFSET}" -composite \
        PNG32:"$OUTDIR/bg-large.png"
    Y_OFFSET=$((Y_OFFSET + CB_H + 8))
fi

# Shuffle/Repeat
if [ -f "$OUTDIR/_shuffle.png" ] && [ -f "$OUTDIR/_repeat.png" ]; then
    magick "$OUTDIR/_shuffle.png" "$OUTDIR/_repeat.png" +append -filter Point -resize "200x" PNG32:"$OUTDIR/_shurep_scaled.png"
    magick "$OUTDIR/bg-large.png" \
        "$OUTDIR/_shurep_scaled.png" -gravity NorthWest -geometry "+420+$((Y_OFFSET - CB_H - 8))" -composite \
        PNG32:"$OUTDIR/bg-large.png"
fi

# --- Cleanup temp files ---
rm -f "$OUTDIR"/_*.png

echo "=== Done: $OUTDIR ==="
echo "  bg-small.png  (338x338)"
echo "  bg-medium.png (720x338)"
echo "  bg-large.png  (720x752)"
echo "  main.png      (original)"
echo "  numbers.png   (sprite sheet)"
ls -la "$OUTDIR"/*.png
