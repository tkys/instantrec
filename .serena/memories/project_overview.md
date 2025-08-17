# InstantRec iOS App - Project Overview

## Purpose
InstantRec is a "lightning-fast startup recording app" designed around the concept of "instant recording on launch". The app starts recording audio immediately when the user taps the app icon, capturing ideas and voice memos before they fade from memory.

## Core Concept & Value Proposition
- **⚡ Lightning-fast startup**: App tap → instant recording start
- **🎯 Single-purpose focus**: Specialized in recording functionality with simple design
- **📊 Visual feedback**: Clear recording status display
- **🔄 Seamless experience**: Natural flow from stop → list → new recording
- **🤖 AI voice recognition**: High-precision voice-to-text using WhisperKit
- **☁️ Cloud integration**: Automatic backup to Google Drive
- **🎚️ Audio enhancement**: Scene-specific recording modes and audio optimization

## Target Users
- People who need to quickly capture thoughts and ideas
- Professionals who frequently take voice memos
- Anyone who values speed and simplicity in audio recording

## Technical Overview
- **Platform**: iOS 17.0+
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI with MVVM architecture
- **Data Persistence**: SwiftData
- **Audio Processing**: AVFoundation
- **AI Transcription**: WhisperKit (CoreML)
- **Cloud Integration**: Google Drive API
- **Build System**: XcodeGen + CocoaPods

## Key Features
### Core Features (MVP)
- Instant recording on app launch
- Large stop button (most of screen tappable)
- Recording file list with timestamps and duration
- Audio playback functionality
- Swipe to delete

### Enhanced Features
- Real-time audio level meter with visual feedback
- Smart time display (relative/absolute)
- Favorite recordings with star system
- In-list playback system with global state management
- Share functionality (AirDrop, email, cloud services)

### Advanced Features
- AI voice recognition with 5 model options (WhisperKit)
- Google Drive automatic backup
- Audio enhancement system with 5 recording modes
- Segmented recording for long sessions (15min auto-split)
- Customization settings for recording behavior

## Performance Metrics
- **Startup time**: < 300ms (app tap to recording start)
- **Recording start**: < 100ms (with permissions granted)
- **UI responsiveness**: 60fps maintained
- **Memory usage**: < 150MB (normal recording)
- **Battery efficiency**: ~10% per hour of recording