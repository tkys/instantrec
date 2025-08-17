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
    @StateObject private var whisperService = WhisperKitTranscriptionService.shared
    
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
                    
                    // 文字起こし進捗表示（該当録音が処理中の場合）
                    if whisperService.isTranscribing && isCurrentlyTranscribing {
                        CompactTranscriptionProgressView(
                            progress: Float(whisperService.transcriptionProgress),
                            stage: whisperService.transcriptionStage
                        )
                        .padding(.top, 8)
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
    
    /// 現在このカードの録音が文字起こし処理中かどうか
    private var isCurrentlyTranscribing: Bool {
        // 最新の録音（リストの最初）が文字起こし中の場合のみ表示
        // より厳密には、特定の録音IDを追跡する仕組みが必要
        return whisperService.isTranscribing && (recording.transcription?.isEmpty ?? true)
    }
    
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

// MARK: - Transcription Progress Components

/// 文字起こし進捗表示コンポーネント
struct TranscriptionProgressView: View {
    let progress: Float
    let stage: String
    let estimatedTimeRemaining: TimeInterval?
    
    var body: some View {
        VStack(spacing: 12) {
            // プログレスバー
            VStack(spacing: 6) {
                HStack {
                    Text("文字起こし中")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(ListUITheme.primaryColor)
                }
                
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: ListUITheme.primaryColor))
                    .scaleEffect(y: 2.0) // プログレスバーを太く
            }
            
            // 進捗詳細
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.and.mic")
                        .font(.caption)
                        .foregroundColor(ListUITheme.primaryColor)
                    
                    Text(stage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 予測時間表示を削除し、動的アニメーション強化
                AnimatedProgressIndicator()
            }
        }
        .padding(ListUITheme.primarySpacing)
        .background(
            RoundedRectangle(cornerRadius: ListUITheme.cardCornerRadius)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

/// 動的進行感アニメーションインジケーター
struct AnimatedProgressIndicator: View {
    @State private var animationPhase: Double = 0
    @State private var glowOpacity: Double = 0.3
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "waveform")
                .font(.caption)
                .foregroundColor(.secondary)
                .scaleEffect(1 + sin(animationPhase) * 0.1)
                .opacity(0.7 + sin(animationPhase + 0.5) * 0.3)
            
            Text("AI処理中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .opacity(0.8 + sin(animationPhase + 1) * 0.2)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(ListUITheme.primaryColor.opacity(glowOpacity), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animationPhase = .pi * 2
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.8
            }
        }
    }
}

/// コンパクト版文字起こし進捗表示
struct CompactTranscriptionProgressView: View {
    let progress: Float
    let stage: String
    
    var body: some View {
        HStack(spacing: 8) {
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: ListUITheme.primaryColor))
                .frame(height: 4)
            
            Text(stage)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(ListUITheme.primaryColor)
                .frame(width: 35, alignment: .trailing)
        }
    }
}

// MARK: - Transcription Display Mode Components

/// 表示モード選択コンポーネント
struct TranscriptionDisplayModeSelector: View {
    @Binding var selectedMode: TranscriptionDisplayMode
    let onModeChange: (TranscriptionDisplayMode) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("表示モード")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(TranscriptionDisplayMode.allCases, id: \.self) { mode in
                    DisplayModeCard(
                        mode: mode,
                        isSelected: selectedMode == mode,
                        onTap: {
                            selectedMode = mode
                            onModeChange(mode)
                        }
                    )
                }
            }
        }
    }
}

/// 表示モードカード
struct DisplayModeCard: View {
    let mode: TranscriptionDisplayMode
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: mode.iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : ListUITheme.primaryColor)
                
                VStack(spacing: 2) {
                    Text(mode.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(mode.description)
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(height: 90)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? ListUITheme.primaryColor : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? ListUITheme.primaryColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

/// タイムスタンプ有効性インジケーター
struct TimestampValidityIndicator: View {
    let validity: TimestampValidity
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: validity.iconName)
                .foregroundColor(colorForValidity(validity))
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("タイムスタンプ: \(validity.displayName)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if let warning = validity.warningMessage {
                    Text(warning)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColorForValidity(validity))
        .cornerRadius(8)
    }
    
    private func colorForValidity(_ validity: TimestampValidity) -> Color {
        switch validity {
        case .valid: return .green
        case .partialValid: return .orange
        case .invalid: return .red
        }
    }
    
    private func backgroundColorForValidity(_ validity: TimestampValidity) -> Color {
        switch validity {
        case .valid: return .green.opacity(0.1)
        case .partialValid: return .orange.opacity(0.1)
        case .invalid: return .red.opacity(0.1)
        }
    }
}

