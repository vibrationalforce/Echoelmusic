#!/bin/bash
#
# Echoelmusic Bulk Sample Processor
# Quick script to process samples from MySamples folder
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MY_SAMPLES="$PROJECT_DIR/MySamples"
OUTPUT_DIR="$PROJECT_DIR/Samples/Processed"

echo "=================================================="
echo "  ECHOELMUSIC BULK SAMPLE PROCESSOR"
echo "=================================================="
echo ""

# Check if MySamples folder exists
if [ ! -d "$MY_SAMPLES" ]; then
    echo "❌ MySamples folder not found!"
    echo "   Expected: $MY_SAMPLES"
    echo ""
    echo "Creating MySamples folder..."
    mkdir -p "$MY_SAMPLES"
    echo "✅ Folder created: $MY_SAMPLES"
    echo ""
    echo "👉 Please add your samples to MySamples/ and run this script again."
    exit 1
fi

# Count audio files
SAMPLE_COUNT=$(find "$MY_SAMPLES" -type f \( -iname "*.wav" -o -iname "*.mp3" -o -iname "*.flac" -o -iname "*.ogg" -o -iname "*.aiff" \) | wc -l)

if [ "$SAMPLE_COUNT" -eq 0 ]; then
    echo "❌ No audio files found in MySamples/"
    echo ""
    echo "Supported formats: WAV, MP3, FLAC, OGG, AIFF"
    echo ""
    echo "👉 Add your samples to: $MY_SAMPLES"
    exit 1
fi

echo "📦 Found $SAMPLE_COUNT samples in MySamples/"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# List samples
echo "Samples to process:"
echo "-------------------"
find "$MY_SAMPLES" -type f \( -iname "*.wav" -o -iname "*.mp3" -o -iname "*.flac" -o -iname "*.ogg" -o -iname "*.aiff" \) -exec basename {} \; | head -10
if [ "$SAMPLE_COUNT" -gt 10 ]; then
    echo "... and $((SAMPLE_COUNT - 10)) more"
fi
echo ""

# Choose preset
echo "Choose transformation preset:"
echo ""
echo "  1) Dark & Deep (Dark Techno)"
echo "  2) Bright & Crispy (Modern House)"
echo "  3) Vintage & Warm (Lo-Fi)"
echo "  4) Glitchy & Modern (Experimental)"
echo "  5) Sub Bass (Bass Heavy)"
echo "  6) Airy & Ethereal (Ambient)"
echo "  7) Aggressive & Punchy (Hard Techno)"
echo "  8) Retro Vaporwave"
echo "  9) Random Light (10-30% variation)"
echo " 10) Random Medium (30-60% variation) [RECOMMENDED]"
echo " 11) Random Heavy (60-100% variation)"
echo ""
read -p "Enter preset number (1-11, default=10): " PRESET_CHOICE
PRESET_CHOICE=${PRESET_CHOICE:-10}

# Map preset choice to name
case $PRESET_CHOICE in
    1) PRESET_NAME="DarkDeep" ;;
    2) PRESET_NAME="BrightCrispy" ;;
    3) PRESET_NAME="VintageWarm" ;;
    4) PRESET_NAME="GlitchyModern" ;;
    5) PRESET_NAME="SubBass" ;;
    6) PRESET_NAME="AiryEthereal" ;;
    7) PRESET_NAME="AggressivePunchy" ;;
    8) PRESET_NAME="RetroVaporwave" ;;
    9) PRESET_NAME="RandomLight" ;;
    10) PRESET_NAME="RandomMedium" ;;
    11) PRESET_NAME="RandomHeavy" ;;
    *) PRESET_NAME="RandomMedium" ;;
esac

echo ""
echo "✅ Selected preset: $PRESET_NAME"
echo ""

# Confirm
read -p "Start processing? (y/n, default=y): " CONFIRM
CONFIRM=${CONFIRM:-y}

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "=================================================="
echo "  PROCESSING SAMPLES"
echo "=================================================="
echo ""
echo "⏳ Processing $SAMPLE_COUNT samples with $PRESET_NAME preset..."
echo ""
echo "NOTE: C++ processor not compiled yet."
echo "      This script will analyze your samples for now."
echo ""

# Analyze samples (extract musical info)
COUNTER=0
while IFS= read -r -d '' SAMPLE_FILE; do
    COUNTER=$((COUNTER + 1))
    BASENAME=$(basename "$SAMPLE_FILE")
    FILENAME="${BASENAME%.*}"

    # Extract BPM from filename
    BPM=$(echo "$FILENAME" | grep -oP '\d{2,3}(?=bpm|BPM)' | head -1)

    # Extract key from filename
    KEY=$(echo "$FILENAME" | grep -oP '(?i)[A-G](#|b)?(m|min|maj)?' | head -1)

    # Extract genre
    GENRE=$(echo "$FILENAME" | grep -oiP '(techno|house|trap|dubstep|dnb|ambient|trance|hip-?hop)' | head -1)

    # Extract type
    TYPE=$(echo "$FILENAME" | grep -oiP '(kick|snare|hat|clap|bass|lead|pad|vocal|loop|fx)' | head -1)

    # Progress
    PROGRESS=$((COUNTER * 100 / SAMPLE_COUNT))
    echo "[$PROGRESS%] ($COUNTER/$SAMPLE_COUNT) $BASENAME"

    # Show detected info
    [ -n "$BPM" ] && echo "        BPM: $BPM"
    [ -n "$KEY" ] && echo "        Key: $KEY"
    [ -n "$GENRE" ] && echo "        Genre: $GENRE"
    [ -n "$TYPE" ] && echo "        Type: $TYPE"

    # Simulate processing (replace with actual C++ call)
    # OUTPUT_NAME="Echoel${PRESET_NAME}${TYPE}_${GENRE}_${KEY}_${BPM}_$(printf '%03d' $COUNTER).wav"
    # echo "        → $OUTPUT_NAME"

done < <(find "$MY_SAMPLES" -type f \( -iname "*.wav" -o -iname "*.mp3" -o -iname "*.flac" -o -iname "*.ogg" -o -iname "*.aiff" \) -print0)

echo ""
echo "=================================================="
echo "  ANALYSIS COMPLETE"
echo "=================================================="
echo ""
echo "📊 Summary:"
echo "   Samples analyzed: $SAMPLE_COUNT"
echo "   Preset: $PRESET_NAME"
echo "   Output folder: $OUTPUT_DIR"
echo ""
echo "⚠️  NOTE: Actual processing requires C++ SampleProcessor"
echo "          (will be integrated in Echoelmusic GUI)"
echo ""
echo "Next steps:"
echo "  1. Open Echoelmusic"
echo "  2. Go to Sample Browser"
echo "  3. Click 'Import from MySamples'"
echo "  4. Choose preset and click 'Process All'"
echo ""
echo "✨ Done!"
