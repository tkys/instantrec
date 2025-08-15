import SwiftUI

// MARK: - List画面用統一UIコンポーネントシステム

/// List画面専用のUIテーマ定義
struct ListUITheme {
    // MARK: - Color System
    static let primaryColor = Color.blue      // メインアクション
    static let successColor = Color.green     // 完了・同期済み
    static let warningColor = Color.orange    // 編集・注意
    static let dangerColor = Color.red        // 削除・エラー
    static let infoColor = Color.purple       // 文字起こし・情報
    static let neutralColor = Color.gray      // 非アクティブ
    
    // MARK: - Typography
    static let titleFont = Font.title2         // メインヘッダー
    static let subtitleFont = Font.headline    // サブタイトル
    static let bodyFont = Font.subheadline     // 本文テキスト
    static let captionFont = Font.caption      // メタ情報
    static let actionFont = Font.title3        // ボタンテキスト
    
    // MARK: - Spacing
    static let primarySpacing: CGFloat = 16    // セクション間
    static let secondarySpacing: CGFloat = 12  // 要素間
    static let tightSpacing: CGFloat = 8       // 関連要素
    static let compactSpacing: CGFloat = 4     // 密接要素
    
    // MARK: - Component Sizes
    static let largeButtonHeight: CGFloat = 44   // メインアクション
    static let mediumButtonHeight: CGFloat = 32  // サブアクション
    static let smallButtonHeight: CGFloat = 24   // インラインアクション
    static let cardCornerRadius: CGFloat = 12    // カード角丸
    static let buttonCornerRadius: CGFloat = 8   // ボタン角丸
}

// MARK: - 統一アクションボタン

struct ListActionButton: View {
    enum Size {
        case large, medium, small
        
        var height: CGFloat {
            switch self {
            case .large: return ListUITheme.largeButtonHeight
            case .medium: return ListUITheme.mediumButtonHeight
            case .small: return ListUITheme.smallButtonHeight
            }
        }
        
        var font: Font {
            switch self {
            case .large: return ListUITheme.actionFont
            case .medium: return ListUITheme.bodyFont
            case .small: return ListUITheme.captionFont
            }
        }
    }
    
    enum Style {
        case primary, success, warning, danger, info, neutral
        case outline(Color)
        
        var backgroundColor: Color {
            switch self {
            case .primary: return ListUITheme.primaryColor
            case .success: return ListUITheme.successColor
            case .warning: return ListUITheme.warningColor
            case .danger: return ListUITheme.dangerColor
            case .info: return ListUITheme.infoColor
            case .neutral: return ListUITheme.neutralColor
            case .outline(_): return Color.clear
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .outline(let color): return color
            case .neutral: return Color.primary
            default: return Color.white
            }
        }
        
        var borderColor: Color? {
            switch self {
            case .outline(let color): return color
            default: return nil
            }
        }
    }
    
