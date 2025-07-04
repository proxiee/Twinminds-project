#!/bin/bash

# AudioTranscriber iOS Device Build and Deploy Script

echo "🚀 Building AudioTranscriber for iOS Device..."

# Set project variables
PROJECT_NAME="AudioTranscriber"
SCHEME_NAME="AudioTranscriber"
WORKSPACE_OR_PROJECT="AudioTranscriber.xcodeproj"

# Check for connected devices
echo "📱 Checking for connected iOS devices..."
DEVICES=$(xcrun devicectl list devices 2>/dev/null | grep -E "iPhone|iPad" | head -1)

if [ -z "$DEVICES" ]; then
    echo "⚠️  No iOS devices found. Please:"
    echo "   1. Connect your iPhone/iPad via USB"
    echo "   2. Trust this computer on your device"
    echo "   3. Ensure Developer Mode is enabled (Settings > Privacy & Security > Developer Mode)"
    echo ""
    echo "🔄 Falling back to iOS Simulator build..."
    ./build_ios.sh
    exit 0
fi

echo "✅ Found connected device(s)"

# Clean previous build
echo "🧹 Cleaning previous build..."
xcodebuild clean -project "$WORKSPACE_OR_PROJECT" -scheme "$SCHEME_NAME"

# Build for iOS Device
echo "🔨 Building for iOS Device..."
xcodebuild build -project "$WORKSPACE_OR_PROJECT" \
    -scheme "$SCHEME_NAME" \
    -destination 'generic/platform=iOS' \
    -configuration Debug \
    IPHONEOS_DEPLOYMENT_TARGET=15.0 \
    DEVELOPMENT_TEAM="" \
    CODE_SIGN_IDENTITY="iPhone Developer" \
    PROVISIONING_PROFILE_SPECIFIER="" \
    CODE_SIGN_STYLE=Automatic \
    INFOPLIST_KEY_NSSpeechRecognitionUsageDescription="This app uses speech recognition to transcribe recorded audio into text." \
    INFOPLIST_KEY_NSMicrophoneUsageDescription="This app needs microphone access to record audio for transcription."

BUILD_RESULT=$?

if [ $BUILD_RESULT -eq 0 ]; then
    echo "✅ Build successful!"
    echo ""
    echo "📱 To deploy to your device:"
    echo "   1. Open AudioTranscriber.xcodeproj in Xcode"
    echo "   2. Select your connected device from the device menu"
    echo "   3. Click the Run button (⌘+R)"
    echo ""
    echo "🔧 Make sure you have:"
    echo "   ✓ Apple Developer account (free is OK for personal use)"
    echo "   ✓ Device connected and trusted"
    echo "   ✓ Automatic code signing enabled in Xcode"
    echo ""
    echo "📋 Required permissions on device:"
    echo "   ✓ Microphone access"
    echo "   ✓ Speech recognition"
    echo ""
else
    echo "❌ Build failed!"
    echo ""
    echo "🔧 Common fixes:"
    echo "   1. Open Xcode and configure code signing:"
    echo "      - Select AudioTranscriber target"
    echo "      - Go to Signing & Capabilities"
    echo "      - Set Team to your Apple ID"
    echo "      - Enable 'Automatically manage signing'"
    echo ""
    echo "   2. Make sure iOS deployment target is compatible with your device"
    echo "   3. Check that your Apple ID is signed in to Xcode"
    echo ""
    exit 1
fi
