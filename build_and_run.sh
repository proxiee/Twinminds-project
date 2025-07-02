#!/bin/bash

# AudioTranscriber macOS Build and Run Script
# This script ensures the app is built with proper privacy permissions

echo "🚀 Building AudioTranscriber for macOS with proper permissions..."

# Set project variables
PROJECT_NAME="AudioTranscriber"
SCHEME_NAME="AudioTranscriber"
WORKSPACE_OR_PROJECT="AudioTranscriber.xcodeproj"

# Clean previous build
echo "🧹 Cleaning previous build..."
xcodebuild clean -project "$WORKSPACE_OR_PROJECT" -scheme "$SCHEME_NAME" -destination 'platform=macOS'

# Build with speech recognition permission
echo "🔨 Building with speech recognition permission..."
xcodebuild build -project "$WORKSPACE_OR_PROJECT" -scheme "$SCHEME_NAME" -destination 'platform=macOS' \
    -configuration Debug \
    INFOPLIST_KEY_NSSpeechRecognitionUsageDescription="This app uses speech recognition to transcribe recorded audio into text." \
    INFOPLIST_KEY_NSMicrophoneUsageDescription="This app needs access to the microphone to record audio for transcription."

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Get the built app path dynamically
    DERIVED_DATA_PATH=$(xcodebuild -project "$WORKSPACE_OR_PROJECT" -scheme "$SCHEME_NAME" -showBuildSettings -destination 'platform=macOS' | grep BUILT_PRODUCTS_DIR | head -1 | sed 's/.*= //')
    APP_PATH="$DERIVED_DATA_PATH/$PROJECT_NAME.app"
    
    echo "📂 App path: $APP_PATH"
    
    # Verify the speech recognition permission is in Info.plist
    echo "🔍 Verifying speech recognition permission..."
    if [ -f "$APP_PATH/Contents/Info.plist" ] && grep -q "NSSpeechRecognitionUsageDescription" "$APP_PATH/Contents/Info.plist"; then
        echo "✅ Speech recognition permission found in Info.plist"
        
        # Create recordings directory in project folder for easy access
        RECORDINGS_DIR="$PWD/Recordings"
        mkdir -p "$RECORDINGS_DIR"
        echo "📁 Created recordings directory: $RECORDINGS_DIR"
        
        # Launch the app
        echo "🚀 Launching AudioTranscriber..."
        open "$APP_PATH"
        
        echo "📱 App launched successfully!"
        echo ""
        echo "📁 Recording files locations:"
        echo "   • App Documents: ~/Library/Containers/Yashwanth.AudioTranscriber/Data/Documents/"
        echo "   • Project Recordings folder: $RECORDINGS_DIR"
        echo "📄 Debug logs: ~/Library/Containers/Yashwanth.AudioTranscriber/Data/Documents/AudioTranscriber_Debug.log"
        echo ""
        echo "💡 Tip: Recordings are saved with names like 'recording-[timestamp].caf'"
        
    else
        echo "❌ Error: Speech recognition permission not found in Info.plist"
        echo "📂 Looking for Info.plist at: $APP_PATH/Contents/Info.plist"
        exit 1
    fi
else
    echo "❌ Build failed!"
    exit 1
fi