    let title: String
    let iconName: String?
    let size: Size
    let style: Style
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            // Professional haptic feedback based on button importance
            triggerHapticFeedback(for: style)
            action()
        }) {
            HStack(spacing: ListUITheme.compactSpacing) {
                if let icon = iconName {
                    Image(systemName: icon)
                        .symbolRenderingMode(.hierarchical)
                }
                Text(title)
            }
            .font(size.font)
            .foregroundColor(style.foregroundColor)
            .frame(height: size.height)
            .padding(.horizontal, ListUITheme.tightSpacing)
            .background(style.backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: ListUITheme.buttonCornerRadius)
                    .stroke(style.borderColor ?? Color.clear, lineWidth: 1)
            )
            .cornerRadius(ListUITheme.buttonCornerRadius)
            // Professional micro-interactions
            .scaleEffect(scale)
            .animation(.interpolatingSpring(stiffness: 400, damping: 10), value: scale)
        }
        .buttonStyle(PlainButtonStyle())
        // Advanced press handling for premium feel
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, 
                           pressing: { pressing in
            withAnimation(.interpolatingSpring(stiffness: 400, damping: 8)) {
                scale = pressing ? 0.95 : 1.0
                isPressed = pressing
            }
        }, perform: {})
        // Accessibility enhancements
        .accessibilityAddTraits(isPressed ? [.isButton, .allowsDirectInteraction] : .isButton)
    }
    
    // MARK: - Contextual Haptic Feedback System
    private func triggerHapticFeedback(for style: Style) {
        switch style {
        case .primary:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .danger:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .info, .neutral:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .outline(_):
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

// MARK: - 統一ステータスインジケーター

struct UnifiedStatusIndicator: View {
    enum Status {
        case transcriptionNone, transcriptionProcessing, transcriptionCompleted, transcriptionError
        case cloudNotSynced, cloudSyncing, cloudSynced, cloudError
        case favorite(Bool)
        case playing(Bool)
        
        var iconName: String {
            switch self {
            case .transcriptionNone: return "doc.text"
            case .transcriptionProcessing: return "waveform.and.mic"
            case .transcriptionCompleted: return "checkmark.circle.fill"
            case .transcriptionError: return "exclamationmark.triangle.fill"
            case .cloudNotSynced: return "icloud.slash"
            case .cloudSyncing: return "cloud.arrow.up"
            case .cloudSynced: return "checkmark.circle.fill"
            case .cloudError: return "exclamationmark.triangle.fill"
            case .favorite(let isFavorite): return isFavorite ? "star.fill" : "star"
            case .playing(let isPlaying): return isPlaying ? "pause.fill" : "play.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .transcriptionNone: return ListUITheme.neutralColor
            case .transcriptionProcessing: return ListUITheme.primaryColor
            case .transcriptionCompleted: return ListUITheme.successColor
            case .transcriptionError: return ListUITheme.dangerColor
            case .cloudNotSynced: return ListUITheme.neutralColor
            case .cloudSyncing: return ListUITheme.primaryColor
            case .cloudSynced: return ListUITheme.successColor
            case .cloudError: return ListUITheme.dangerColor
            case .favorite(let isFavorite): return isFavorite ? ListUITheme.warningColor : ListUITheme.neutralColor
            case .playing(_): return ListUITheme.primaryColor
            }
        }
        
        var needsAnimation: Bool {
            switch self {
            case .transcriptionProcessing, .cloudSyncing: return true
            default: return false
            }
        }
    }
    
    let status: Status
    let action: (() -> Void)?
    
    var body: some View {
        Button(action: action ?? {}) {
            Image(systemName: status.iconName)
                .foregroundColor(status.color)
                .font(ListUITheme.actionFont)
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(status.needsAnimation ? 0.6 : 1.0)
        .animation(
            status.needsAnimation ? 
            Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) : 
            nil,
            value: status.needsAnimation
        )
        .disabled(action == nil)
    }
}

// MARK: - 統一メタデータ表示

struct UnifiedMetadata: View {
    let primaryText: String
    let secondaryText: String?
    let iconName: String?
    
    var body: some View {
        HStack(spacing: ListUITheme.compactSpacing) {
            if let icon = iconName {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .font(ListUITheme.captionFont)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryText)
                    .font(ListUITheme.captionFont)
                    .foregroundColor(.secondary)
                
                if let secondary = secondaryText {
                    Text(secondary)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .opacity(0.7)
                }
            }
        }
    }
}

// MARK: - Spotify風録音カード（プレミアムデザイン）

struct SpotifyStyleRecordingCard: View {
    let recording: Recording
    let showTranscriptionPreview: Bool
    let onPlayTap: () -> Void
    let onDetailTap: () -> Void
    let onFavoriteTap: () -> Void
    let onShareTap: () -> Void
    let isPlaying: Bool
    
    @EnvironmentObject private var themeService: AppThemeService
    
    var body: some View {
        VStack(spacing: 0) {
            // メイン録音情報エリア
            HStack(spacing: ListUITheme.primarySpacing) {
                // 左：プレイボタン（Spotify風の大きなボタン）
                Button(action: onPlayTap) {
                    ZStack {
                        Circle()
                            .fill(isPlaying ? AppTheme.universalPauseColor : AppTheme.universalPlayColor)
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .offset(x: isPlaying ? 0 : 2)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                
                // 中央：録音情報
                VStack(alignment: .leading, spacing: 6) {
                    Text(recording.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(recording.relativeTimeString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatDuration(recording.duration))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // プロミネントステータスバー
                    HStack(spacing: 12) {
                        ProminentStatusBadge(
                            status: getTranscriptionStatus(),
                            iconName: "doc.text",
                            text: transcriptionStatusText
                        )
                        
                        ProminentStatusBadge(
                            status: getCloudStatus(),
                            iconName: "icloud",
                            text: cloudStatusText
                        )
                    }
                }
                
                Spacer()
                
                // 右：アクションボタン群
                VStack(spacing: 8) {
                    Button(action: onFavoriteTap) {
                        Image(systemName: recording.isFavorite ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundColor(recording.isFavorite ? themeService.currentTheme.warningColor : .secondary)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Button(action: onShareTap) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Button(action: onDetailTap) {
                        Image(systemName: "ellipsis")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(ListUITheme.primarySpacing)
            
            // オプション：文字起こしプレビュー
            if showTranscriptionPreview, 
               let transcription = recording.transcription,
               !transcription.isEmpty {
                
                Divider()
                    .padding(.horizontal, ListUITheme.primarySpacing)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "quote.bubble")
                            .font(.caption)
                            .foregroundColor(themeService.currentTheme.infoColor)
                        
                        Text("Transcript")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(themeService.currentTheme.infoColor)
                        
                        if recording.transcription != recording.originalTranscription {
                            Image(systemName: "pencil.circle.fill")
                                .font(.caption2)
                                .foregroundColor(themeService.currentTheme.warningColor)
                        }
                        
                        Spacer()
                    }
                    
                    Text(transcription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .onTapGesture(perform: onDetailTap)
                }
                .padding(ListUITheme.primarySpacing)
                .background(Color(.systemGray6).opacity(0.3))
            }
        }
        .background(themeService.currentTheme.cardBackgroundColor)
        .cornerRadius(16)
        .shadow(color: themeService.currentTheme.primaryColor.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - ステータス計算
    
    private func getTranscriptionStatus() -> ProminentStatusBadge.StatusType {
        if let transcription = recording.transcription, !transcription.isEmpty {
            if recording.transcription != recording.originalTranscription {
                return .processing // Edited state - show as processing/changed
            }
            return .success
        }
        // TODO: 処理中の状態を検出（実際の文字起こしサービスのステータスを確認）
        return .inactive
    }
    
    private func getCloudStatus() -> ProminentStatusBadge.StatusType {
        switch recording.cloudSyncStatus {
        case .synced: return .success
        case .uploading: return .processing
        case .error: return .error
        default: return .inactive
        }
    }
    
    private var transcriptionStatusText: String {
        if let transcription = recording.transcription, !transcription.isEmpty {
            if recording.transcription != recording.originalTranscription {
                return "Edited"
            }
            return "Done"
        }
        return "Pending"
    }
    
    private var cloudStatusText: String {
        switch recording.cloudSyncStatus {
        case .synced: return "Saved"
        case .uploading: return "Saving..."
        case .error: return "Failed"
        case .notSynced: return "Local"
        default: return "Local"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - 統一録音カード（後方互換性用）

struct UnifiedRecordingCard: View {
    let recording: Recording
    let showTranscriptionPreview: Bool
    let onPlayTap: () -> Void
    let onDetailTap: () -> Void
    let onFavoriteTap: () -> Void
    let onShareTap: () -> Void
    let isPlaying: Bool
    
    var body: some View {
        SpotifyStyleRecordingCard(
            recording: recording,
            showTranscriptionPreview: showTranscriptionPreview,
            onPlayTap: onPlayTap,
            onDetailTap: onDetailTap,
            onFavoriteTap: onFavoriteTap,
            onShareTap: onShareTap,
            isPlaying: isPlaying
        )
    }
}

// MARK: - 統一DetailViewヘッダー

struct UnifiedDetailHeader: View {
    let title: String
    let subtitle: String
    let metadata: [String]
    let isEditing: Bool
    let onEditToggle: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var editedTitle = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: ListUITheme.secondarySpacing) {
            if isEditing {
                VStack(alignment: .leading, spacing: ListUITheme.tightSpacing) {
                    TextField("Title", text: $editedTitle)
                        .font(ListUITheme.titleFont)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    HStack {
                        ListActionButton(
                            title: "Cancel",
                            iconName: "xmark",
                            size: .medium,
                            style: .outline(ListUITheme.neutralColor),
                            action: onCancel
                        )
                        
                        Spacer()
                        
                        ListActionButton(
                            title: "Save",
                            iconName: "checkmark",
                            size: .medium,
                            style: .primary,
                            action: onSave
                        )
                    }
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: ListUITheme.compactSpacing) {
                        Text(title)
                            .font(ListUITheme.titleFont)
                            .fontWeight(.bold)
                        
                        Text(subtitle)
                            .font(ListUITheme.bodyFont)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    UnifiedStatusIndicator(
                        status: .transcriptionNone,
                        action: onEditToggle
                    )
                }
            }
            
            // Metadata
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: ListUITheme.compactSpacing) {
                ForEach(metadata, id: \.self) { item in
                    UnifiedMetadata(
                        primaryText: item,
                        secondaryText: nil,
                        iconName: "info.circle"
                    )
                }
            }
        }
    }
}

// MARK: - Spotify風コンポーネント

/// プロミネントステータスバッジ（Spotify風スタイル）
struct ProminentStatusBadge: View {
    enum StatusType {
        case success, processing, error, inactive
        
        func color(theme: AppTheme) -> Color {
            switch self {
            case .success: return theme.successColor
            case .processing: return theme.primaryColor
            case .error: return theme.errorColor
            case .inactive: return theme.neutralColor
            }
        }
        
        func backgroundColor(theme: AppTheme) -> Color {
            switch self {
            case .success: return theme.successColor.opacity(0.15)
            case .processing: return theme.primaryColor.opacity(0.15)
            case .error: return theme.errorColor.opacity(0.15)
            case .inactive: return theme.neutralColor.opacity(0.15)
            }
        }
    }
    
    let status: StatusType
    let iconName: String
    let text: String
    
    @EnvironmentObject private var themeService: AppThemeService
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.caption2)
                .foregroundColor(status.color(theme: themeService.currentTheme))
            
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(status.color(theme: themeService.currentTheme))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.backgroundColor(theme: themeService.currentTheme))
        .cornerRadius(8)
    }
}

/// スケールアニメーション付きボタンスタイル
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// モデルダウンロードステータスインジケーター（強化版）
struct EnhancedModelDownloadIndicator: View {
    enum DownloadState {
        case notDownloaded
        case downloading(progress: Float)
        case downloaded
        case error
        
        var iconName: String {
            switch self {
            case .notDownloaded: return "arrow.down.circle"
            case .downloading: return "arrow.down.circle.fill"
            case .downloaded: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .notDownloaded: return .blue
            case .downloading: return .orange
            case .downloaded: return .green
            case .error: return .red
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .notDownloaded: return .blue.opacity(0.1)
            case .downloading: return .orange.opacity(0.1)
            case .downloaded: return .green.opacity(0.1)
            case .error: return .red.opacity(0.1)
            }
        }
        
        var text: String {
            switch self {
            case .notDownloaded: return "Tap to Download"
            case .downloading(let progress): return "Downloading \(Int(progress * 100))%"
            case .downloaded: return "Downloaded"
            case .error: return "Retry Download"
            }
        }
    }
    
    let state: DownloadState
    let action: (() -> Void)?
    
    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 8) {
                ZStack {
                    // Background circle for progress
                    if case .downloading(let progress) = state {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 2)
                            .overlay(
                                Circle()
                                    .trim(from: 0, to: CGFloat(progress))
                                    .stroke(state.color, lineWidth: 2)
                                    .rotationEffect(.degrees(-90))
                            )
                            .frame(width: 20, height: 20)
                    }
                    
                    Image(systemName: state.iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(state.color)
                }
                
                Text(state.text)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(state.color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(state.backgroundColor)
            .cornerRadius(12)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(action == nil)
    }
}

// MARK: - Spotify風アイコンシステム

/// ステータスヘルプシート（ユーザー向けアイコン説明）
struct StatusIconHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Transcription Status") {
                    StatusHelpRow(
                        iconName: "doc.text",
                        title: "Pending",
                        description: "Transcription not started",
                        color: Color(.systemGray)
                    )
                    StatusHelpRow(
                        iconName: "waveform.and.mic",
                        title: "Processing",
                        description: "Creating transcript from audio",
                        color: .blue
                    )
                    StatusHelpRow(
                        iconName: "checkmark.circle.fill",
                        title: "Done",
                        description: "Transcript ready to view",
                        color: .green
                    )
                    StatusHelpRow(
                        iconName: "pencil.circle",
                        title: "Edited",
                        description: "Transcript has been modified",
                        color: .orange
                    )
                }
                
                Section("Cloud Backup Status") {
                    StatusHelpRow(
                        iconName: "icloud.slash",
                        title: "Local",
                        description: "Stored only on this device",
                        color: Color(.systemGray)
                    )
                    StatusHelpRow(
                        iconName: "icloud.and.arrow.up",
                        title: "Saving...",
                        description: "Uploading to Google Drive",
                        color: .blue
                    )
                    StatusHelpRow(
                        iconName: "icloud.fill",
                        title: "Saved",
                        description: "Backed up to Google Drive",
                        color: .green
                    )
                    StatusHelpRow(
                        iconName: "icloud.slash",
                        title: "Failed",
                        description: "Backup error - try again",
                        color: .red
                    )
                }
                
                Section("Model Download Status") {
                    StatusHelpRow(
                        iconName: "arrow.down.circle",
                        title: "Tap to Download",
                        description: "AI model not downloaded yet",
                        color: .blue
                    )
                    StatusHelpRow(
                        iconName: "arrow.down.circle.fill",
                        title: "Downloading...",
                        description: "Fetching AI model from server",
                        color: .orange
                    )
                    StatusHelpRow(
                        iconName: "checkmark.circle.fill",
                        title: "Downloaded",
                        description: "AI model ready for transcription",
                        color: .green
                    )
                }
            }
            .navigationTitle("Status Icons Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct StatusHelpRow: View {
    let iconName: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

/// ステータスアイコン用統一システム（強化版）
struct StatusIconSystem {
    // 文字起こし状態
    enum TranscriptionStatus {
        case none, processing, completed, edited, error
        
        var iconName: String {
            switch self {
            case .none: return "doc.text"
            case .processing: return "waveform.and.mic"
            case .completed: return "checkmark.circle.fill"
            case .edited: return "pencil.circle"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .none: return Color(.systemGray)
            case .processing: return .blue
            case .completed: return .green
            case .edited: return .orange
            case .error: return .red
            }
        }
        
        var displayText: String {
            switch self {
            case .none: return "No transcript"
            case .processing: return "Transcribing..."
            case .completed: return "Transcript ready"
            case .edited: return "Transcript edited"
            case .error: return "Transcription failed"
            }
        }
    }
    
    // Google Driveバックアップ状態
    enum BackupStatus {
        case notSynced, syncing(progress: Float), synced, error
        
        var iconName: String {
            switch self {
            case .notSynced: return "icloud.slash"
            case .syncing: return "icloud.and.arrow.up"
            case .synced: return "icloud.fill"
            case .error: return "icloud.slash"
            }
        }
        
        var color: Color {
            switch self {
            case .notSynced: return Color(.systemGray)
            case .syncing: return .blue
            case .synced: return .green
            case .error: return .red
            }
        }
        
        var displayText: String {
            switch self {
            case .notSynced: return "Local only"
            case .syncing(let progress): return "Syncing \(Int(progress * 100))%"
            case .synced: return "Cloud synced"
            case .error: return "Sync failed"
            }
        }
    }
}

// MARK: - Professional Performance & Loading Experience

/// High-performance skeleton loading system for premium user experience
struct SkeletonLoadingView: View {
    @State private var isAnimating = false
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(height: CGFloat = 20, cornerRadius: CGFloat = 4) {
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color(.systemGray5),
                        Color(.systemGray4),
                        Color(.systemGray5)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: height)
            .mask(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .black, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: isAnimating ? 300 : -300)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

/// Professional recording card skeleton for smooth loading transitions
struct RecordingCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: HierarchicalSpacing.level4) {
            // Title skeleton
            HStack {
                SkeletonLoadingView(height: 18, cornerRadius: 4)
                    .frame(maxWidth: .infinity)
                
                Spacer()
                
                // Status icons skeleton
                HStack(spacing: HierarchicalSpacing.level6) {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 16, height: 16)
                    
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 16, height: 16)
                }
            }
            
            // Metadata skeleton
            HStack {
                SkeletonLoadingView(height: 14, cornerRadius: 3)
                    .frame(width: 80)
                
                Spacer()
                
                SkeletonLoadingView(height: 14, cornerRadius: 3)
                    .frame(width: 60)
            }
            
            // Action buttons skeleton
            HStack {
                SkeletonLoadingView(height: 32, cornerRadius: ListUITheme.buttonCornerRadius)
                    .frame(width: 100)
                
                Spacer()
                
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 32, height: 32)
                
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 32, height: 32)
            }
        }
        .padding(HierarchicalSpacing.level3)
        .background(Color(.systemBackground))
        .cornerRadius(ListUITheme.cardCornerRadius)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .accessibilityLabel("Loading recording information")
    }
}

