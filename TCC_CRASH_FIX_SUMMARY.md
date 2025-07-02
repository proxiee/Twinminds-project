# AudioTranscriber TCC Crash Fix

## Problem
The AudioTranscriber app was crashing immediately on launch with a TCC (Transparency, Consent, and Control) violation:

```
Termination Reason: Namespace TCC, Code 0 
This app has crashed because it attempted to access privacy-sensitive data without a usage description. 
The app's Info.plist must contain an NSSpeechRecognitionUsageDescription key with a string value explaining to the user how the app uses this data.
```

## Root Cause Analysis

### Issue 1: Missing Privacy Description in Generated Info.plist
The project was configured with `GENERATE_INFOPLIST_FILE = YES`, which means Xcode generates the Info.plist file automatically from build settings rather than using the source Info.plist file. The generated Info.plist was missing the `NSSpeechRecognitionUsageDescription` key.

### Issue 2: Concurrent Permission Requests
The original code was requesting both speech recognition and microphone permissions simultaneously during app initialization, which can cause conflicts with Apple's privacy framework.

## Solutions Applied

### 1. Fixed Info.plist Generation
Added the speech recognition usage description to the build settings:
```bash
INFOPLIST_KEY_NSSpeechRecognitionUsageDescription="This app uses speech recognition to transcribe recorded audio into text."
```

### 2. Sequential Permission Requests
Modified `AudioService.swift` to request permissions sequentially:

**Before:**
```swift
private func checkPermissions() {
    SFSpeechRecognizer.requestAuthorization { authStatus in
        DispatchQueue.main.async {
            self.permissionStatus = authStatus
        }
    }
    
    requestMicrophonePermission()  // ❌ Called immediately
}
```

**After:**
```swift
private func checkPermissions() {
    logger.logInfo("🔐 Requesting speech recognition authorization...")
    SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
        DispatchQueue.main.async {
            self?.logger.logInfo("Speech recognition authorization status: \(authStatus.rawValue)")
            self?.permissionStatus = authStatus
            
            // Only request microphone permission after speech recognition is authorized
            if authStatus == .authorized {
                self?.requestMicrophonePermission()  // ✅ Called only after speech auth
            } else {
                self?.logger.logWarning("Speech recognition not authorized: \(authStatus)")
            }
        }
    }
}
```

### 3. Enhanced Error Handling
- Added proper weak self references to prevent retain cycles
- Added comprehensive debug logging
- Improved error handling throughout the permission flow

## Current Status ✅

- **App launches successfully** without TCC crashes
- **Proper privacy descriptions** are included in the generated Info.plist
- **Sequential permission requests** prevent framework conflicts
- **Debug logging** provides visibility into the permission flow
- **Build script** (`build_and_run.sh`) ensures proper configuration

## Files Modified

1. `AudioTranscriber/AudioService.swift` - Fixed permission request sequence
2. `build_and_run.sh` - Build script with proper configuration (new)
3. `TCC_CRASH_FIX_SUMMARY.md` - This documentation (new)

## Usage

To build and run the app with proper permissions:

```bash
./build_and_run.sh
```

Or manually:

```bash
xcodebuild build -project AudioTranscriber.xcodeproj -scheme AudioTranscriber \
    -destination 'platform=macOS,arch=x86_64' \
    INFOPLIST_KEY_NSSpeechRecognitionUsageDescription="This app uses speech recognition to transcribe recorded audio into text."
```

## Debug Information

- **Debug logs**: `~/Library/Containers/Yashwanth.AudioTranscriber/Data/Documents/AudioTranscriber_Debug.log`
- **App bundle**: `/Users/yash/Library/Developer/Xcode/DerivedData/AudioTranscriber-fikbjdrsqikcgdekyzgasgkfaomq/Build/Products/Debug/AudioTranscriber.app`

## Next Steps

1. Test the complete recording workflow
2. Verify permission dialogs appear correctly
3. Test audio transcription functionality
4. Consider adding the permission keys permanently to the project settings if needed

---

**Note**: The app now properly requests speech recognition permission first, then microphone permission, preventing the TCC violation that was causing the crash.
