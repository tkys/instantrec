# InstantRec - Essential Development Commands

## Project Setup & Build Commands

### Initial Setup
```bash
# Clone and setup project
git clone <repository-url>
cd instantrec

# Install CocoaPods dependencies (required for Google Drive integration)
pod install

# Generate Xcode project (if needed)
xcodegen generate

# Open workspace (IMPORTANT: Use .xcworkspace, not .xcodeproj)
open InstantRec.xcworkspace
```

### Build Commands
```bash
# Build for iOS Simulator
xcodebuild -workspace InstantRec.xcworkspace -scheme InstantRec -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' build

# Build for device
xcodebuild -workspace InstantRec.xcworkspace -scheme InstantRec -configuration Debug -destination 'platform=iOS,name=Your iPhone' build

# Clean build artifacts
xcodebuild -workspace InstantRec.xcworkspace -scheme InstantRec clean
```

## Testing & Validation

### Quick Project Test
```bash
# Run built-in project structure test
swift quick_test.swift

# Manual test checklist (refer to ManualTestPlan.md)
# 1. Test app launch and permissions
# 2. Test recording functionality
# 3. Test playback features
# 4. Test settings and configuration
```

### File Structure Validation
```bash
# Check core app files exist
ls -la Sources/instantrec/App/InstantRecordApp.swift
ls -la Sources/instantrec/ViewModels/RecordingViewModel.swift
ls -la Sources/instantrec/Services/AudioService.swift

# Verify build configuration
ls -la project.yml Podfile InstantRec.xcworkspace
```

## Development Workflow

### Code Generation & Updates
```bash
# Regenerate Xcode project after modifying project.yml
xcodegen generate

# Update CocoaPods dependencies
pod install
pod update

# Update Swift Package Manager dependencies (in Xcode: File > Packages > Update to Latest Package Versions)
```

### Debugging & Diagnostics
```bash
# View simulator logs
xcrun simctl spawn booted log stream --predicate 'eventMessage contains "InstantRec"'

# Check app installation on simulator
xcrun simctl list devices | grep Booted
```

## macOS/Darwin-Specific Commands

### System Information
```bash
# Check Xcode version and tools
xcode-select --print-path
xcodebuild -version
swift --version

# Check available simulators
xcrun simctl list devices available

# System resource monitoring (for development)
top -pid $(pgrep InstantRec)
```

### File Management
```bash
# Find files with specific patterns
find Sources/instantrec -name "*.swift" -type f
mdfind -name "InstantRec" -onlyin ~/Library/Developer

# Check app bundle structure
ls -la ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug-iphonesimulator/InstantRec.app/
```

## Git & Version Control

### Standard Git Workflow
```bash
# Check repository status
git status
git log --oneline -10

# Create feature branch
git checkout -b feature/new-feature-name
git add .
git commit -m "✨ Add new feature description"

# Push changes
git push origin feature/new-feature-name
```

### Project-Specific Git Commands
```bash
# Check large files (WhisperKit models are gitignored)
git ls-files --others --ignored --exclude-standard
du -sh Sources/instantrec/Resources/WhisperKitModels*/

# Commit with project emoji convention
git commit -m "🎙️ Audio recording improvements"
git commit -m "🤖 WhisperKit transcription enhancements"
git commit -m "☁️ Google Drive sync optimizations"
```

## Search & Analysis

### Code Search
```bash
# Find specific patterns in codebase
grep -r "AVAudioRecorder" Sources/instantrec --include="*.swift"
grep -r "WhisperKit" Sources/instantrec --include="*.swift"
grep -r "// MARK:" Sources/instantrec --include="*.swift"

# Find TODO and FIXME items
grep -r "TODO\|FIXME" Sources/instantrec --include="*.swift"

# Check for performance-critical sections
grep -r "PERFORMANCE\|optimization" Sources/instantrec --include="*.swift"
```

### Project Analysis
```bash
# Count lines of code
find Sources/instantrec -name "*.swift" -exec wc -l {} + | tail -1

# Check for memory leaks patterns
grep -r "\[weak self\]" Sources/instantrec --include="*.swift"
grep -r "Timer\|timer" Sources/instantrec --include="*.swift"

# Analyze imports and dependencies
grep -r "^import " Sources/instantrec --include="*.swift" | sort | uniq -c
```

## Utility Commands

### Documentation Generation
```bash
# Generate documentation from code comments
swift package generate-documentation

# Check markdown files for issues
find . -name "*.md" -exec markdown-lint {} \;
```

### Performance & Monitoring
```bash
# Monitor app performance (when running)
instruments -t "Time Profiler" -D trace_output.trace InstantRec.app

# Check disk space (important for long recordings)
df -h
du -sh Sources/instantrec/Resources/
```

## Task Completion Checklist

When completing a development task:

1. **Build & Test**: `xcodebuild -workspace InstantRec.xcworkspace -scheme InstantRec build`
2. **Run Quick Test**: `swift quick_test.swift`
3. **Manual Testing**: Follow ManualTestPlan.md
4. **Code Review**: Check for memory leaks, performance issues
5. **Documentation**: Update relevant .md files if needed
6. **Commit**: Use appropriate emoji and descriptive message
7. **Verify**: Ensure all files build without warnings