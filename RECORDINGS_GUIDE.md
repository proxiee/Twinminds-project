# AudioTranscriber - Complete Features Guide

## 🎯 Quick Summary

✅ **FIXED**: Visual audio feedback with animated bars
✅ **FIXED**: Automatic file conversion to MP3/M4A
✅ **FIXED**: Auto-sync to project recordings folder
✅ **FIXED**: Recordings sorted by newest first
✅ **FIXED**: Clean, modern UI with better button layout
✅ **FIXED**: Real-time transcription display
✅ **FIXED**: Easy file access and management

**File naming**: `AudioTranscriber_Recording_YYYY-MM-DD_HH-mm-ss.caf` (+ .mp3/.m4a)

## 📱 Building and Running the App

### For macOS:
```bash
./build_and_run.sh
```

### For iOS Simulator:
```bash
./build_ios.sh
```

## 📁 Where Recording Files Are Saved

### macOS App:
- **Primary location**: `~/Library/Containers/Yashwanth.AudioTranscriber/Data/Documents/`
- **Project copy**: `./Recordings/` (automatically created)

### iOS Simulator:
- **Simulator Documents**: `~/Library/Developer/CoreSimulator/Devices/[DEVICE_ID]/data/Containers/Data/Application/[APP_ID]/Documents/`

## 🆕 NEW FEATURES (Just Added!)

### 🎤 Visual Audio Feedback
- **Real-time audio bars**: See 20 animated bars showing microphone input levels
- **Color-coded feedback**: Green (good), Yellow (loud), Red (very loud)
- **Audio level percentage**: Shows exact input level (0-100%)
- **Responsive animation**: Bars animate smoothly with your voice

### 🎵 Automatic Audio Conversion
- **Auto MP3/M4A conversion**: Every recording is automatically converted
- **Multiple formats**: Original CAF + converted MP3 (or M4A on iOS)
- **Background processing**: Conversion happens automatically after recording
- **Better compatibility**: MP3/M4A files work everywhere

### 🔄 Smart File Syncing
- **"Sync All" button**: Converts and copies ALL recordings to project folder
- **Auto-sync on stop**: New recordings automatically copied after stopping
- **Newest first sorting**: All lists show newest recordings at the top
- **Instant access**: No manual copying needed

### 🎨 Improved UI
- **Clean button layout**: 3 main action buttons in a row
- **Better transcription display**: Real-time text with smooth scrolling
- **Modern design**: Icons and better spacing
- **Responsive layout**: Works great on all screen sizes

### 📝 Enhanced Recordings List
- **Play button**: Listen to recordings directly in the app
- **Transcribe button**: Get text transcription of any recording
- **Copy transcription**: Easy copy-to-clipboard functionality
- **File info**: See date, time, and file size for each recording
- **Swipe to delete**: Remove unwanted recordings easily

## 🔧 How to Access Recording Files

### Method 1: Use the App's "Copy Recording to Project" Button
1. Record something in the app
2. Tap "Copy Recording to Project" button
3. Files will be copied to `./Recordings/` folder in your project directory

### Method 2: Use "Copy Recordings Info" Button
1. Tap "Copy Recordings Info" button in the app
2. Paste the copied text - it shows exact file locations and names

### Method 3: Direct File Access (macOS)
```bash
# Navigate to the app's documents folder
cd ~/Library/Containers/Yashwanth.AudioTranscriber/Data/Documents/

# List all recording files
ls -la *.caf

# Copy files to current directory
cp *.caf /Users/yash/Documents/Twinminds-project/Recordings/
```

### Method 4: iOS Simulator File Access
```bash
# Find your simulator's device ID
xcrun simctl list devices

# Look for recording files (replace DEVICE_ID with actual ID)
find ~/Library/Developer/CoreSimulator/Devices -name "*.caf" | grep AudioTranscriber
```

## 🎵 File Format Details

- **Format**: CAF (Core Audio Format)
- **Quality**: 44.1 kHz, 32-bit float, mono
- **Compatibility**: Can be played by most audio players, including QuickTime Player, VLC, and imported into audio editing software

## 🐛 Troubleshooting

### App won't open on iOS Simulator:
1. Make sure iPhone 16 Pro simulator is available: `xcrun simctl list devices`
2. Try building for a different device: Edit `build_ios.sh` and change the device name
3. Check that iOS deployment target is compatible (currently set to 15.0)

### No recordings found:
1. Make sure you've granted microphone and speech recognition permissions
2. Try the "Copy Recordings Info" button to see the exact storage location
3. Check the debug logs with "Copy Debug Logs" button

### Recordings not accessible:
1. Use the "Copy Recording to Project" button after each recording
2. The `./Recordings/` folder is created automatically in your project directory
3. Files are named with timestamps for easy identification

## 📋 Debug Information

The app creates detailed logs saved to:
- **macOS**: `~/Library/Containers/Yashwanth.AudioTranscriber/Data/Documents/AudioTranscriber_Debug.log`
- **iOS Simulator**: App's Documents directory (same location as recordings)

Use the "Copy Debug Logs" button to get detailed troubleshooting information.

## 🚀 Tips for Development

1. **Easy file access**: Use the purple "Copy Recording to Project" button after each test recording
2. **File naming**: Recordings include date and time stamps for easy sorting
3. **Cross-platform**: The same file format works on both macOS and iOS
4. **Project integration**: The `./Recordings/` folder is gitignored by default

## ⚠️ Important Notes

- Recordings are saved in the app's sandboxed Documents directory
- iOS Simulator recordings are stored in a different location than device recordings
- Use the app's built-in buttons for easiest file access
- CAF files can be converted to other formats using audio conversion tools if needed
