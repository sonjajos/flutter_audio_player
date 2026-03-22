#!/bin/bash
# Push audio samples to the iOS Simulator's app container.
# Usage: ./scripts/push_audio.sh
# Source: ~/Desktop/music (sample1.mp3 - sample12.mp3)

BUNDLE_ID="com.flutter.audioPlayer"
SOURCE_DIR="$HOME/Desktop/music"

# Verify source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory not found: $SOURCE_DIR"
    exit 1
fi

# Verify simulator is booted
APP_DATA=$(xcrun simctl get_app_container booted "$BUNDLE_ID" data 2>/dev/null)
if [ -z "$APP_DATA" ]; then
    echo "Error: Could not find app container. Is the simulator running and app installed?"
    exit 1
fi

AUDIO_DIR="$APP_DATA/Documents/audio_files"

# Wipe and recreate to avoid duplicates or stale files
rm -rf "$AUDIO_DIR"
mkdir -p "$AUDIO_DIR"

# Copy all mp3 files from source
COPIED=0
for file in "$SOURCE_DIR"/*.mp3; do
    [ -f "$file" ] || continue
    cp "$file" "$AUDIO_DIR/"
    echo "Copied: $(basename "$file")"
    COPIED=$((COPIED + 1))
done

if [ $COPIED -eq 0 ]; then
    echo "Warning: No .mp3 files found in $SOURCE_DIR"
    exit 1
fi

echo ""
echo "Done. $COPIED file(s) in app container:"
ls "$AUDIO_DIR/"
echo ""
echo "Hot restart the app to pick them up (r in flutter run, or re-launch)."