/// コンパクト表示モード選択（ツールバー用）
struct CompactDisplayModeSelector: View {
    let availableModes: [TranscriptionDisplayMode]
    @Binding var selectedMode: TranscriptionDisplayMode
    let onModeChange: (TranscriptionDisplayMode) -> Void
    
    var body: some View {
        Menu {
            ForEach(availableModes, id: \.self) { mode in
                Button(action: {
                    selectedMode = mode
                    onModeChange(mode)
                }) {
                    Label(mode.displayName, systemImage: mode.iconName)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedMode.iconName)
                    .font(.caption)
                Text(selectedMode.displayName)
                    .font(.caption)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

/// 表示モード別のテキスト表示コンポーネント
struct TranscriptionDisplayView: View {
    let recording: Recording
    let displayMode: TranscriptionDisplayMode
    
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [SearchResult] = []
    @State private var currentSearchIndex = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 検索バー
            if isSearching {
                TranscriptionSearchBar(
                    searchText: $searchText,
                    onSearchTextChange: performSearch,
                    onPrevious: moveToPreviousResult,
                    onNext: moveToNextResult,
                    onClose: closeSearch,
                    resultCount: searchResults.count,
                    currentIndex: currentSearchIndex
                )
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        let displayText = recording.getDisplayText(mode: displayMode)
                        
                        if displayText.isEmpty {
                            EmptyTranscriptionView()
                        } else {
                            switch displayMode {
                            case .plainText:
                                PlainTextView(text: displayText, searchText: searchText)
                            case .timestamped:
                                TimestampedTextView(text: displayText, recording: recording, searchText: searchText)
                            case .segmented:
                                SegmentedTextView(text: displayText, recording: recording, searchText: searchText)
                            case .timeline:
                                TimelineTextView(text: displayText, recording: recording, searchText: searchText)
                            }
                        }
                    }
                    .padding(ListUITheme.primarySpacing)
                }
                .onChange(of: currentSearchIndex) { _ in
                    guard !searchResults.isEmpty else { return }
                    let result = searchResults[currentSearchIndex]
                    proxy.scrollTo("segment_\\(result.segmentIndex)", anchor: .center)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    isSearching.toggle()
                    if !isSearching {
                        closeSearch()
                    }
                }) {
                    Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                        .font(.title3)
                }
            }
        }
    }
    
    // MARK: - Search Functions
    
    private func performSearch(_ query: String) {
        guard !query.isEmpty else {
            searchResults = []
            currentSearchIndex = 0
            return
        }
        
        let segments = recording.segments
        searchResults = []
        
        for (segmentIndex, segment) in segments.enumerated() {
            let ranges = findOccurrences(of: query, in: segment.text)
            for range in ranges {
                searchResults.append(SearchResult(
                    segmentIndex: segmentIndex,
                    range: range,
                    text: String(segment.text[range]),
                    timestamp: segment.startTime
                ))
            }
        }
        
        currentSearchIndex = searchResults.isEmpty ? 0 : 0
    }
    
    private func findOccurrences(of query: String, in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchRange = text.startIndex..<text.endIndex
        
        while let range = text.range(of: query, options: .caseInsensitive, range: searchRange) {
            ranges.append(range)
            searchRange = range.upperBound..<text.endIndex
        }
        
        return ranges
    }
    
    private func moveToPreviousResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex - 1 + searchResults.count) % searchResults.count
    }
    
    private func moveToNextResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex + 1) % searchResults.count
    }
    
    private func closeSearch() {
        searchText = ""
        searchResults = []
        currentSearchIndex = 0
        isSearching = false
    }
}

// MARK: - Search Support Types

struct SearchResult {
    let segmentIndex: Int
    let range: Range<String.Index>
    let text: String
    let timestamp: TimeInterval
}

