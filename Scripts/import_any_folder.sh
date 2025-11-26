#!/bin/bash
#
# Import ANY Folder - No "MySamples" required!
# Just point to your FL Studio Mobile/Sample Bulk or any other folder
#
# Usage:
#   ./import_any_folder.sh "/path/to/Sample Bulk"
#   ./import_any_folder.sh "~/Documents/FL Studio Mobile/MySamples/Sample Bulk"
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=================================================="
echo "  ECHOELMUSIC - IMPORT ANY FOLDER"
echo "  Flexible Import from ANY Location!"
echo "=================================================="
echo ""

# Check if folder path provided
if [ -z "$1" ]; then
    echo "❌ No folder specified!"
    echo ""
    echo "Usage:"
    echo "  ./import_any_folder.sh \"/path/to/your/samples\""
    echo ""
    echo "Examples:"
    echo "  ./import_any_folder.sh \"~/Documents/FL Studio Mobile/MySamples/Sample Bulk\""
    echo "  ./import_any_folder.sh \"/sdcard/FL Studio Mobile/Audio Clips\""
    echo "  ./import_any_folder.sh \"C:\\Users\\Me\\Music\\MySamples\""
    echo ""
    exit 1
fi

SOURCE_FOLDER="$1"

# Expand tilde and check if folder exists
SOURCE_FOLDER="${SOURCE_FOLDER/#\~/$HOME}"

if [ ! -d "$SOURCE_FOLDER" ]; then
    echo "❌ Folder not found: $SOURCE_FOLDER"
    echo ""
    echo "Please check the path and try again."
    exit 1
fi

echo "✅ Found folder: $SOURCE_FOLDER"
echo ""

# Count samples
SAMPLE_COUNT=$(find "$SOURCE_FOLDER" -type f \( -iname "*.wav" -o -iname "*.mp3" -o -iname "*.flac" -o -iname "*.ogg" -o -iname "*.aiff" -o -iname "*.m4a" \) | wc -l)

if [ "$SAMPLE_COUNT" -eq 0 ]; then
    echo "❌ No audio files found in folder!"
    echo ""
    echo "Supported formats: WAV, MP3, FLAC, OGG, AIFF, M4A"
    exit 1
fi

echo "📦 Found $SAMPLE_COUNT samples"
echo ""

# Show some samples
echo "Sample files (first 10):"
echo "------------------------"
find "$SOURCE_FOLDER" -type f \( -iname "*.wav" -o -iname "*.mp3" -o -iname "*.flac" -o -iname "*.ogg" -o -iname "*.aiff" -o -iname "*.m4a" \) -exec basename {} \; | head -10
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
echo "  9) Random Light (10-30%)"
echo " 10) Random Medium (30-60%) [RECOMMENDED]"
echo " 11) Random Heavy (60-100%)"
echo "  0) No transformation (just import & organize)"
echo ""
read -p "Enter preset number (0-11, default=10): " PRESET_CHOICE
PRESET_CHOICE=${PRESET_CHOICE:-10}

case $PRESET_CHOICE in
    0) PRESET_NAME="No Transform" ;;
    1) PRESET_NAME="Dark & Deep" ;;
    2) PRESET_NAME="Bright & Crispy" ;;
    3) PRESET_NAME="Vintage & Warm" ;;
    4) PRESET_NAME="Glitchy & Modern" ;;
    5) PRESET_NAME="Sub Bass" ;;
    6) PRESET_NAME="Airy & Ethereal" ;;
    7) PRESET_NAME="Aggressive & Punchy" ;;
    8) PRESET_NAME="Retro Vaporwave" ;;
    9) PRESET_NAME="Random Light" ;;
    10) PRESET_NAME="Random Medium" ;;
    11) PRESET_NAME="Random Heavy" ;;
    *) PRESET_NAME="Random Medium"; PRESET_CHOICE=10 ;;
esac

echo ""
echo "✅ Selected: $PRESET_NAME"
echo ""

# Confirm
read -p "Import $SAMPLE_COUNT samples from this folder? (y/n, default=y): " CONFIRM
CONFIRM=${CONFIRM:-y}

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "=================================================="
echo "  IMPORTING FROM:"
echo "  $SOURCE_FOLDER"
echo "=================================================="
echo ""
echo "⏳ Processing $SAMPLE_COUNT samples with $PRESET_NAME preset..."
echo ""

# For now, just analyze (C++ processor integration coming)
COUNTER=0
while IFS= read -r -d '' SAMPLE_FILE; do
    COUNTER=$((COUNTER + 1))
    BASENAME=$(basename "$SAMPLE_FILE")
    FILENAME="${BASENAME%.*}"

    # Extract info from filename
    BPM=$(echo "$FILENAME" | grep -oP '\d{2,3}(?=bpm|BPM)' | head -1)
    KEY=$(echo "$FILENAME" | grep -oP '(?i)[A-G](#|b)?(m|min|maj)?' | head -1)
    GENRE=$(echo "$FILENAME" | grep -oiP '(techno|house|trap|dubstep|dnb|ambient|trance)' | head -1)
    TYPE=$(echo "$FILENAME" | grep -oiP '(kick|snare|hat|clap|bass|lead|pad|vocal|loop|fx)' | head -1)

    # Progress
    PROGRESS=$((COUNTER * 100 / SAMPLE_COUNT))
    echo "[$PROGRESS%] ($COUNTER/$SAMPLE_COUNT) $BASENAME"

    # Show detected info
    INFO=""
    [ -n "$BPM" ] && INFO="$INFO BPM:$BPM"
    [ -n "$KEY" ] && INFO="$INFO Key:$KEY"
    [ -n "$GENRE" ] && INFO="$INFO Genre:$GENRE"
    [ -n "$TYPE" ] && INFO="$INFO Type:$TYPE"

    [ -n "$INFO" ] && echo "        →$INFO"

done < <(find "$SOURCE_FOLDER" -type f \( -iname "*.wav" -o -iname "*.mp3" -o -iname "*.flac" -o -iname "*.ogg" -o -iname "*.aiff" -o -iname "*.m4a" \) -print0)

echo ""
echo "=================================================="
echo "  ANALYSIS COMPLETE"
echo "=================================================="
echo ""
echo "📊 Summary:"
echo "   Source: $SOURCE_FOLDER"
echo "   Samples: $SAMPLE_COUNT"
echo "   Preset: $PRESET_NAME"
echo ""
echo "⚠️  NOTE: Full import requires C++ FLStudioMobileImporter"
echo "          (will be integrated in Echoelmusic GUI)"
echo ""
echo "To import now:"
echo "  1. Compile: g++ Scripts/ImportFromFLStudio.cpp -o import_fl"
echo "  2. Run: ./import_fl \"$SOURCE_FOLDER\""
echo ""
echo "Or use Echoelmusic GUI:"
echo "  1. Open Echoelmusic"
echo "  2. Sample Browser → Import → Custom Folder"
echo "  3. Select: $SOURCE_FOLDER"
echo "  4. Choose preset: $PRESET_NAME"
echo "  5. Click 'Import'"
echo ""
echo "✨ Ready to import!"
