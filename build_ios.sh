#!/bin/bash

# AudioTranscriber iOS Simulator Build and Run Script

echo "🚀 Building AudioTranscriber for iOS Simulator..."

# Set project variables
PROJECT_NAME="AudioTranscriber"
SCHEME_NAME="AudioTranscriber"
WORKSPACE_OR_PROJECT="AudioTranscriber.xcodeproj"

# Clean previous build
echo "🧹 Cleaning previous build..."
xcodebuild clean -project "$WORKSPACE_OR_PROJECT" -scheme "$SCHEME_NAME" -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'

# Build for iOS Simulator
echo "🔨 Building for iOS Simulator..."
xcodebuild build -project "$WORKSPACE_OR_PROJECT" \
    -scheme "$SCHEME_NAME" \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
    -configuration Debug \
    IPHONEOS_DEPLOYMENT_TARGET=15.0 \
    SDKROOT=iphonesimulator \
    INFOPLIST_KEY_NSSpeechRecognitionUsageDescription="This app uses speech recognition to transcribe recorded audio into text." \
    INFOPLIST_KEY_NSMicrophoneUsageDescription="This app needs microphone access to record audio for transcription."

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Install and run on simulator
    echo "📱 Installing on iPhone 16 Pro Simulator..."
    
    # Boot simulator if needed
    xcrun simctl boot "iPhone 16 Pro" 2>/dev/null || true
    
    # Get the built app path
    DERIVED_DATA_PATH=$(xcodebuild -project "$WORKSPACE_OR_PROJECT" -scheme "$SCHEME_NAME" -showBuildSettings | grep BUILT_PRODUCTS_DIR | head -1 | sed 's/.*= //')
    APP_PATH="$DERIVED_DATA_PATH/$PROJECT_NAME.app"
    
    echo "📂 App path: $APP_PATH"
    
    # Check if app exists, if not try the correct iOS simulator path
    if [ ! -d "$APP_PATH" ]; then
        # Try the iOS simulator specific path
        PARENT_DIR=$(dirname "$DERIVED_DATA_PATH")
        APP_PATH="$PARENT_DIR/Debug-iphonesimulator/$PROJECT_NAME.app"
        echo "📂 Trying iOS simulator path: $APP_PATH"
    fi
    
    # Install app on simulator
    if [ -d "$APP_PATH" ]; then
        xcrun simctl install "iPhone 16 Pro" "$APP_PATH"
    else
        echo "❌ App not found at expected paths. Looking for app..."
        find "$(dirname "$DERIVED_DATA_PATH")" -name "$PROJECT_NAME.app" -type d | head -1
        APP_PATH=$(find "$(dirname "$DERIVED_DATA_PATH")" -name "$PROJECT_NAME.app" -type d | head -1)
        if [ -n "$APP_PATH" ]; then
            echo "📂 Found app at: $APP_PATH"
            xcrun simctl install "iPhone 16 Pro" "$APP_PATH"
        else
            echo "❌ Could not find built app"
            exit 1
        fi
    fi
    
    # Launch app
    BUNDLE_ID=$(defaults read "$APP_PATH/Info.plist" CFBundleIdentifier 2>/dev/null || echo "Yashwanth.AudioTranscriber")
    echo "🚀 Launching app with bundle ID: $BUNDLE_ID"
    xcrun simctl launch "iPhone 16 Pro" "$BUNDLE_ID"
    
    # Open simulator
    open -a Simulator
    
    echo "📱 App launched successfully on iOS Simulator!"
    echo ""
    echo "📁 Recording files will be saved to the simulator's Documents directory"
    echo "🔧 Use 'Device > Photos' in Simulator to access recording files"
    echo "📋 To access files directly, check: ~/Library/Developer/CoreSimulator/Devices/[DEVICE_ID]/data/Containers/Data/Application/[APP_ID]/Documents/"
    
else
    echo "❌ Build failed!"
    exit 1
fi
