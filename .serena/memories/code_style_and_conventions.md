# InstantRec - Code Style & Conventions

## Naming Conventions

### File Naming
- **Swift Files**: PascalCase (e.g., `RecordingViewModel.swift`, `AudioService.swift`)
- **Group Organization**: Logical grouping by functionality (Models, Views, ViewModels, Services, Utils)
- **Resource Files**: Descriptive names (e.g., `Localizable.strings`, `GoogleSignInConfiguration.plist`)

### Class & Struct Naming
- **Classes**: PascalCase with descriptive names (e.g., `RecordingViewModel`, `AudioService`)
- **Structs**: PascalCase for models (e.g., `Recording`, `CloudSyncStatus`)
- **Enums**: PascalCase with descriptive cases (e.g., `RecordingMode`, `PermissionStatus`)

### Property & Method Naming
- **Properties**: camelCase with clear intent (e.g., `isRecording`, `elapsedTime`, `memoryPressureLevel`)
- **Methods**: camelCase with action verbs (e.g., `startRecording()`, `updateElapsedTime()`, `handleAppDidEnterBackground()`)
- **Boolean Properties**: Prefixed with `is`, `has`, `can`, `should` (e.g., `isLongRecording`, `canRetryOperation`)

## Code Organization

### MARK Comments
Consistent use of `// MARK: -` for section organization:
```swift
class RecordingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    
    // MARK: - Private Properties  
    private let audioService = AudioService.shared
    
    // MARK: - Lifecycle Methods
    func setup(modelContext: ModelContext) { }
    
    // MARK: - Recording Management
    func startRecording() { }
    
    // MARK: - Error Handling Methods
    private func handleAudioServiceError(_ error: AudioServiceError) { }
}
```

### SwiftUI View Structure
```swift
struct RecordingView: View {
    // MARK: - Properties
    @StateObject private var viewModel: RecordingViewModel
    @EnvironmentObject private var themeService: AppThemeService
    
    // MARK: - Body
    var body: some View {
        // View implementation
    }
    
    // MARK: - Helper Methods
    private func handleRecordingTap() { }
}
```

## Language & Framework Patterns

### SwiftUI Patterns
- **State Management**: `@StateObject` for ViewModels, `@ObservedObject` for passed objects
- **Environment Objects**: Shared services passed down the view hierarchy
- **Property Wrappers**: `@Published` for reactive properties in ViewModels
- **Modifiers**: Chainable modifiers for clean, readable UI code

### Swift Language Features
- **Optionals**: Proper unwrapping with `guard let`, `if let`, nil coalescing
- **Error Handling**: `do-catch` blocks, custom error types conforming to `LocalizedError`
- **Closures**: Trailing closure syntax, `[weak self]` for memory safety
- **Extensions**: Utility extensions in separate files (e.g., `DateFormatter+Extensions.swift`)

### Async/Await Usage
```swift
// Background operations
Task {
    await whisperService.transcribeAudio(fileURL: recordingURL)
}

// UI updates on main queue
await MainActor.run {
    self.isTranscribing = false
}
```

## Documentation & Comments

### Method Documentation
```swift
/// Starts long-term recording monitoring for sessions exceeding threshold
/// - Note: Monitors memory usage, disk space, and system resources
/// - Warning: Must be called on main thread for UI updates
private func startLongRecordingMonitoring() {
    // Implementation
}
```

### Inline Comments
- **Japanese Comments**: Used for domain-specific functionality (録音監視機能)
- **English Comments**: Technical implementation details
- **Performance Notes**: Critical performance sections marked with specific comments

### TODO & FIXME
```swift
// TODO: Implement advanced noise cancellation
// FIXME: Memory leak in timer invalidation
// MARK: - PERFORMANCE: Critical path for startup time
```

## Type Safety & Best Practices

### Strong Typing
- Explicit types for public APIs
- Type inference for internal implementation
- Custom types for domain concepts (e.g., `RecordingStartMode` enum)

### Memory Management
- `[weak self]` in closures that outlive the object
- Proper `deinit` implementation for cleanup
- Timer invalidation and resource cleanup

### Error Handling
```swift
enum AudioServiceError: LocalizedError {
    case permissionDenied
    case diskSpaceInsufficient(available: Int64, required: Int64)
    case sessionConfigurationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "マイクロフォンアクセスが拒否されました"
        // ... other cases
        }
    }
}
```

## Performance Considerations

### Startup Optimization
- Minimal work in `init()` methods
- Lazy initialization of expensive resources
- Deferred setup operations

### UI Performance
- Background queues for heavy operations
- Throttled updates for high-frequency events
- Efficient SwiftUI view updates with minimal re-rendering