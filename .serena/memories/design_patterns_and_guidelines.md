# InstantRec - Design Patterns & Development Guidelines

## Architectural Patterns

### MVVM Pattern Implementation
```swift
// ViewModel: Business logic and state management
class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var elapsedTime: TimeInterval = 0
    
    private let audioService = AudioService.shared
    
    func startRecording() {
        // Business logic here
    }
}

// View: UI declaration and user interaction
struct RecordingView: View {
    @StateObject private var viewModel = RecordingViewModel()
    
    var body: some View {
        // SwiftUI view declaration
    }
}
```

### Singleton Pattern for Services
```swift
class AudioService: ObservableObject {
    static let shared = AudioService()
    
    private init() {
        // Private initializer for singleton
    }
    
    // Service methods
}
```

### Observer Pattern with Combine
```swift
class ViewModelExample: ObservableObject {
    @Published var state: State = .initial
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Setup publishers and subscribers
        NotificationCenter.default
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleBackgroundTransition()
            }
            .store(in: &cancellables)
    }
}
```

## SwiftUI Best Practices

### State Management Hierarchy
```swift
@main
struct InstantRecApp: App {
    @StateObject private var appState = AppStateManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)  // Inject at top level
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppStateManager
    @StateObject private var viewModel = RecordingViewModel()
    
    var body: some View {
        // View implementation
    }
}
```

### Performance-Optimized Views
```swift
struct OptimizedListItem: View {
    let recording: Recording
    
    var body: some View {
        HStack {
            // Minimize view updates with computed properties
            Text(recording.formattedDate)
            Spacer()
            Text(recording.formattedDuration)
        }
        .id(recording.id)  // Stable identity for list performance
    }
}
```

## Service Design Patterns

### Service Layer Architecture
```swift
protocol AudioServiceProtocol {
    func startRecording() async throws
    func stopRecording() async throws
    var isRecording: Bool { get }
}

class AudioService: AudioServiceProtocol, ObservableObject {
    @Published var isRecording = false
    
    // Implementation with error handling
    func startRecording() async throws {
        do {
            // Audio recording logic
            await MainActor.run {
                self.isRecording = true
            }
        } catch {
            throw AudioServiceError.recordingFailed(error)
        }
    }
}
```

### Error Handling Pattern
```swift
enum AudioServiceError: LocalizedError {
    case permissionDenied
    case hardwareNotAvailable
    case diskSpaceInsufficient
    case recordingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "マイクロフォンアクセスが必要です"
        case .hardwareNotAvailable:
            return "オーディオハードウェアが利用できません"
        case .diskSpaceInsufficient:
            return "ストレージ容量が不足しています"
        case .recordingFailed(let error):
            return "録音に失敗しました: \(error.localizedDescription)"
        }
    }
}
```

## Memory Management Patterns

### Weak Reference Pattern
```swift
class RecordingViewModel: ObservableObject {
    private var timer: Timer?
    
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
        }
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
}
```

### Resource Cleanup Pattern
```swift
class AudioService: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    func setupAudioEngine() throws {
        audioEngine = AVAudioEngine()
        // Setup logic
    }
    
    func cleanup() {
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
    }
    
    deinit {
        cleanup()
    }
}
```

## Performance Optimization Patterns

### Lazy Initialization
```swift
class ExpensiveService {
    private lazy var whisperKit: WhisperKit? = {
        do {
            return try WhisperKit()
        } catch {
            print("Failed to initialize WhisperKit: \(error)")
            return nil
        }
    }()
    
    func performTranscription() async {
        guard let whisperKit = whisperKit else { return }
        // Use whisperKit
    }
}
```

### Background Processing Pattern
```swift
class DataProcessor: ObservableObject {
    @Published var isProcessing = false
    
    func processLargeDataset() async {
        await MainActor.run {
            isProcessing = true
        }
        
        // Heavy processing on background queue
        let result = await withTaskGroup(of: ProcessedItem.self) { group in
            // Parallel processing
        }
        
        await MainActor.run {
            isProcessing = false
            // Update UI with results
        }
    }
}
```

## UI/UX Design Guidelines

### Accessibility First Design
```swift
struct AccessibleButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(title, action: action)
            .accessibilityLabel(title)
            .accessibilityHint("Double tap to activate")
            .accessibilityAddTraits(.isButton)
            .font(.title2)  // Support Dynamic Type
    }
}
```

### Responsive Design Pattern
```swift
struct AdaptiveLayout: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    
    var body: some View {
        if sizeClass == .compact {
            VStack { contentViews }  // Phone layout
        } else {
            HStack { contentViews }  // iPad layout
        }
    }
    
    @ViewBuilder
    var contentViews: some View {
        // Shared content
    }
}
```

## Testing Patterns

### Testable Service Design
```swift
protocol AudioServiceProtocol {
    func startRecording() async throws
    func stopRecording() async throws
}

class AudioService: AudioServiceProtocol {
    // Implementation
}

class MockAudioService: AudioServiceProtocol {
    var shouldFailRecording = false
    
    func startRecording() async throws {
        if shouldFailRecording {
            throw AudioServiceError.recordingFailed(NSError())
        }
    }
    
    func stopRecording() async throws {
        // Mock implementation
    }
}
```

## Security Patterns

### Secure Data Handling
```swift
class SecureSettings {
    private let keychain = KeychainService()
    
    func storeAPIKey(_ key: String) {
        keychain.store(key, forAccount: "google-drive-api")
    }
    
    func retrieveAPIKey() -> String? {
        return keychain.retrieve(forAccount: "google-drive-api")
    }
}
```

### Permission Handling Pattern
```swift
class PermissionManager: ObservableObject {
    @Published var microphonePermission: PermissionStatus = .unknown
    
    func requestMicrophonePermission() async {
        let permission = await AVAudioSession.sharedInstance().requestRecordPermission()
        
        await MainActor.run {
            microphonePermission = permission ? .granted : .denied
        }
    }
}
```

## Code Organization Guidelines

### File Organization Pattern
- One primary type per file
- Related extensions in the same file
- Utility extensions in separate files
- Group related functionality in folders

### Documentation Standards
```swift
/// Manages audio recording functionality for the InstantRec app
/// 
/// This service handles:
/// - Microphone permission management
/// - Audio session configuration
/// - Recording start/stop operations
/// - Audio file management
///
/// - Important: Always call methods on the main thread for UI updates
/// - Warning: Requires microphone permissions before use
class AudioService: ObservableObject {
    
    /// Current recording state
    /// - Note: KVO observable for SwiftUI integration
    @Published var isRecording = false
    
    /// Starts audio recording session
    /// - Throws: `AudioServiceError` if recording cannot be started
    /// - Returns: URL of the created recording file
    func startRecording() async throws -> URL {
        // Implementation
    }
}
```

These patterns ensure maintainable, performant, and scalable code that follows iOS development best practices while meeting the specific needs of the InstantRec application.