/// Progressive loading container for smooth content transitions
struct ProgressiveLoadingContainer<Content: View>: View {
    enum LoadingState {
        case loading
        case partial
        case complete
    }
    
    @State private var loadingState: LoadingState = .loading
    let content: Content
    let loadingDuration: TimeInterval
    
    init(loadingDuration: TimeInterval = 0.8, @ViewBuilder content: () -> Content) {
        self.loadingDuration = loadingDuration
        self.content = content()
    }
    
    var body: some View {
        Group {
            switch loadingState {
            case .loading:
                RecordingCardSkeleton()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                
            case .partial:
                content
                    .opacity(0.6)
                    .transition(.opacity)
                
            case .complete:
                content
                    .transition(.opacity.combined(with: .scale(scale: 1.05).animation(.spring(response: 0.3))))
            }
        }
        .onAppear {
            simulateProgressiveLoading()
        }
    }
    
    private func simulateProgressiveLoading() {
        // Simulate partial data loading
        DispatchQueue.main.asyncAfter(deadline: .now() + loadingDuration * 0.3) {
            withAnimation(.easeOut(duration: 0.3)) {
                loadingState = .partial
            }
        }
        
        // Complete loading
        DispatchQueue.main.asyncAfter(deadline: .now() + loadingDuration) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                loadingState = .complete
            }
        }
    }
}

