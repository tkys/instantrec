# InstantRec - Tech Stack & Architecture

## Core Technology Stack

### Programming Language & Frameworks
- **Swift 5.9+**: Primary language
- **SwiftUI**: Declarative UI framework for rapid development and minimal startup impact
- **SwiftData**: Data persistence with high SwiftUI compatibility
- **AVFoundation**: Native iOS audio processing framework
- **WhisperKit**: AI transcription using CoreML optimization
- **Google Drive API**: Cloud backup integration

### Architecture Pattern
- **MVVM (Model-View-ViewModel)**: Separation of UI logic and business logic
- **Observable Objects**: SwiftUI-native reactive pattern using `@Observable` and `@StateObject`
- **Singleton Services**: Core services like AudioService, WhisperKitTranscriptionService use shared instances
- **Dependency Injection**: Services injected into ViewModels through environment objects

### iOS Platform Requirements
- **Minimum iOS Version**: 17.0
- **Target Devices**: iPhone (primary), iPad (supported)
- **Orientation Support**: Portrait (primary), Landscape (secondary)

## Project Structure

```
InstantRec/
├── Sources/instantrec/
│   ├── App/
│   │   └── InstantRecordApp.swift      # App entry point with SwiftUI App lifecycle
│   ├── Models/                         # SwiftData models
│   │   ├── Recording.swift             # Core recording data model
│   │   ├── CloudSyncStatus.swift       # Cloud sync state management
│   │   ├── BackupSettings.swift        # Configuration settings
│   │   └── RecordingStartMode.swift     # Recording behavior modes
│   ├── ViewModels/                     # MVVM ViewModels
│   │   ├── RecordingViewModel.swift     # Main recording logic
│   │   ├── RecordingsListViewModel.swift # List management
│   │   └── AppStateManager.swift        # Global app state
│   ├── Views/                          # SwiftUI Views
│   │   ├── RecordingView.swift         # Main recording interface
│   │   ├── RecordingsListView.swift    # Recording list display
│   │   ├── SettingsView.swift          # App configuration
│   │   ├── ListUIComponents.swift      # Reusable UI components
│   │   └── [Other specialized views]
│   ├── Services/                       # Business logic services
│   │   ├── AudioService.swift          # Core audio recording
│   │   ├── WhisperKitTranscriptionService.swift # AI transcription
│   │   ├── GoogleDriveService.swift    # Cloud backup
│   │   ├── PlaybackManager.swift       # Audio playback
│   │   ├── MemoryMonitorService.swift  # Performance monitoring
│   │   └── [Other specialized services]
│   ├── Utils/                          # Utility extensions
│   │   ├── DateFormatter+Extensions.swift
│   │   └── TimeInterval+Extensions.swift
│   ├── Resources/                      # Localization and assets
│   └── Info.plist                     # App configuration
```

## Build System & Dependencies

### Project Configuration
- **XcodeGen**: Project file generation from `project.yml`
- **Swift Package Manager**: WhisperKit and other Swift packages
- **CocoaPods**: Google Drive API and authentication libraries

### Key Dependencies
```yaml
# Swift Package Manager
- WhisperKit: AI transcription (CoreML optimized)

# CocoaPods  
- GoogleAPIClientForREST/Drive: Google Drive integration
- GoogleSignIn: OAuth2 authentication
```

### Development Tools
- **Xcode 15.4+**: Primary IDE
- **iOS Simulator**: Testing environment
- **Swift Playgrounds**: Quick prototyping (optional)

## Performance Optimization Principles

### Startup Performance (Critical)
- Minimal initialization in app launch
- No splash screens
- Deferred heavy operations
- Lazy loading of non-essential services

### Memory Management
- Automatic reference counting (ARC)
- Memory monitoring service for long recordings
- Periodic cleanup of temporary resources
- Efficient audio buffer management

### UI Responsiveness
- 60fps target for all animations
- Background queues for heavy operations
- Throttled UI updates for performance-critical paths
- SwiftUI's native optimization features