/// 検索バー
struct TranscriptionSearchBar: View {
    @Binding var searchText: String
    let onSearchTextChange: (String) -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onClose: () -> Void
    let resultCount: Int
    let currentIndex: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // 検索フィールド
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                TextField("文字起こしを検索", text: $searchText)
                    .font(.body)
                    .onChange(of: searchText) { newValue in
                        onSearchTextChange(newValue)
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        onSearchTextChange("")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // 検索結果ナビゲーション
            if resultCount > 0 {
                HStack(spacing: 4) {
                    Button(action: onPrevious) {
                        Image(systemName: "chevron.up")
                            .font(.caption)
                    }
                    .disabled(resultCount == 0)
                    
                    Text("\(currentIndex + 1)/\(resultCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                    
                    Button(action: onNext) {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .disabled(resultCount == 0)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .cornerRadius(6)
            }
            
            // 閉じるボタン
            Button(action: onClose) {
                Text("完了")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, ListUITheme.primarySpacing)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

/// プレーンテキスト表示
struct PlainTextView: View {
    let text: String
    let searchText: String?
    
    init(text: String, searchText: String? = nil) {
        self.text = text
        self.searchText = searchText
    }
    
    var body: some View {
        if let searchText = searchText, !searchText.isEmpty {
            HighlightedText(text: text, searchText: searchText)
                .font(.body)
                .lineSpacing(4)
        } else {
            Text(text)
                .font(.body)
                .lineSpacing(4)
                .textSelection(.enabled)
        }
    }
}

/// ハイライト表示テキスト
struct HighlightedText: View {
    let text: String
    let searchText: String
    
    var body: some View {
        let attributedString = highlightText(text, searchText: searchText)
        Text(AttributedString(attributedString))
            .textSelection(.enabled)
    }
    
    private func highlightText(_ text: String, searchText: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: text.count)
        
        // デフォルトの属性
        attributedString.addAttribute(.foregroundColor, value: UIColor.label, range: range)
        
        // 検索語句をハイライト
        let searchRange = NSRange(location: 0, length: text.count)
        let regex = try? NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: searchText), options: .caseInsensitive)
        
        regex?.enumerateMatches(in: text, options: [], range: searchRange) { match, _, _ in
            if let matchRange = match?.range {
                attributedString.addAttribute(.backgroundColor, value: UIColor.systemYellow, range: matchRange)
                attributedString.addAttribute(.foregroundColor, value: UIColor.black, range: matchRange)
            }
        }
        
        return attributedString
    }
}

/// タイムスタンプ付きテキスト表示
struct TimestampedTextView: View {
    let text: String
    let recording: Recording?
    let searchText: String?
    
    init(text: String, recording: Recording? = nil, searchText: String? = nil) {
        self.text = text
        self.recording = recording
        self.searchText = searchText
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(text.components(separatedBy: "\n").enumerated().map { IdentifiableString(index: $0.offset, value: $0.element) }, id: \.id) { item in
                if !item.value.isEmpty {
                    TimestampedLineView(line: item.value, recording: recording, searchText: searchText)
                        .id("segment_\(item.index)")
                }
            }
        }
    }
}

struct IdentifiableString: Identifiable {
    let id = UUID()
    let index: Int
    let value: String
}

struct TimestampedLineView: View {
    let line: String
    let recording: Recording?
    let searchText: String?
    
    @StateObject private var playbackManager = PlaybackManager.shared
    
