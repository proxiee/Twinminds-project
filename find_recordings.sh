#!/bin/bash

# AudioTranscriber Recording File Finder
# This script helps locate and copy recording files from the app

echo "🔍 AudioTranscriber Recording File Finder"
echo "========================================"

# Create recordings directory if it doesn't exist
RECORDINGS_DIR="$PWD/Recordings"
mkdir -p "$RECORDINGS_DIR"

# Function to copy files and show results
copy_files() {
    local source_dir="$1"
    local description="$2"
    
    if [ -d "$source_dir" ]; then
        local files=$(find "$source_dir" -name "*.caf" 2>/dev/null)
        if [ -n "$files" ]; then
            echo "📁 Found recordings in $description:"
            echo "$files" | while read -r file; do
                if [ -f "$file" ]; then
                    basename=$(basename "$file")
                    cp "$file" "$RECORDINGS_DIR/"
                    echo "  ✅ Copied: $basename"
                fi
            done
            echo ""
        else
            echo "📭 No recordings found in $description"
            echo ""
        fi
    else
        echo "📂 Directory not found: $description"
        echo ""
    fi
}

echo "🎯 Searching for AudioTranscriber recordings..."
echo ""

# Search macOS app directory
MACOS_DIR="$HOME/Library/Containers/Yashwanth.AudioTranscriber/Data/Documents"
copy_files "$MACOS_DIR" "macOS app directory"

# Search iOS Simulator directories
echo "🔍 Searching iOS Simulator directories..."
SIM_DIRS=$(find "$HOME/Library/Developer/CoreSimulator/Devices" -name "Documents" -type d 2>/dev/null | head -10)

if [ -n "$SIM_DIRS" ]; then
    echo "$SIM_DIRS" | while read -r sim_dir; do
        device_id=$(echo "$sim_dir" | cut -d'/' -f8)
        copy_files "$sim_dir" "iOS Simulator ($device_id)"
    done
else
    echo "📭 No iOS Simulator directories found"
    echo ""
fi

# Show summary
echo "📊 Summary:"
echo "--------"
if [ -d "$RECORDINGS_DIR" ]; then
    recording_count=$(find "$RECORDINGS_DIR" -name "*.caf" 2>/dev/null | wc -l)
    echo "📁 Recordings copied to: $RECORDINGS_DIR"
    echo "🎵 Total recordings found: $recording_count"
    
    if [ "$recording_count" -gt 0 ]; then
        echo ""
        echo "📋 Files copied:"
        ls -la "$RECORDINGS_DIR"/*.caf 2>/dev/null | while read -r line; do
            echo "  $line"
        done
    fi
else
    echo "❌ Could not create recordings directory"
fi

echo ""
echo "💡 Tips:"
echo "  • Use the app's 'Copy Recording to Project' button for easier access"
echo "  • Check the RECORDINGS_GUIDE.md for more detailed instructions"
echo "  • Files are named: AudioTranscriber_Recording_[timestamp].caf"
