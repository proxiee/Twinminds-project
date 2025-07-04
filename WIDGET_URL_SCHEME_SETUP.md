# Widget URL Scheme Setup Guide

To enable widget actions (start/stop recording), you need to add a URL scheme to your Xcode project.

## Steps to Add URL Scheme:

1. **Open Xcode** and select your AudioTranscriber project
2. **Select the AudioTranscriber target** (not the widget target)
3. **Go to Info tab** in the target settings
4. **Expand "URL Types"** section
5. **Click the "+" button** to add a new URL type
6. **Configure the URL type:**
   - **Identifier:** `audiotranscriber`
   - **URL Schemes:** `audiotranscriber`
   - **Role:** `Editor`
   - **Icon:** (leave empty or add custom icon)

## URL Scheme Actions:

The widget now supports these URL actions:

- `audiotranscriber://start-recording` - Start recording
- `audiotranscriber://stop-recording` - Stop recording  
- `audiotranscriber://widget-tap` - Toggle recording state
- `audiotranscriber://open-app` - Open the app

## Widget Features:

### Small Widget:
- Shows recording status and duration
- Tap to toggle recording
- Displays session count or current session

### Medium Widget:
- **When not recording:** Shows recent sessions or "Start Recording" button
- **When recording:** Shows recording duration with Stop/More buttons
- Interactive controls for recording management

### Large Widget:
- **When not recording:** Shows up to 6 recent sessions or "Start Recording" button
- **When recording:** Shows large recording timer with Stop/More buttons
- Full session details and controls

## Testing:

1. Build and run the app
2. Add the widget to your home screen
3. Test the recording controls:
   - Tap "Start Recording" to begin
   - Tap "Stop" to end recording
   - Tap "More" to open the app
   - Tap the small widget to toggle recording

## Notes:

- The widget updates every 5 minutes automatically
- Recording duration is shown in real-time when recording
- All widget actions open the app and trigger the appropriate recording functions
- The widget uses App Groups to share data between the app and widget extension 