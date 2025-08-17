import SwiftUI
import SwiftData
import UIKit

// MARK: - Expert UX Optimizations
// Implements professional iOS design patterns based on HIG and modern UX principles


struct RecordingsListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var recordingViewModel: RecordingViewModel
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]
    @State private var recordingToShare: Recording?
    @State private var selectedRecording: Recording?
    @State private var showingStatusHelp = false
    
    // 文字起こし進捗表示用
    @StateObject private var whisperService = WhisperKitTranscriptionService.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 文字起こし進捗表示（実行中のみ表示）
                if whisperService.isTranscribing {
                    TranscriptionProgressView(
                        progress: Float(whisperService.transcriptionProgress),
                        stage: whisperService.transcriptionStage,
                        estimatedTimeRemaining: nil
                    )
                    .padding(.horizontal, HierarchicalSpacing.level3)
                    .padding(.top, HierarchicalSpacing.level4)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                    .animation(.easeInOut(duration: 0.3), value: whisperService.isTranscribing)
                }
                
                ScrollView {
                    LazyVStack(spacing: HierarchicalSpacing.level2) {
                        ForEach(recordings) { recording in
                            EnhancedRecordingCard(
                                recording: recording, 
                                recordingToShare: $recordingToShare,
                                selectedRecording: $selectedRecording,
                                modelContext: modelContext
                            )
                            // Professional swipe actions for direct manipulation
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    deleteRecordingWithHaptics(recording)
                                }
                                .tint(.red)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button("Share", systemImage: "square.and.arrow.up") {
                                    shareRecordingWithHaptics(recording)
                                }
                                .tint(ListUITheme.primaryColor)
                                
                                Button(recording.isFavorite ? "Unfavorite" : "Favorite", 
                                       systemImage: recording.isFavorite ? "star.slash" : "star.fill") {
                                    toggleFavoriteWithHaptics(recording)
                                }
                                .tint(ListUITheme.warningColor)
                            }
                            // Enhanced context menu with better organization
                            .contextMenu {
                                // Primary Actions
                                Section {
                                    Button("Play", systemImage: "play.fill") {
                                        playRecording(recording)
                                    }
                                    Button("Share", systemImage: "square.and.arrow.up") {
                                        shareRecordingWithHaptics(recording)
                                    }
                                }
                                
                                // Secondary Actions
                                Section {
                                    Button("Rename", systemImage: "pencil") {
                                        // TODO: Implement rename functionality
                                    }
                                    Button(recording.isFavorite ? "Unfavorite" : "Favorite", 
                                           systemImage: recording.isFavorite ? "star.slash" : "star.fill") {
                                        toggleFavoriteWithHaptics(recording)
                                    }
                                }
                                
                                // Destructive Actions
                                Section {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        deleteRecordingWithHaptics(recording)
                                    }
                                }
                            } preview: {
                                // Context menu preview
                                RecordingPreviewCard(recording: recording)
                                    .frame(width: 250, height: 120)
                            }
                        }
                    }
                    .padding(.horizontal, HierarchicalSpacing.level3)
                    .padding(.top, HierarchicalSpacing.level4)
                }
            }
            .navigationTitle("recordings_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Status Guide", systemImage: "questionmark.circle") {
                        showingStatusHelp = true
                    }
                    .foregroundColor(.blue)
                }
            }
            .sheet(item: $recordingToShare) { recording in
                SmartActivityView(recording: recording)
                    .onAppear {
                        print("🎯 RecordingsList: Presenting SmartActivityView for recording: \(recording.fileName)")
                    }
            }
            .sheet(item: $selectedRecording) { recording in
                RecordingDetailView(recording: recording, modelContext: modelContext)
            }
            .sheet(isPresented: $showingStatusHelp) {
                StatusIconHelpSheet()
            }
        }
    }

    // MARK: - Enhanced Actions with Haptic Feedback
    
    private func deleteRecordingWithHaptics(_ recording: Recording) {
        // Haptic feedback for destructive action
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(.warning)
        
        let viewModel = RecordingsListViewModel(modelContext: modelContext)
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.deleteRecording(recording)
        }
    }
    
    private func shareRecordingWithHaptics(_ recording: Recording) {
        // Haptic feedback for action
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator.impactOccurred()
        
        recordingToShare = recording
    }
    
    private func toggleFavoriteWithHaptics(_ recording: Recording) {
        // Haptic feedback for toggle action
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(.success)
        
        withAnimation(.easeInOut(duration: 0.2)) {
            recording.isFavorite.toggle()
            try? modelContext.save()
        }
    }
    
    private func playRecording(_ recording: Recording) {
        // Haptic feedback for playback
        let impactGenerator = UIImpactFeedbackGenerator(style: .light)
        impactGenerator.impactOccurred()
        
        PlaybackManager.shared.play(recording: recording)
    }
    
}

// MARK: - Hierarchical Spacing System (Professional UX)
/// Expert-level spatial design following iOS HIG principles
struct HierarchicalSpacing {
    static let level1: CGFloat = 32  // Major sections (Navigation to content)
    static let level2: CGFloat = 20  // Content groups (Between cards)
    static let level3: CGFloat = 16  // Related elements (Container padding)
    static let level4: CGFloat = 12  // Sub-elements (Minor spacing)
    static let level5: CGFloat = 8   // Tight coupling (Icon to text)
    static let level6: CGFloat = 4   // Minimal spacing (Stack elements)
}

