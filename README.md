# 🎙️ AudioTranscriber - iOS Audio Recording & Transcription App

A production-ready iOS application that records audio in 30-second segments, transcribes them using OpenAI Whisper API with local fallback, and manages everything with SwiftData. Built to handle real-world audio challenges including interruptions, background recording, and network failures.

📚 **Documentation**: See `ARCHITECTURE.md` for system design details and `AUDIO_SYSTEM_DESIGN.md` for audio handling specifics.

## ✨ Features

### 🎯 Core Features
- **30-Second Segmented Recording**: Automatic audio segmentation for optimal transcription
- **Dual Transcription Engine**: OpenAI Whisper API with Apple Speech fallback
- **Background Recording**: Continue recording when app is in background
- **Real-time Transcription**: Live transcription display during recording
- **Audio Interruption Recovery**: Handle phone calls, Siri, and route changes
- **Encrypted Storage**: AES-GCM encryption for all audio files
- **SwiftData Integration**: Efficient data management for large datasets

### 🎨 User Interface
- **Modern SwiftUI Interface**: Clean, accessible design
- **Session Management**: View, search, and filter recording sessions
- **Real-time Audio Visualization**: Audio level meters and waveform display
- **Progress Tracking**: Transcription progress indicators
- **Network Status**: Real-time connectivity monitoring

### 🔧 Advanced Features
- **Configurable Audio Quality**: Sample rate, bit depth, and format settings
- **Noise Reduction**: Custom audio processing with configurable thresholds
- **Export Functionality**: Share recordings in multiple formats
- **iOS Widget**: Quick access to recording controls
- **Offline Support**: Queue transcriptions when network unavailable

## 📋 Requirements

### System Requirements
- **iOS 15.0+** (iOS 17.0+ recommended for latest features)
- **Xcode 15.0+**
- **Swift 5.9+**
- **macOS 13.0+** (for development)

### Dependencies
- **AVFoundation**: Audio recording and playback
- **Speech**: Local transcription
- **SwiftData**: Data persistence
- **CryptoKit**: File encryption
- **WidgetKit**: iOS widget support

## 🚀 Installation & Setup

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/AudioTranscriber.git
cd AudioTranscriber
```

### 2. Open in Xcode
```bash
open AudioTranscriber.xcodeproj
```

### 3. Configure API Keys

#### OpenAI API Key Setup
1. Get your OpenAI API key from [OpenAI Platform](https://platform.openai.com/api-keys)
2. Run the setup script:
```bash
swift store_api_key.swift
```
3. Enter your OpenAI API key when prompted

**Alternative Manual Setup:**
1. Open the app on your device
2. Go to **Settings** → **Transcription Settings**
3. Tap **Configure OpenAI API Key**
4. Enter your API key

### 4. Configure App Groups (for Widget)
1. In Xcode, select the project
2. Go to **Signing & Capabilities**
3. Add **App Groups** capability
4. Add group: `group.com.audiotranscriber.widget`
5. Repeat for both main app and widget extension

### 5. Build and Run
```bash
# Build for iOS Simulator
xcodebuild -project AudioTranscriber.xcodeproj -scheme AudioTranscriber -destination 'platform=iOS Simulator,name=iPhone 16' build

