import SwiftUI

// MARK: - テーマ選択シート

struct ThemeSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeService: AppThemeService
    @State private var selectedTheme: AppTheme
    @State private var previewTheme: AppTheme
    
    init() {
        let currentTheme = AppThemeService.shared.currentTheme
        _selectedTheme = State(initialValue: currentTheme)
        _previewTheme = State(initialValue: currentTheme)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // ヘッダー説明
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose Your Style")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Select a color theme that matches your taste and workflow")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // テーマ選択グリッド
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 16) {
                        ForEach(AppTheme.allCases) { theme in
                            ThemeSelectionCard(
                                theme: theme,
                                isSelected: selectedTheme == theme,
                                onSelect: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedTheme = theme
                                        previewTheme = theme
                                    }
                                }
                            )
                        }
                    }
                    
                    // プレビューセクション
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Preview")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ThemedPreviewCard(theme: previewTheme)
                            .id(previewTheme.rawValue) // プレビューの安定性向上
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .navigationTitle("App Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        themeService.changeTheme(to: selectedTheme)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(selectedTheme.primaryColor)
                }
            }
        }
    }
}

// MARK: - テーマ選択カード

struct ThemeSelectionCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // カラーパレット表示
            HStack(spacing: 6) {
                ColorCircle(color: theme.primaryColor, size: 20)
                ColorCircle(color: theme.secondaryColor, size: 20)
                ColorCircle(color: theme.accentColor, size: 20)
            }
            
            VStack(spacing: 4) {
                Text(theme.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(theme.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(theme.cardBackgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? theme.primaryColor : Color(.systemGray5), lineWidth: isSelected ? 3 : 1)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .shadow(color: isSelected ? theme.primaryColor.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 4)
        .onTapGesture {
            onSelect()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - カラーサークル

struct ColorCircle: View {
    let color: Color
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
    }
}

// MARK: - テーマプレビューカード

struct ThemedPreviewCard: View {
    let theme: AppTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ミニ録音カードのプレビュー
            HStack(spacing: 12) {
                // プレイボタン
                Circle()
                    .fill(theme.playButtonColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sample Recording")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("2 mins • Just now")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        StatusBadge(text: "Done", color: theme.successColor)
                        StatusBadge(text: "Saved", color: theme.accentColor)
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(theme.cardBackgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray6), lineWidth: 1)
            )
            
            // ボタンプレビュー
            HStack(spacing: 8) {
                PreviewButton(title: "Primary", color: theme.primaryColor)
                PreviewButton(title: "Secondary", color: theme.secondaryColor)
                PreviewButton(title: "Accent", color: theme.accentColor)
            }
        }
        .padding(16)
        .background(theme.backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }
}

struct PreviewButton: View {
    let title: String
    let color: Color
    
    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(4)
    }
}

// MARK: - テーマ設定行（Settings用）

struct ThemeSettingRow: View {
    @EnvironmentObject private var themeService: AppThemeService
    @State private var showingThemeSelection = false
    
    var body: some View {
        Button(action: { showingThemeSelection = true }) {
            HStack {
                Text("App Theme")
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 6) {
                    ColorCircle(color: themeService.currentTheme.primaryColor, size: 16)
                    
                    Text(themeService.currentTheme.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingThemeSelection) {
            ThemeSelectionSheet()
        }
    }
}