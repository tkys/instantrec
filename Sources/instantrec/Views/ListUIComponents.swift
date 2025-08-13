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

// MARK: - 統一録音カード

struct UnifiedRecordingCard: View {
    let recording: Recording
    let showTranscriptionPreview: Bool
    let onPlayTap: () -> Void
    let onDetailTap: () -> Void
    let onFavoriteTap: () -> Void
    let onShareTap: () -> Void
    let isPlaying: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: ListUITheme.secondarySpacing) {
            // Header Section
            HStack {
                VStack(alignment: .leading, spacing: ListUITheme.compactSpacing) {
                    Text(recording.displayName)
                        .font(ListUITheme.subtitleFont)
                        .lineLimit(2)
                    
                    UnifiedMetadata(
                        primaryText: recording.relativeTimeString,
                        secondaryText: formatDuration(recording.duration),
                        iconName: "clock"
                    )
                }
                
                Spacer()
                
                // Status Icons
                HStack(spacing: ListUITheme.tightSpacing) {
                    UnifiedStatusIndicator(
                        status: .transcriptionCompleted,
                        action: nil
                    )
                    
                    UnifiedStatusIndicator(
                        status: .cloudSynced,
                        action: nil
                    )
                    
                    UnifiedStatusIndicator(
                        status: .favorite(recording.isFavorite),
                        action: onFavoriteTap
                    )
                }
            }
            
            // Playback Controls
            HStack(spacing: ListUITheme.secondarySpacing) {
                UnifiedStatusIndicator(
                    status: .playing(isPlaying),
                    action: onPlayTap
                )
                
                Spacer()
                
                ListActionButton(
                    title: "Details",
                    iconName: "info.circle",
                    size: .small,
                    style: .outline(ListUITheme.infoColor),
                    action: onDetailTap
                )
                
                ListActionButton(
                    title: "Share",
                    iconName: "square.and.arrow.up",
                    size: .small,
                    style: .outline(ListUITheme.neutralColor),
                    action: onShareTap
                )
            }
            
            // Transcription Preview
            if showTranscriptionPreview,
               let transcription = recording.transcription,
               !transcription.isEmpty {
                
                VStack(alignment: .leading, spacing: ListUITheme.tightSpacing) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(ListUITheme.infoColor)
                            .font(ListUITheme.captionFont)
                        
                        Text("Transcription")
                            .font(ListUITheme.captionFont)
                            .fontWeight(.medium)
                            .foregroundColor(ListUITheme.infoColor)
                        
                        if recording.transcription != recording.originalTranscription {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(ListUITheme.warningColor)
                                .font(.caption2)
                        }
                        
                        Spacer()
                    }
                    
                    Text(transcription)
                        .font(ListUITheme.bodyFont)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .onTapGesture(perform: onDetailTap)
                }
                .padding(ListUITheme.tightSpacing)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(ListUITheme.buttonCornerRadius)
            }
        }
        .padding(ListUITheme.primarySpacing)
        .background(Color(.systemGray6))
        .cornerRadius(ListUITheme.cardCornerRadius)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
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