/// Optimized empty state view with engaging micro-animations
struct OptimizedEmptyStateView: View {
    let iconName: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    @State private var animationPhase = 0
    
    var body: some View {
        VStack(spacing: HierarchicalSpacing.level2) {
            // Animated icon
            Image(systemName: iconName)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(ListUITheme.primaryColor)
                .scaleEffect(animationPhase == 0 ? 1.0 : 1.1)
                .animation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true),
                    value: animationPhase
                )
            
            VStack(spacing: HierarchicalSpacing.level4) {
                Text(title)
                    .font(ListUITheme.subtitleFont)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(ListUITheme.bodyFont)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if let actionTitle = actionTitle, let action = action {
                ListActionButton(
                    title: actionTitle,
                    iconName: "plus.circle.fill",
                    size: .medium,
                    style: .primary,
                    action: action
                )
                .padding(.top, HierarchicalSpacing.level4)
            }
        }
        .padding(.horizontal, HierarchicalSpacing.level1)
        .onAppear {
            animationPhase = 1
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

// MARK: - Performance Monitoring Extensions

/// Performance monitoring for smooth 60fps scrolling
extension View {
    func optimizedForScrolling() -> some View {
        self
            .drawingGroup() // Rasterize complex views for better scrolling performance
            .clipped() // Prevent overdraw
    }
    
    func conditionalDrawingGroup(when condition: Bool) -> some View {
        Group {
            if condition {
                self.drawingGroup()
            } else {
                self
            }
        }
    }
}