# InstantRec - Task Completion Guidelines

## When a Task is Completed

### 1. Build Verification (MANDATORY)
```bash
# Always verify the project builds successfully
xcodebuild -workspace InstantRec.xcworkspace -scheme InstantRec -configuration Debug build

# If build fails, fix all compilation errors before proceeding
# Common issues: Missing imports, syntax errors, type mismatches
```

### 2. Quick Test Execution
```bash
# Run the project's built-in test script
swift quick_test.swift

# This checks:
# - File structure integrity
# - Configuration files presence
# - Build artifacts existence
# - Dependencies status
```

### 3. Manual Testing Protocol

#### Core Functionality Testing
- **App Launch**: Verify instant recording startup
- **Recording**: Test start, pause, resume, stop functionality
- **Playback**: Ensure audio files play correctly
- **UI Responsiveness**: Check 60fps performance and smooth animations
- **Memory Usage**: Monitor for memory leaks during long operations

#### Feature-Specific Testing
- **WhisperKit**: Test transcription accuracy and performance
- **Google Drive**: Verify cloud backup functionality
- **Settings**: Confirm configuration changes take effect
- **Long Recording**: Test stability for extended sessions

### 4. Code Quality Checks

#### Memory Management
```bash
# Search for potential memory leaks
grep -r "Timer\|timer" Sources/instantrec --include="*.swift"
grep -r "\[weak self\]" Sources/instantrec --include="*.swift"

# Verify proper cleanup in deinit methods
grep -r "deinit" Sources/instantrec --include="*.swift"
```

#### Performance Patterns
```bash
# Check for performance-critical sections
grep -r "DispatchQueue\|Task\|async" Sources/instantrec --include="*.swift"
grep -r "PERFORMANCE\|optimization" Sources/instantrec --include="*.swift"
```

### 5. Documentation Updates

#### Required Updates
- Update README.md if new features added
- Modify technical documentation for architectural changes
- Add comments for complex algorithms or performance-critical code
- Update DEVELOPMENT_LOG.md with significant changes

#### Code Documentation
```swift
/// Description of method purpose and behavior
/// - Parameter param: Description of parameter
/// - Returns: Description of return value
/// - Note: Important implementation details
/// - Warning: Potential pitfalls or requirements
func methodName(param: Type) -> ReturnType {
    // Implementation
}
```

### 6. Git Commit Standards

#### Commit Message Format
```bash
# Use emoji prefixes for clear categorization
git commit -m "🎙️ Add audio recording feature"
git commit -m "🤖 Improve WhisperKit transcription accuracy"
git commit -m "☁️ Fix Google Drive sync issue"
git commit -m "🔧 Performance optimization for startup time"
git commit -m "🐛 Fix memory leak in timer management"
git commit -m "📝 Update documentation for new API"
```

#### Emoji Convention
- 🎙️ Audio recording features
- 🤖 AI/WhisperKit transcription
- ☁️ Cloud/Google Drive integration
- 🔧 Performance improvements
- 🐛 Bug fixes
- 📝 Documentation
- ✨ New features
- 🎨 UI/UX improvements
- 🔒 Security enhancements

### 7. Performance Verification

#### Startup Performance
- App launch to recording start: < 300ms target
- UI responsiveness: No frame drops during critical operations
- Memory usage: Monitor for excessive allocations

#### Runtime Performance
- Audio processing: Real-time performance without glitches
- UI updates: Smooth animations and transitions
- Background tasks: Efficient resource usage

### 8. Error Handling Verification

#### Test Error Scenarios
- Microphone permission denied
- Insufficient disk space
- Network connectivity issues (for cloud features)
- App backgrounding during recording
- System interruptions (phone calls, etc.)

### 9. Final Checklist

Before marking a task as complete:

- [ ] ✅ Project builds without errors or warnings
- [ ] ✅ Quick test script passes
- [ ] ✅ Manual testing completed for affected areas
- [ ] ✅ Memory leaks checked and resolved
- [ ] ✅ Performance impact assessed and optimized
- [ ] ✅ Error handling tested for edge cases
- [ ] ✅ Documentation updated as needed
- [ ] ✅ Code committed with appropriate message
- [ ] ✅ Related features still work correctly (regression testing)

### 10. Continuous Integration Mindset

#### Code Quality Standards
- No force unwrapping of optionals in production code
- Proper error handling with LocalizedError conformance
- Background thread usage for heavy operations
- SwiftUI best practices for state management

#### Performance Standards
- Startup time under 300ms
- 60fps UI performance
- Memory usage under 150MB for normal operations
- Efficient battery usage for long recordings

### 11. Rollback Procedure

If issues are discovered after task completion:

```bash
# Check recent commits
git log --oneline -5

# Create backup branch
git checkout -b backup-before-rollback

# Rollback to previous working state
git reset --hard <previous-commit-hash>

# Or revert specific changes
git revert <problematic-commit-hash>
```

Remember: **Quality over speed**. It's better to take time ensuring proper implementation than to rush and create technical debt or performance issues.