    init(line: String, recording: Recording? = nil, searchText: String? = nil) {
        self.line = line
        self.recording = recording
        self.searchText = searchText
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let timestampMatch = line.range(of: #"\[([\d:\.]+)\]"#, options: .regularExpression) {
                let timestamp = String(line[timestampMatch])
                let content = String(line[line.index(timestampMatch.upperBound, offsetBy: 1)...])
                
                // タップ可能なタイムスタンプ
                Button(action: {
                    if let recording = recording,
                       let timeInSeconds = parseTimestamp(timestamp) {
                        seekToTimestamp(timeInSeconds)
                    }
                }) {
                    Text(timestamp)
                        .font(.caption.monospaced())
                        .foregroundColor(isCurrentTimestamp(timestamp) ? .white : ListUITheme.primaryColor)
                        .frame(width: 80, alignment: .leading)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isCurrentTimestamp(timestamp) ? ListUITheme.primaryColor : ListUITheme.primaryColor.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(recording == nil)
                
                if let searchText = searchText, !searchText.isEmpty {
                    HighlightedText(text: content, searchText: searchText)
                        .font(.body)
                        .lineSpacing(2)
                } else {
                    Text(content)
                        .font(.body)
                        .lineSpacing(2)
                        .textSelection(.enabled)
                }
            } else {
                if let searchText = searchText, !searchText.isEmpty {
                    HighlightedText(text: line, searchText: searchText)
                        .font(.body)
                } else {
                    Text(line)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Timestamp Navigation
    
    private func parseTimestamp(_ timestamp: String) -> TimeInterval? {
        // [mm:ss.SSS] または [mm:ss] 形式を解析
        let cleanTimestamp = timestamp.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let components = cleanTimestamp.components(separatedBy: ":")
        
        guard components.count >= 2 else { return nil }
        
        let minutes = Double(components[0]) ?? 0
        let secondsComponent = components[1].components(separatedBy: ".")
        let seconds = Double(secondsComponent[0]) ?? 0
        let milliseconds = secondsComponent.count > 1 ? (Double(secondsComponent[1]) ?? 0) / 1000 : 0
        
        return (minutes * 60) + seconds + milliseconds
    }
    
    private func seekToTimestamp(_ timeInSeconds: TimeInterval) {
        guard let recording = recording else { return }
        
        // レコーディングが再生中でない場合は再生を開始
        if !playbackManager.isPlayingRecording(recording) {
            playbackManager.play(recording: recording)
        }
        
        // 指定時間にシーク
        let progress = timeInSeconds / recording.duration
        playbackManager.seek(to: progress)
        
        // ハプティックフィードバック
        let impactGenerator = UIImpactFeedbackGenerator(style: .light)
        impactGenerator.impactOccurred()
        
        print("🎯 Seeking to timestamp: \(timeInSeconds)s (\(Int(progress * 100))%)")
    }
    
    private func isCurrentTimestamp(_ timestamp: String) -> Bool {
        guard let recording = recording,
              playbackManager.isPlayingRecording(recording),
              let timestampSeconds = parseTimestamp(timestamp) else {
            return false
        }
        
        let currentTime = playbackManager.playbackProgress * Double(recording.duration)
        let threshold: TimeInterval = 2.0 // 2秒の許容範囲
        
        return abs(currentTime - timestampSeconds) <= threshold
    }
}

/// セグメント表示
struct SegmentedTextView: View {
    let text: String
    let recording: Recording?
    let searchText: String?
    
    init(text: String, recording: Recording? = nil, searchText: String? = nil) {
        self.text = text
        self.recording = recording
        self.searchText = searchText
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(text.components(separatedBy: "\n\n").enumerated().map { IdentifiableString(index: $0.offset, value: $0.element) }, id: \.id) { item in
                if !item.value.isEmpty {
                    SegmentCardView(segment: item.value, recording: recording, searchText: searchText)
                        .id("segment_\(item.index)")
                }
            }
        }
    }
}

// MARK: - Segment Editing Components

struct EditableSegmentCard: View {
    @Binding var segment: TranscriptionSegment
    let isEditing: Bool
    @State private var editedText: String = ""
    @State private var isEditingThisSegment: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    
    let onSave: () -> Void
    let onCancel: () -> Void
    
    init(segment: Binding<TranscriptionSegment>, isEditing: Bool, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self._segment = segment
        self.isEditing = isEditing
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedText = State(initialValue: segment.wrappedValue.text)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // タイムスタンプ表示
            HStack {
                Text(formatTimestamp(segment.startTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                
                Text("→")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatTimestamp(segment.endTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                
                Spacer()
                
                // 編集ボタン（編集モード時のみ表示）
                if isEditing && !isEditingThisSegment {
                    Button("Edit") {
                        startEditing()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            // テキスト表示・編集エリア
            if isEditingThisSegment && isEditing {
                VStack(spacing: 8) {
                    TextEditor(text: $editedText)
                        .font(.body)
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .focused($isTextFieldFocused)
                    
                    HStack {
                        Button("Cancel") {
                            cancelEditing()
                        }
                        .foregroundColor(.red)
                        .font(.caption)
                        
                        Spacer()
                        
                        Button("Save") {
                            saveEdit()
                        }
                        .foregroundColor(.blue)
                        .font(.caption)
                        .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            } else {
                Text(segment.text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture {
                        if isEditing {
                            startEditing()
                        }
                    }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isEditingThisSegment ? Color.blue.opacity(0.1) : Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isEditingThisSegment ? Color.blue : Color(.systemGray4),
                            lineWidth: isEditingThisSegment ? 2 : 1
                        )
                )
        )
        .onAppear {
            editedText = segment.text
        }
        .onChange(of: segment.text) { _, newValue in
            if !isEditingThisSegment {
                editedText = newValue
            }
        }
    }
    
    private func startEditing() {
        editedText = segment.text
        isEditingThisSegment = true
        isTextFieldFocused = true
    }
    
    private func cancelEditing() {
        editedText = segment.text
        isEditingThisSegment = false
        isTextFieldFocused = false
        onCancel()
    }
    
    private func saveEdit() {
        let trimmedText = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty && trimmedText != segment.text {
            segment = TranscriptionSegment(
                startTime: segment.startTime,
                endTime: segment.endTime,
                text: trimmedText,
                confidence: segment.confidence,
                id: segment.id
            )
            onSave()
        }
        isEditingThisSegment = false
        isTextFieldFocused = false
    }
    
    private func formatTimestamp(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
}

struct SegmentEditableView: View {
    @Binding var recording: Recording
    let isEditing: Bool
    @State private var segments: [TranscriptionSegment] = []
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if segments.isEmpty {
                Text("No segments available for editing")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach($segments) { $segment in
                    EditableSegmentCard(
                        segment: $segment,
                        isEditing: isEditing,
                        onSave: {
                            saveSegmentEdit(segment)
                        },
                        onCancel: {
                            // キャンセル時の処理（必要に応じて実装）
                        }
                    )
                    .id(segment.id)
                }
            }
        }
        .onAppear {
            loadSegments()
        }
        .onChange(of: recording.segmentsData) { _, _ in
            loadSegments()
        }
    }
    
    private func loadSegments() {
        segments = recording.segments
    }
    
    private func saveSegmentEdit(_ segment: TranscriptionSegment) {
        // Recording.swiftのupdateSegmentメソッドを使用
        recording.updateSegment(id: segment.id, newText: segment.text)
        
        // データベースに保存
        do {
            try modelContext.save()
            print("✅ Segment edited and saved: \(segment.id)")
        } catch {
            print("❌ Failed to save segment edit: \(error)")
        }
    }
}

struct SegmentCardView: View {
    let segment: String
    let recording: Recording?
    let searchText: String?
    
    @StateObject private var playbackManager = PlaybackManager.shared
    
    init(segment: String, recording: Recording? = nil, searchText: String? = nil) {
        self.segment = segment
        self.recording = recording
        self.searchText = searchText
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let lines = segment.components(separatedBy: "\n")
            if lines.count >= 2 {
                // セグメントヘッダー（クリック可能）
                Button(action: {
                    if let duration = extractDurationFromHeader(lines[0]) {
                        seekToSegmentStart(duration)
                    }
                }) {
                    HStack {
                        Text(lines[0])
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(ListUITheme.primaryColor)
                        
                        if recording != nil {
                            Image(systemName: "play.circle.fill")
                                .font(.caption)
                                .foregroundColor(ListUITheme.primaryColor)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(recording == nil)
                
                // セグメント本文
                if let searchText = searchText, !searchText.isEmpty {
                    HighlightedText(text: lines[1], searchText: searchText)
                        .font(.body)
                        .lineSpacing(2)
                } else {
                    Text(lines[1])
                        .font(.body)
                        .lineSpacing(2)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
    }
    
    private func extractDurationFromHeader(_ header: String) -> TimeInterval? {
        // 【1】 (5.2秒) 形式からセグメント番号を抽出し、開始時間を推定
        let pattern = #"【(\d+)】\s*\(([\d\.]+)秒\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: header, range: NSRange(header.startIndex..., in: header)) else {
            return nil
        }
        
        let segmentNumber = Int(String(header[Range(match.range(at: 1), in: header)!])) ?? 1
        let segmentDuration = Double(String(header[Range(match.range(at: 2), in: header)!])) ?? 0
        
        // 簡易的な開始時間推定（実際のタイムスタンプがない場合）
        let estimatedStartTime = Double(segmentNumber - 1) * segmentDuration
        return estimatedStartTime
    }
    
    private func seekToSegmentStart(_ estimatedStartTime: TimeInterval) {
        guard let recording = recording else { return }
        
        if !playbackManager.isPlayingRecording(recording) {
            playbackManager.play(recording: recording)
        }
        
        let progress = estimatedStartTime / recording.duration
        playbackManager.seek(to: Double(progress))
        
        let impactGenerator = UIImpactFeedbackGenerator(style: .light)
        impactGenerator.impactOccurred()
        
        print("🎯 Seeking to segment start: \(estimatedStartTime)s")
    }
}

/// 時系列表示
struct TimelineTextView: View {
    let text: String
    let recording: Recording?
    let searchText: String?
    
    init(text: String, recording: Recording? = nil, searchText: String? = nil) {
        self.text = text
        self.recording = recording
        self.searchText = searchText
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(text.components(separatedBy: "\n\n").enumerated().map { IdentifiableString(index: $0.offset, value: $0.element) }, id: \.id) { item in
                if !item.value.isEmpty {
                    TimelineItemView(item: item.value, recording: recording, searchText: searchText)
                        .id("segment_\(item.index)")
                }
            }
        }
    }
}

struct TimelineItemView: View {
    let item: String
    let recording: Recording?
    let searchText: String?
    
    @StateObject private var playbackManager = PlaybackManager.shared
    
    init(item: String, recording: Recording? = nil, searchText: String? = nil) {
        self.item = item
        self.recording = recording
        self.searchText = searchText
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // タイムライン線（クリック可能）
            Button(action: {
                if let startTime = extractTimelineTimestamp() {
                    seekToTimelineTimestamp(startTime)
                }
            }) {
                VStack {
                    Circle()
                        .fill(isCurrentTimelinePoint() ? .white : ListUITheme.primaryColor)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(ListUITheme.primaryColor, lineWidth: 2)
                                .opacity(isCurrentTimelinePoint() ? 1 : 0)
                        )
                    Rectangle()
                        .fill(ListUITheme.primaryColor.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 8)
            .disabled(recording == nil)
            
            // コンテンツ
            VStack(alignment: .leading, spacing: 6) {
                let lines = item.components(separatedBy: "\n")
                ForEach(lines, id: \.self) { line in
                    if line.hasPrefix("⏱️") {
                        Button(action: {
                            if let startTime = extractTimelineTimestamp() {
                                seekToTimelineTimestamp(startTime)
                            }
                        }) {
                            Text(line)
                                .font(.caption.monospaced())
                                .foregroundColor(isCurrentTimelinePoint() ? .white : ListUITheme.primaryColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isCurrentTimelinePoint() ? ListUITheme.primaryColor : ListUITheme.primaryColor.opacity(0.1))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(recording == nil)
                    } else if line.hasPrefix("💬") {
                        let content = String(line.dropFirst(2))
                        if let searchText = searchText, !searchText.isEmpty {
                            HighlightedText(text: content, searchText: searchText)
                                .font(.body)
                                .lineSpacing(2)
                        } else {
                            Text(content)
                                .font(.body)
                                .lineSpacing(2)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 8)
    }
    
    private func extractTimelineTimestamp() -> TimeInterval? {
        let lines = item.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("⏱️") {
                // "⏱️ 00:30.5 - 00:45.2 (14.7s)" 形式から開始時間を抽出
                let pattern = #"(\d+):(\d+)\.(\d+)"#
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
                    continue
                }
                
                let minutes = Double(String(line[Range(match.range(at: 1), in: line)!])) ?? 0
                let seconds = Double(String(line[Range(match.range(at: 2), in: line)!])) ?? 0
                let deciseconds = Double(String(line[Range(match.range(at: 3), in: line)!])) ?? 0
                
                return (minutes * 60) + seconds + (deciseconds / 10)
            }
        }
        return nil
    }
    
    private func seekToTimelineTimestamp(_ timeInSeconds: TimeInterval) {
        guard let recording = recording else { return }
        
        if !playbackManager.isPlayingRecording(recording) {
            playbackManager.play(recording: recording)
        }
        
        let progress = timeInSeconds / recording.duration
        playbackManager.seek(to: Double(progress))
        
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator.impactOccurred()
        
        print("🎯 Seeking to timeline timestamp: \(timeInSeconds)s")
    }
    
    private func isCurrentTimelinePoint() -> Bool {
        guard let recording = recording,
              playbackManager.isPlayingRecording(recording),
              let timestamp = extractTimelineTimestamp() else {
            return false
        }
        
        let currentTime = playbackManager.playbackProgress * Double(recording.duration)
        let threshold: TimeInterval = 3.0 // 3秒の許容範囲
        
        return abs(currentTime - timestamp) <= threshold
    }
}

/// 空の文字起こし表示
struct EmptyTranscriptionView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("文字起こし結果なし")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("この録音にはまだ文字起こし結果がありません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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