// MARK: - Context Menu Preview Card
struct RecordingPreviewCard: View {
    let recording: Recording
    
    var body: some View {
        VStack(alignment: .leading, spacing: HierarchicalSpacing.level4) {
            HStack {
                VStack(alignment: .leading, spacing: HierarchicalSpacing.level6) {
                    Text(recording.displayName)
                        .font(ListUITheme.subtitleFont)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(recording.relativeTimeString)
                        .font(ListUITheme.captionFont)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicators
                HStack(spacing: HierarchicalSpacing.level6) {
                    if recording.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(ListUITheme.warningColor)
                            .font(.caption)
                    }
                    
                    if recording.transcription != nil {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(ListUITheme.infoColor)
                            .font(.caption)
                    }
                }
            }
            
            // Duration and waveform placeholder
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(ListUITheme.primaryColor)
                
                Text(formatDuration(recording.duration))
                    .font(ListUITheme.captionFont)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Play button
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundColor(ListUITheme.primaryColor)
            }
        }
        .padding(HierarchicalSpacing.level3)
        .background(Color(.systemBackground))
        .cornerRadius(ListUITheme.cardCornerRadius)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Enhanced Recording Card

struct EnhancedRecordingCard: View {
    let recording: Recording
    @Binding var recordingToShare: Recording?
    @Binding var selectedRecording: Recording?
    let modelContext: ModelContext
    @StateObject private var playbackManager = PlaybackManager.shared
    
    var body: some View {
        UnifiedRecordingCard(
            recording: recording,
            showTranscriptionPreview: true,
            onPlayTap: {
                playbackManager.play(recording: recording)
            },
            onDetailTap: {
                selectedRecording = recording
            },
            onFavoriteTap: {
                toggleFavorite()
            },
            onShareTap: {
                recordingToShare = recording
            },
            isPlaying: playbackManager.isPlayingRecording(recording)
        )
        // MARK: - Professional Accessibility Implementation
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to view details, or use the actions rotor for more options")
        .accessibilityAction(named: "Play Recording") { 
            playRecordingWithAccessibilityAnnouncement() 
        }
        .accessibilityAction(named: "Share Recording") { 
            shareRecordingWithAccessibilityAnnouncement() 
        }
        .accessibilityAction(named: recording.isFavorite ? "Remove from Favorites" : "Add to Favorites") { 
            toggleFavoriteWithAccessibilityAnnouncement() 
        }
        .accessibilityAction(named: "Delete Recording") { 
            // Show confirmation for destructive action
            deleteRecordingWithAccessibilityConfirmation() 
        }
        // Dynamic Type support
        .dynamicTypeSize(.large...DynamicTypeSize.accessibility3)
    }
    
    // MARK: - Accessibility Helpers
    
    private var accessibilityDescription: String {
        var description = "Recording: \(recording.displayName)"
        description += ", Duration: \(formatDuration(recording.duration))"
        description += ", Created: \(recording.relativeTimeString)"
        
        if recording.isFavorite {
            description += ", Favorited"
        }
        
        if let transcription = recording.transcription, !transcription.isEmpty {
            description += ", Has transcription available"
        }
        
        if playbackManager.isPlayingRecording(recording) {
            description += ", Currently playing"
        }
        
        switch recording.cloudSyncStatus {
        case .synced:
            description += ", Synced to cloud"
        case .uploading:
            description += ", Uploading to cloud"
        case .error:
            description += ", Cloud sync failed"
        default:
            break
        }
        
        return description
    }
    
    private func playRecordingWithAccessibilityAnnouncement() {
        playbackManager.play(recording: recording)
        
        // Accessibility announcement
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIAccessibility.post(notification: .announcement, 
                               argument: "Playing \(recording.displayName)")
        }
    }
    
    private func shareRecordingWithAccessibilityAnnouncement() {
        recordingToShare = recording
        UIAccessibility.post(notification: .announcement, 
                           argument: "Share options for \(recording.displayName) opened")
    }
    
    private func toggleFavoriteWithAccessibilityAnnouncement() {
        withAnimation(.easeInOut(duration: 0.2)) {
            recording.isFavorite.toggle()
            try? modelContext.save()
            
            let message = recording.isFavorite ? 
                "\(recording.displayName) added to favorites" : 
                "\(recording.displayName) removed from favorites"
            
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
    
    private func deleteRecordingWithAccessibilityConfirmation() {
        // For accessibility, provide immediate feedback
        UIAccessibility.post(notification: .announcement, 
                           argument: "Delete confirmation required for \(recording.displayName). Use context menu or swipe action to confirm.")
    }
    
    private func toggleFavorite() {
        withAnimation(.easeInOut(duration: 0.2)) {
            recording.isFavorite.toggle()
            try? modelContext.save()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d minutes and %02d seconds", minutes, seconds)
    }
}

// MARK: - Legacy Status Icons (deprecated - use UnifiedStatusIndicator instead)
// These components are kept for compatibility but should be replaced with UnifiedStatusIndicator