# Or use the provided script
./build_ios.sh
```

## 🎮 Usage Guide

### Recording Audio

#### Start Recording
1. Open the app
2. Ensure microphone permissions are granted
3. Tap the **red record button** to start recording
4. Speak clearly - you'll see real-time transcription

#### Recording Modes
- **Segmented Mode** (Default): Records in 30-second chunks
- **Legacy Mode**: Single continuous recording
- Toggle between modes in **Settings** → **Recording Mode**

#### During Recording
- **Pause/Resume**: Use the pause button to temporarily stop
- **Audio Level**: Monitor input levels with the visualizer
- **Live Transcription**: See real-time transcription in the dedicated box
- **Background**: Recording continues when app is backgrounded

#### Stop Recording
- Tap the **stop button** to end recording
- Segments will automatically be processed for transcription

### Managing Sessions

#### View Sessions
1. Tap **Sessions** button on main screen
2. Browse your recording sessions
3. Use search and filters to find specific recordings

#### Session Details
- **Session Info**: Duration, segment count, creation date
- **Transcription Status**: Progress indicators for each segment
- **Playback**: Tap segments to play audio
- **Export**: Share individual segments or entire sessions

#### Search & Filter
- **Search**: Find sessions by name or transcription content
- **Filter**: By status (completed, failed, in progress)
- **Sort**: By date, name, or duration

### Settings & Configuration

#### Audio Quality Settings
1. Tap **Quality** button
2. Choose from presets:
   - **Low**: 8kHz, 16-bit (smaller files)
   - **Medium**: 16kHz, 16-bit (balanced)
   - **High**: 44.1kHz, 16-bit (best quality)
   - **Custom**: Configure your own settings

#### Transcription Settings
1. Tap **Settings** → **Transcription Settings**
2. Choose transcription method:
   - **Local (Apple Speech)**: Fast, offline, lower accuracy
   - **OpenAI Whisper**: High accuracy, requires API key
   - **OpenAI + Local Fallback**: Best of both worlds

#### Noise Reduction
- Toggle noise reduction in main screen
- Adjust threshold in **Settings** → **Audio Quality**

## 🔧 Configuration Files

### Entitlements
- `AudioTranscriber.entitlements`: Background audio, app groups
- `AudioTranscriberWidget.entitlements`: Widget permissions

### Info.plist
- Microphone usage description
- Speech recognition usage description
- Background modes configuration

## 📱 Widget Setup

### Add Widget to Home Screen
1. Long press on home screen
2. Tap **+** button
3. Search for "AudioTranscriber"
4. Choose widget size and add

### Widget Features
- **Quick Recording**: Tap to start/stop recording
- **Session Status**: View recent recordings
- **Live Updates**: Real-time recording status

## 🧪 Testing

### Unit Tests
```bash
# Run unit tests
xcodebuild test -project AudioTranscriber.xcodeproj -scheme AudioTranscriber -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Manual Testing Checklist
- [ ] Recording starts/stops properly
- [ ] Background recording works
- [ ] Audio interruptions are handled
- [ ] Transcription completes successfully
- [ ] Widget updates correctly
- [ ] Search and filtering work
- [ ] Export functionality works

## 🐛 Troubleshooting

### Common Issues

#### Recording Not Starting
- Check microphone permissions in **Settings** → **Privacy & Security** → **Microphone**
- Ensure speech recognition is enabled
- Verify sufficient storage space (minimum 20MB)

#### Transcription Failing
- Check internet connection for OpenAI API
- Verify OpenAI API key is configured
- Check API quota and billing status
- Try switching to local transcription method

#### Background Recording Issues
- Ensure background audio capability is enabled
- Check device settings for background app refresh
- Verify app is not being terminated by iOS

#### Widget Not Working
- Check app groups configuration
- Verify widget extension is properly signed
- Restart device if widget data doesn't sync

### Debug Information
- Enable debug logging in **Settings** → **Debug**
- Check console output in Xcode
- Review log files in app documents directory

## 📊 Performance Considerations

### Memory Management
- Audio files are processed in chunks
- Temporary files are cleaned up automatically
- Background processing uses efficient queues

### Storage Optimization
- Audio files are encrypted and compressed
- Automatic cleanup of old recordings
- Configurable retention policies

### Battery Optimization
- Background tasks are optimized
- Audio processing is efficient
- Network requests are batched

## 🔒 Security & Privacy

### Data Protection
- All audio files are encrypted with AES-GCM
- API keys stored securely in Keychain
- No data transmitted without encryption

### Privacy Compliance
- Microphone access is clearly explained
- Speech recognition permissions are transparent
- User data is stored locally by default

## 🤝 Contributing

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

### Code Style
- Follow Swift style guidelines
- Add comments for complex logic
- Use meaningful variable names
- Include accessibility labels

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **OpenAI** for the Whisper API
- **Apple** for AVFoundation and Speech frameworks
- **SwiftUI** community for UI components
- **SwiftData** team for the data persistence framework

## 📞 Support

### Getting Help
- Check the troubleshooting section above
- Review the documentation files in the project
- Open an issue on GitHub for bugs
- Contact the development team for questions

### Documentation Files
- `ARCHITECTURE.md`: Comprehensive system architecture and design decisions
- `AUDIO_SYSTEM_DESIGN.md`: Detailed audio system design and interruption handling
- `DATA_MODEL_DESIGN.md`: SwiftData schema design and performance optimizations
- `KNOWN_ISSUES.md`: Current limitations and areas for improvement
- `WIDGET_SETUP_GUIDE.md`: Detailed widget configuration
- `RECORDINGS_GUIDE.md`: Recording management guide
- `TCC_CRASH_FIX_SUMMARY.md`: Technical issue solutions

---


## 💭 Developer Note

**I was actually traveling during the announcement and there was no way to cut short the work that I was already committed to, so I juggled working on this and things from my personal life so often. I had no proper sleep and had no Mac with me, so I had to rent one from the internet, which unfortunately gave no mic access. But finally, a friend lent me his Mac, even though i had limited access to it, it is where I have been building this app. This application was built in three states and late nights. This was an exciting project and I wish I could have completed this in better circumstances, but I am also very proud of what I have accomplished. Thank you.**
