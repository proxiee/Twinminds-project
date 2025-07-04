# iOS Widget Setup Guide for AudioTranscriber

This guide will walk you through setting up the iOS Widget extension for the AudioTranscriber app.

## 📋 Prerequisites

- Xcode 15.0 or later
- iOS 17.0+ deployment target
- Apple Developer account (for device testing)

## 🚀 Step-by-Step Setup Instructions

### Step 1: Create Widget Extension Target

1. **Open Xcode** and open the `AudioTranscriber.xcodeproj` file
2. **Add New Target**:
   - Go to `File` → `New` → `Target`
   - Select `iOS` → `Widget Extension`
   - Click `Next`

3. **Configure Widget Extension**:
   - **Product Name**: `AudioTranscriberWidget`
   - **Language**: `Swift`
   - **Include Configuration Intent**: `Unchecked` (we don't need user configuration)
   - **Embed in Application**: `AudioTranscriber`
   - Click `Finish`

4. **Activate Scheme**: When prompted, click `Activate` to create a new scheme for the widget

### Step 2: Replace Widget Files

1. **Replace the main widget file**:
   - Delete the auto-generated `AudioTranscriberWidget.swift` file
   - Add the provided `AudioTranscriberWidget.swift` file to the widget target

2. **Add Info.plist**:
   - Replace the auto-generated `Info.plist` with the provided one

3. **Add Entitlements**:
   - Add the provided `AudioTranscriberWidget.entitlements` file to the widget target

### Step 3: Configure App Groups

1. **Main App Configuration**:
   - Select the main `AudioTranscriber` target
   - Go to `Signing & Capabilities`
   - Click `+ Capability`
   - Add `App Groups`
   - Add group: `group.com.audiotranscriber.widget`

2. **Widget Extension Configuration**:
   - Select the `AudioTranscriberWidget` target
   - Go to `Signing & Capabilities`
   - Click `+ Capability`
   - Add `App Groups`
   - Add the same group: `group.com.audiotranscriber.widget`

### Step 4: Add Shared Data Service

1. **Add WidgetDataService.swift**:
   - Add the provided `WidgetDataService.swift` file to the main app target
   - This enables communication between the app and widget

2. **Update AudioService.swift**:
   - The widget integration has already been added to the AudioService
   - This automatically updates the widget when recording starts/stops

### Step 5: Configure Bundle Identifiers

1. **Main App**:
   - Bundle Identifier: `com.yourcompany.AudioTranscriber` (or your preferred identifier)

2. **Widget Extension**:
   - Bundle Identifier: `com.yourcompany.AudioTranscriber.widget` (append `.widget`)

### Step 6: Build and Test

1. **Build the Project**:
   ```bash
   xcodebuild -project AudioTranscriber.xcodeproj -scheme AudioTranscriber -destination 'platform=iOS Simulator,name=iPhone 16' build
   ```

2. **Run on Device/Simulator**:
   - Select the main app scheme
   - Run the app (⌘+R)
   - The widget extension will be installed automatically

3. **Add Widget to Home Screen**:
   - Long press on home screen
   - Tap the `+` button
   - Search for "AudioTranscriber"
   - Add the widget in your preferred size

## 🎯 Widget Features

### Supported Widget Sizes:
- **Small**: Shows recording status and session count
- **Medium**: Shows recent recordings with status badges
- **Large**: Shows detailed session information with timestamps

### Widget Functionality:
- **Real-time Updates**: Shows current recording status
- **Recent Sessions**: Displays up to 10 most recent recordings
- **Status Indicators**: Shows transcription completion status
- **Quick Access**: Tap to open the main app

## 🔧 Configuration Options

### Widget Refresh Rate:
- Default: Every 5 minutes
- Can be adjusted in `AudioTranscriberWidgetProvider.getTimeline()`

### Data Sharing:
- Uses App Groups for secure data sharing
- Shared via UserDefaults with suite name: `group.com.audiotranscriber.widget`

### Supported Data:
- Recent recording sessions (up to 10)
- Current recording status
- Session metadata (duration, segments, transcription status)

## 🐛 Troubleshooting

### Common Issues:

1. **Widget Not Appearing**:
   - Check App Groups configuration
   - Verify bundle identifiers
   - Clean build folder and rebuild

2. **Data Not Updating**:
   - Check UserDefaults suite name matches
   - Verify WidgetDataService integration
   - Check console for error messages

3. **Build Errors**:
   - Ensure all files are added to correct targets
   - Check entitlements configuration
   - Verify deployment target compatibility

### Debug Tips:

1. **Check Console Logs**:
   - Look for widget-related log messages
   - Check for data sharing errors

2. **Test Data Sharing**:
   - Add test data in main app
   - Verify widget receives updates

3. **Widget Refresh**:
   - Force widget refresh by removing and re-adding
   - Check timeline refresh intervals

## 📱 Testing on Device

1. **Device Requirements**:
   - iOS 17.0 or later
   - Sufficient storage space

2. **Installation**:
   - Build and run on device
   - Widget extension installs automatically
   - Add widget from home screen

3. **Testing Scenarios**:
   - Start/stop recording
   - Check widget updates
   - Test different widget sizes
   - Verify data persistence

## 🎉 Success Criteria

The widget is successfully implemented when:

- ✅ Widget appears in home screen widget gallery
- ✅ Widget shows current recording status
- ✅ Widget displays recent sessions
- ✅ Data updates when recording starts/stops
- ✅ All widget sizes work correctly
- ✅ No build errors or runtime crashes

## 📚 Additional Resources

- [Apple WidgetKit Documentation](https://developer.apple.com/documentation/widgetkit)
- [App Groups Guide](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups)
- [Widget Extension Tutorial](https://developer.apple.com/tutorials/app-dev-training/creating-a-widget-extension)

---

**Note**: This widget implementation provides a foundation that can be extended with additional features like quick actions, deep linking, and more advanced data visualization. 