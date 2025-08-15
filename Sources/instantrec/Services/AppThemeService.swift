import SwiftUI
import Foundation

// MARK: - アプリテーマシステム

/// アプリ全体のテーマ定義
enum AppTheme: String, CaseIterable, Identifiable {
    case minimal = "Minimal"
    case business = "Business" 
    case warm = "Warm"
    case fresh = "Fresh"
    case premium = "Premium"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .minimal: return "Minimal"
        case .business: return "Business"
        case .warm: return "Warm"
        case .fresh: return "Fresh" 
        case .premium: return "Premium"
        }
    }
    
    var description: String {
        switch self {
        case .minimal: return "Clean and simple grayscale design"
        case .business: return "Professional navy and blue tones"
        case .warm: return "Cozy earth and brown colors"
        case .fresh: return "Natural green and mint shades"
        case .premium: return "Elegant gold and dark accents"
        }
    }
    
    // MARK: - カラーパレット定義
    
    var primaryColor: Color {
        switch self {
        case .minimal: return Color.gray
        case .business: return Color.blue
        case .warm: return Color.brown
        case .fresh: return Color.green
        case .premium: return Color.yellow
        }
    }
    
    var secondaryColor: Color {
        switch self {
        case .minimal: return Color(.systemGray2)
        case .business: return Color(.systemBlue).opacity(0.8)
        case .warm: return Color(.systemOrange).opacity(0.8)
        case .fresh: return Color(.systemMint).opacity(0.8)
        case .premium: return Color(.systemYellow).opacity(0.9)
        }
    }
    
    var accentColor: Color {
        switch self {
        case .minimal: return Color(.systemGray)
        case .business: return Color(.systemIndigo)
        case .warm: return Color(.systemOrange)
        case .fresh: return Color(.systemTeal)
        case .premium: return Color(.systemYellow)
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .minimal: return Color(.systemBackground)
        case .business: return Color(.systemBackground)
        case .warm: return Color(.systemBackground)
        case .fresh: return Color(.systemBackground)
        case .premium: return Color(.systemBackground)
        }
    }
    
    var cardBackgroundColor: Color {
        switch self {
        case .minimal: return Color(.systemGray6)
        case .business: return Color(.systemBlue).opacity(0.05)
        case .warm: return Color(.systemOrange).opacity(0.05)
        case .fresh: return Color(.systemGreen).opacity(0.05)
        case .premium: return Color(.systemYellow).opacity(0.05)
        }
    }
    
    // MARK: - ステータスカラー（統一性重視）
    
    var successColor: Color { Color(.systemGreen) }
    var warningColor: Color { Color(.systemOrange) }
    var errorColor: Color { Color(.systemRed) }
    var infoColor: Color { primaryColor }
    var neutralColor: Color { Color(.systemGray) }
    
    // MARK: - グラデーション
    
    var primaryGradient: LinearGradient {
        switch self {
        case .minimal:
            return LinearGradient(
                colors: [Color(.systemGray5), Color(.systemGray6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .business:
            return LinearGradient(
                colors: [Color(.systemBlue).opacity(0.1), Color(.systemIndigo).opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .warm:
            return LinearGradient(
                colors: [Color(.systemOrange).opacity(0.1), Color(.systemBrown).opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .fresh:
            return LinearGradient(
                colors: [Color(.systemGreen).opacity(0.1), Color(.systemMint).opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .premium:
            return LinearGradient(
                colors: [Color(.systemYellow).opacity(0.1), Color(.systemGray6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - アイコンカラー
    
    var playButtonColor: Color {
        switch self {
        case .minimal: return Color(.systemGray)
        case .business: return Color(.systemBlue)
        case .warm: return Color(.systemOrange)
        case .fresh: return Color(.systemGreen)
        case .premium: return Color(.systemYellow)
        }
    }
    
    var recordButtonColor: Color {
        Color(.systemRed) // 録音ボタンは安全性のため統一
    }
    
    var readyStateColor: Color {
        switch self {
        case .minimal: return Color(.systemGray)
        case .business: return primaryColor
        case .warm: return primaryColor
        case .fresh: return primaryColor
        case .premium: return primaryColor
        }
    }
    
    var recordingStateColor: Color {
        Color(.systemRed) // 録音中は安全性のため統一（赤色）
    }
}

// MARK: - 普遍的録音・再生カラー（テーマ独立）

extension AppTheme {
    /// 録音・再生で使用する普遍的カラー（業界標準・テーマ独立）
    static let universalPlayColor = Color(.systemBlue)        // 再生: 青（標準）
    static let universalPauseColor = Color(.systemOrange)     // 一時停止: オレンジ（標準）
    static let universalStopColor = Color(.systemBlue)        // 停止: 青（再生と統一）
    static let universalRecordColor = Color(.systemRed)       // 録音: 赤（標準）
    static let universalDiscardColor = Color(.systemRed)      // 破棄: 赤（危険操作）
}

// MARK: - テーマ管理サービス

class AppThemeService: ObservableObject {
    static let shared = AppThemeService()
    
    @Published var currentTheme: AppTheme {
        didSet {
            saveTheme()
        }
    }
    
    private let userDefaults = UserDefaults.standard
    private let themeKey = "selectedAppTheme"
    
    private init() {
        // 保存されたテーマを読み込み、デフォルトはbusiness
        if let savedTheme = userDefaults.string(forKey: themeKey),
           let theme = AppTheme(rawValue: savedTheme) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .business
        }
    }
    
    func changeTheme(to theme: AppTheme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTheme = theme
        }
        
        // ハプティックフィードバック
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        print("🎨 Theme changed to: \(theme.displayName)")
    }
    
    private func saveTheme() {
        userDefaults.set(currentTheme.rawValue, forKey: themeKey)
    }
}

// MARK: - テーマ対応UIコンポーネント

struct ThemedCard<Content: View>: View {
    let content: Content
    @EnvironmentObject private var themeService: AppThemeService
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(themeService.currentTheme.cardBackgroundColor)
            .cornerRadius(12)
            .shadow(color: themeService.currentTheme.primaryColor.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct ThemedButton: View {
    let title: String
    let iconName: String?
    let style: ButtonStyle
    let action: () -> Void
    
    @EnvironmentObject private var themeService: AppThemeService
    
    enum ButtonStyle {
        case primary, secondary, accent
    }
    
    var backgroundColor: Color {
        switch style {
        case .primary: return themeService.currentTheme.primaryColor
        case .secondary: return themeService.currentTheme.secondaryColor
        case .accent: return themeService.currentTheme.accentColor
        }
    }
    
    var foregroundColor: Color {
        switch style {
        case .primary, .accent: return .white
        case .secondary: return themeService.currentTheme.primaryColor
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = iconName {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(backgroundColor)
            .cornerRadius(8)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - テーマプレビューコンポーネント

struct ThemePreview: View {
    let theme: AppTheme
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // カラーパレット表示
            HStack(spacing: 4) {
                Circle()
                    .fill(theme.primaryColor)
                    .frame(width: 16, height: 16)
                
                Circle()
                    .fill(theme.secondaryColor)
                    .frame(width: 16, height: 16)
                
                Circle()
                    .fill(theme.accentColor)
                    .frame(width: 16, height: 16)
            }
            
            Text(theme.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? theme.primaryColor : .secondary)
        }
        .padding(12)
        .background(theme.cardBackgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? theme.primaryColor : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}