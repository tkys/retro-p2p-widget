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

# --- Hex color helpers (portable, no GNU awk needed) ---
# Convert 6-digit hex to "R G B" decimal string
hex_to_rgb() {
    printf '%d %d %d' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"
}

# Darken a hex color by factor (0-100, where 50 = half brightness)
darken_hex() {
    local hex="$1" factor="$2"
    local rgb
    rgb=$(hex_to_rgb "$hex")
    echo "$rgb" | awk -v f="$factor" '{printf "#%02X%02X%02X", int($1*f/100), int($2*f/100), int($3*f/100)}'
}

# Brighten a hex color (add offset, clamp to 255)
brighten_hex() {
    local hex="$1" offset="$2"
    local rgb
    rgb=$(hex_to_rgb "$hex")
    echo "$rgb" | awk -v o="$offset" '{
        r=$1+o; g=$2+o; b=$3+o;
        printf "#%02X%02X%02X", (r>255?255:r), (g>255?255:g), (b>255?255:b)
    }'
}

# --- Resolve case-insensitive filenames ---
# Looks for exact name first, then .png equivalent (for re-running on processed dirs)
find_bmp() {
    local base="$1"
    local result
    result=$(find "$SRC" -maxdepth 2 -iname "${base}" -print -quit 2>/dev/null)
    if [ -z "$result" ] && [[ "$base" == *.bmp ]]; then
        local png_name="${base%.bmp}.png"
        result=$(find "$SRC" -maxdepth 2 -iname "${png_name}" -print -quit 2>/dev/null)
    fi
    echo "$result"
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
EQMAIN_BMP=$(find_bmp "eqmain.bmp")
PLEDIT_BMP=$(find_bmp "pledit.bmp")
VISCOLOR_TXT=$(find_bmp "viscolor.txt")

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
# Strategy: Full Winamp UI assembly at ~2.6x scale, top-aligned
#   - Main window (275×116 → 720×304) at Y=0
#   - Position bar + Control buttons below main
#   - EQ window (~720×180) below controls
#   - Playlist window (~720×187) at bottom
# =============================================
echo "  Composing bg-large.png (720x752)..."

SCALE_L=$(echo "scale=4; 720 / 275" | bc)  # ~2.618x

# Scale main.bmp to 720 wide
magick "$MAIN_BMP" \
    -filter Point -resize "720x" \
    PNG32:"$OUTDIR/_main_scaled.png"

MAIN_H=$(identify -format "%h" "$OUTDIR/_main_scaled.png")

# Top-aligned: main starts at Y=0 (matches Winamp stacked layout)
VERT_OFFSET=0

# Pre-scale extra parts
if [ -f "$OUTDIR/_posbar.png" ]; then
    magick "$OUTDIR/_posbar.png" -filter Point -resize "660x" PNG32:"$OUTDIR/_posbar_scaled.png"
    PB_H=$(identify -format "%h" "$OUTDIR/_posbar_scaled.png")
fi
if [ -f "$OUTDIR/_cbuttons.png" ]; then
    magick "$OUTDIR/_cbuttons.png" -filter Point -resize "360x" PNG32:"$OUTDIR/_cbuttons_scaled.png"
    CB_H=$(identify -format "%h" "$OUTDIR/_cbuttons_scaled.png")
fi

# Create canvas and composite main at top
magick -size 720x752 "xc:#${BG_COLOR}" \
    "$OUTDIR/_main_scaled.png" -gravity NorthWest -geometry "+0+${VERT_OFFSET}" -composite \
    PNG32:"$OUTDIR/bg-large.png"

Y_OFFSET=$((VERT_OFFSET + MAIN_H))

# Posbar below main
if [ -f "$OUTDIR/_posbar_scaled.png" ]; then
    magick "$OUTDIR/bg-large.png" \
        "$OUTDIR/_posbar_scaled.png" -gravity NorthWest -geometry "+30+${Y_OFFSET}" -composite \
        PNG32:"$OUTDIR/bg-large.png"
    Y_OFFSET=$((Y_OFFSET + PB_H + 8))
fi

# Control buttons
if [ -f "$OUTDIR/_cbuttons_scaled.png" ]; then
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

# --- EQ Window ---
# Standard Winamp EQ: 275×116, but we use a compact version ~275×69
# EQ_Y starts after control buttons area
EQ_Y=$Y_OFFSET
EQ_HEIGHT=180  # Target height for EQ section at @2x

# Extract EQ background from eqmain.bmp if available
if [ -n "$EQMAIN_BMP" ] && [ -f "$EQMAIN_BMP" ]; then
    # EQ titlebar: 275×14 from top of eqmain.bmp
    magick "$EQMAIN_BMP" -crop 275x14+0+0 +repage \
        -filter Point -resize "720x" PNG32:"$OUTDIR/_eq_titlebar.png"
    EQ_TB_H=$(identify -format "%h" "$OUTDIR/_eq_titlebar.png")

    # EQ body: 275×55 (below titlebar, the main EQ area with sliders)
    magick "$EQMAIN_BMP" -crop 275x55+0+14 +repage \
        -filter Point -resize "720x" PNG32:"$OUTDIR/_eq_body.png"
    EQ_BODY_H=$(identify -format "%h" "$OUTDIR/_eq_body.png")

    # Composite EQ titlebar
    magick "$OUTDIR/bg-large.png" \
        "$OUTDIR/_eq_titlebar.png" -gravity NorthWest -geometry "+0+${EQ_Y}" -composite \
        PNG32:"$OUTDIR/bg-large.png"
    EQ_Y=$((EQ_Y + EQ_TB_H))

    # Composite EQ body
    magick "$OUTDIR/bg-large.png" \
        "$OUTDIR/_eq_body.png" -gravity NorthWest -geometry "+0+${EQ_Y}" -composite \
        PNG32:"$OUTDIR/bg-large.png"
    EQ_Y=$((EQ_Y + EQ_BODY_H))
else
    echo "  No eqmain.bmp found, generating fallback EQ window..."
    # Fallback: draw EQ-like window with background color
    # EQ titlebar fallback: solid dark bar with "EQUALIZER" feel
    DARK_BG=$(darken_hex "$BG_COLOR" 50)
    magick -size 720x37 "xc:${DARK_BG}" PNG32:"$OUTDIR/_eq_titlebar_fb.png"
    magick "$OUTDIR/bg-large.png" \
        "$OUTDIR/_eq_titlebar_fb.png" -gravity NorthWest -geometry "+0+${EQ_Y}" -composite \
        PNG32:"$OUTDIR/bg-large.png"
    EQ_Y=$((EQ_Y + 37))

    # EQ body fallback
    EQ_BODY_FB_H=143
    magick -size 720x${EQ_BODY_FB_H} "xc:#${BG_COLOR}" PNG32:"$OUTDIR/_eq_body_fb.png"
    magick "$OUTDIR/bg-large.png" \
        "$OUTDIR/_eq_body_fb.png" -gravity NorthWest -geometry "+0+${EQ_Y}" -composite \
        PNG32:"$OUTDIR/bg-large.png"
    EQ_Y=$((EQ_Y + EQ_BODY_FB_H))
fi

# Draw static EQ bars (10 bands) — "frozen moment" visualization
# Use viscolor.txt first color if available, otherwise derive from clock/bg color
EQ_BAR_COLOR=""
if [ -n "$VISCOLOR_TXT" ] && [ -f "$VISCOLOR_TXT" ]; then
    # viscolor.txt line 2 is typically the peak color
    EQ_BAR_COLOR=$(sed -n '2p' "$VISCOLOR_TXT" | tr -d '\r' | \
        awk -F',' '{printf "#%02X%02X%02X", $1+0, $2+0, $3+0}' 2>/dev/null)
fi
if [ -z "$EQ_BAR_COLOR" ] || [ "$EQ_BAR_COLOR" = "#000000" ]; then
    # Derive a bright accent from BG_COLOR
    EQ_BAR_COLOR=$(brighten_hex "$BG_COLOR" 160)
fi
echo "  EQ bar color: $EQ_BAR_COLOR"

# Draw 10 EQ bars with pseudo-random heights in the EQ body area
# Bars positioned in the EQ body region (EQ_Y is now at bottom of EQ section)
EQ_BARS_BOTTOM=$((EQ_Y - 15))  # 15px padding from bottom
BAR_WIDTH=36
BAR_GAP=26
# Center 10 bars: total = 10*36 + 9*26 = 594, margin = (720-594)/2 = 63
BAR_START_X=63

# Seed with skin name for consistent "random" bars per skin
SEED=$(echo -n "$NAME" | cksum | awk '{print $1}')
DRAW_BARS=""
for i in $(seq 0 9); do
    # Deterministic pseudo-random height per band (30-110px)
    H=$(( (SEED * (i + 3) * 7 + i * 31) % 80 + 30 ))
    BAR_X=$((BAR_START_X + i * (BAR_WIDTH + BAR_GAP)))
    BAR_Y=$((EQ_BARS_BOTTOM - H))
    DRAW_BARS="${DRAW_BARS} rectangle ${BAR_X},${BAR_Y} $((BAR_X + BAR_WIDTH)),${EQ_BARS_BOTTOM}"
done

magick "$OUTDIR/bg-large.png" \
    -fill "$EQ_BAR_COLOR" -draw "${DRAW_BARS}" \
    PNG32:"$OUTDIR/bg-large.png"

# --- Playlist Window ---
# Fill remaining space from EQ_Y to 752
PL_Y=$EQ_Y
PL_HEIGHT=$((752 - PL_Y))

if [ $PL_HEIGHT -gt 20 ]; then
    echo "  Composing playlist window (height=${PL_HEIGHT})..."

    if [ -n "$PLEDIT_BMP" ] && [ -f "$PLEDIT_BMP" ]; then
        # Extract playlist titlebar: 275×14 from pledit.bmp at (0,0)
        magick "$PLEDIT_BMP" -crop 275x14+0+0 +repage \
            -filter Point -resize "720x" PNG32:"$OUTDIR/_pl_titlebar.png"
        PL_TB_H=$(identify -format "%h" "$OUTDIR/_pl_titlebar.png")

        magick "$OUTDIR/bg-large.png" \
            "$OUTDIR/_pl_titlebar.png" -gravity NorthWest -geometry "+0+${PL_Y}" -composite \
            PNG32:"$OUTDIR/bg-large.png"
        PL_Y=$((PL_Y + PL_TB_H))

        # Playlist body: use a strip from pledit.bmp and tile/stretch to fill
        PL_BMP_H=$(identify -format "%h" "$PLEDIT_BMP")
        # Grab a body strip (below titlebar, ~20px)
        STRIP_Y=14
        STRIP_H=$((PL_BMP_H > 34 ? 20 : PL_BMP_H - 14))
        if [ $STRIP_H -gt 0 ]; then
            PL_BODY_H=$((752 - PL_Y))
            magick "$PLEDIT_BMP" -crop "275x${STRIP_H}+0+${STRIP_Y}" +repage \
                -filter Point -resize "720x" \
                -write mpr:plstrip +delete \
                -size "720x${PL_BODY_H}" tile:mpr:plstrip \
                PNG32:"$OUTDIR/_pl_body.png"
            magick "$OUTDIR/bg-large.png" \
                "$OUTDIR/_pl_body.png" -gravity NorthWest -geometry "+0+${PL_Y}" -composite \
                PNG32:"$OUTDIR/bg-large.png"
        fi
    else
        echo "  No pledit.bmp found, generating fallback playlist window..."
        # Fallback: darker rectangle with subtle border
        DARK_PL=$(darken_hex "$BG_COLOR" 75)

        # Titlebar
        magick -size 720x37 "xc:${DARK_PL}" PNG32:"$OUTDIR/_pl_titlebar_fb.png"
        magick "$OUTDIR/bg-large.png" \
            "$OUTDIR/_pl_titlebar_fb.png" -gravity NorthWest -geometry "+0+${PL_Y}" -composite \
            PNG32:"$OUTDIR/bg-large.png"
        PL_Y=$((PL_Y + 37))

        # Body: slightly different shade
        PL_BODY_H=$((752 - PL_Y))
        if [ $PL_BODY_H -gt 0 ]; then
            DARKER_PL=$(darken_hex "$BG_COLOR" 50)
            magick -size "720x${PL_BODY_H}" "xc:${DARKER_PL}" PNG32:"$OUTDIR/_pl_body_fb.png"
            magick "$OUTDIR/bg-large.png" \
                "$OUTDIR/_pl_body_fb.png" -gravity NorthWest -geometry "+0+${PL_Y}" -composite \
                PNG32:"$OUTDIR/bg-large.png"
        fi
    fi
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
