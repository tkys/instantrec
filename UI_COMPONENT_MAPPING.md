# InstantRec 統一UIコンポーネント使用箇所マッピング

## 🎨 ListUIComponents.swift - 統一UIシステム全体図

```
ListUIComponents.swift (418行)
├── ListUITheme (テーマ定義)
│   ├── Color System (6色)
│   ├── Typography (5段階)  
│   ├── Spacing (4段階)
│   └── Component Sizes (3サイズ)
├── ListActionButton (統一ボタン)
├── UnifiedStatusIndicator (ステータス表示)
├── UnifiedMetadata (メタ情報表示) 
├── UnifiedRecordingCard (録音カード)
└── UnifiedDetailHeader (詳細ヘッダー)
```

## 📱 画面別コンポーネント使用状況

### 1. RecordingsListView.swift

#### 使用コンポーネント
```swift
// メインリストカード
UnifiedRecordingCard(
    recording: recording,
    showTranscriptionPreview: true,
    onPlayTap: { playbackManager.play(recording: recording) },
    onDetailTap: { selectedRecording = recording },
    onFavoriteTap: { toggleFavorite() },
    onShareTap: { recordingToShare = recording },
    isPlaying: playbackManager.isPlayingRecording(recording)
)
```

#### マッピング詳細
| 要素 | 使用コンポーネント | 適用箇所 | 効果 |
|------|------------------|----------|------|
| 録音カード全体 | `UnifiedRecordingCard` | `EnhancedRecordingCard` を置換 | 完全統一化 |
| ステータス表示 | `UnifiedStatusIndicator` | 文字起こし・同期・お気に入り | 一貫した視覚表現 |
| メタ情報 | `UnifiedMetadata` | 時間・長さ表示 | 統一フォーマット |
| アクションボタン | `ListActionButton` | Details・Share ボタン | 統一スタイル |

### 2. RecordingDetailView.swift

#### 使用コンポーネント概要

##### ヘッダーセクション
```swift
UnifiedDetailHeader(
    title: recording.displayName,
    subtitle: "Audio Recording",
    metadata: [
        recording.relativeTimeString,
        formatDuration(recording.duration),
        "Transcription: \(recording.transcriptionStatus.displayName)"
    ],
    isEditing: isEditingTitle,
    onEditToggle: { startTitleEdit() },
    onSave: { saveTitle() },
    onCancel: { cancelTitleEdit() }
)
```

##### 再生コントロール
```swift
ListActionButton(
    title: playbackManager.isPlayingRecording(recording) ? "Pause" : "Play",
    iconName: playbackManager.isPlayingRecording(recording) ? "pause.fill" : "play.fill",
    size: .large,
    style: .primary,
    action: { playbackManager.play(recording: recording) }
)

UnifiedStatusIndicator(
    status: .favorite(recording.isFavorite),
    action: { /* お気に入り切り替え */ }
)
```

##### プログレススライダー
```swift
UnifiedMetadata(
    primaryText: playbackManager.currentPlaybackTime,
    secondaryText: nil,
    iconName: nil
)
```

##### 文字起こしセクション
```swift
// 編集モード
ListActionButton(title: "Cancel", iconName: "xmark", size: .medium, style: .outline(ListUITheme.neutralColor))
ListActionButton(title: "Reset", iconName: "arrow.counterclockwise", size: .medium, style: .warning)
ListActionButton(title: "Save", iconName: "checkmark", size: .medium, style: .primary)

// 表示モード
ListActionButton(title: "Edit", iconName: "pencil", size: .medium, style: .outline(ListUITheme.primaryColor))
ListActionButton(title: "Reset to Original", iconName: "arrow.counterclockwise", size: .medium, style: .outline(ListUITheme.warningColor))
```

##### ツールバー
```swift
// ナビゲーションバー左
ListActionButton(
    title: "Done",
    iconName: "xmark", 
    size: .medium,
    style: .outline(ListUITheme.primaryColor)
)

// ナビゲーションバー右（メニュー）
UnifiedStatusIndicator(
    status: .transcriptionNone,
    action: nil
)
```

#### 詳細マッピング表

| セクション | 要素 | 使用コンポーネント | Before | After |
|-----------|------|------------------|--------|-------|
| **ヘッダー** | タイトル・メタ情報 | `UnifiedDetailHeader` | カスタムVStack | 統一ヘッダー |
| **再生制御** | 再生ボタン | `ListActionButton(.large, .primary)` | カスタムButton | 統一アクションボタン |
| **再生制御** | お気に入り | `UnifiedStatusIndicator(.favorite)` | カスタムButton | 統一ステータス表示 |
| **進捗表示** | 時間表示 | `UnifiedMetadata` | Text(.caption) | 統一メタ情報 |
| **文字起こし** | ヘッダー | `ListUITheme` フォント・カラー | `.headline`, `.purple` | 統一テーマ |
| **文字起こし** | 編集ボタン | `ListActionButton(.medium, .outline)` | カスタムButton | 統一アクションボタン |
| **文字起こし** | 保存ボタン | `ListActionButton(.medium, .primary)` | `.blue` Button | 統一プライマリアクション |
| **文字起こし** | キャンセルボタン | `ListActionButton(.medium, .outline)` | `.secondary` Button | 統一セカンダリアクション |
| **文字起こし** | リセットボタン | `ListActionButton(.medium, .warning)` | `.orange` Button | 統一警告アクション |
| **ツールバー** | 完了ボタン | `ListActionButton(.medium, .outline)` | Text("Done") | 統一ツールバーボタン |
| **ツールバー** | メニューアイコン | `UnifiedStatusIndicator` | Image(ellipsis.circle) | 統一アイコン表示 |

## 🎨 テーマシステム詳細マッピング

### ListUITheme 使用箇所一覧

#### カラーシステム適用箇所

| カラー | 定数 | 使用箇所 | 適用要素 |
|--------|------|----------|----------|
| **Primary Blue** | `ListUITheme.primaryColor` | 再生ボタン、主要アクション | `.primary` スタイルボタン |
| **Success Green** | `ListUITheme.successColor` | 完了状態、同期済み | 成功ステータス |
| **Warning Orange** | `ListUITheme.warningColor` | 編集状態、リセット機能 | `.warning` スタイルボタン |
| **Danger Red** | `ListUITheme.dangerColor` | 削除アクション | `.danger` スタイルボタン |
| **Info Purple** | `ListUITheme.infoColor` | 文字起こし関連 | 情報表示セクション |
| **Neutral Gray** | `ListUITheme.neutralColor` | 非アクティブ状態 | セカンダリアクション |

#### タイポグラフィ適用箇所

| フォント | 定数 | 使用箇所 | 適用要素 |
|----------|------|----------|----------|
| **Title2** | `ListUITheme.titleFont` | 詳細画面タイトル | `UnifiedDetailHeader` |
| **Headline** | `ListUITheme.subtitleFont` | サブタイトル、セクションヘッダー | カードヘッダー |
| **Subheadline** | `ListUITheme.bodyFont` | 本文、文字起こしテキスト | メインコンテンツ |
| **Caption** | `ListUITheme.captionFont` | メタ情報、時間表示 | `UnifiedMetadata` |
| **Title3** | `ListUITheme.actionFont` | ボタンテキスト | `ListActionButton` |

#### スペーシング適用箇所

| スペーシング | 定数 | 値 | 使用箇所 |
|-------------|------|----|---------| 
| **Primary** | `ListUITheme.primarySpacing` | 16pt | セクション間、主要余白 |
| **Secondary** | `ListUITheme.secondarySpacing` | 12pt | 関連要素間 |
| **Tight** | `ListUITheme.tightSpacing` | 8pt | 密接要素間 |
| **Compact** | `ListUITheme.compactSpacing` | 4pt | 最小余白 |

## 🔧 実装パターン詳細

### 1. ボタン実装パターン

#### Primary Action (主要アクション)
```swift
ListActionButton(
    title: "Play",
    iconName: "play.fill", 
    size: .large,
    style: .primary,
    action: { /* アクション */ }
)
```

#### Secondary Action (副次アクション)  
```swift
ListActionButton(
    title: "Edit",
    iconName: "pencil",
    size: .medium, 
    style: .outline(ListUITheme.primaryColor),
    action: { /* アクション */ }
)
```

#### Destructive Action (削除アクション)
```swift
ListActionButton(
    title: "Delete",
    iconName: "trash",
    size: .medium,
    style: .danger,
    action: { /* アクション */ }
)
```

### 2. ステータス表示パターン

#### 動的ステータス（アニメーション付き）
```swift
UnifiedStatusIndicator(
    status: .transcriptionProcessing, // 自動でアニメーション
    action: nil
)
```

#### インタラクティブステータス
```swift
UnifiedStatusIndicator(
    status: .favorite(recording.isFavorite),
    action: { toggleFavorite() } // タップ可能
)
```

### 3. メタデータ表示パターン

#### アイコン付きメタデータ
```swift
UnifiedMetadata(
    primaryText: "3:45",
    secondaryText: "録音時間", 
    iconName: "clock"
)
```

#### シンプルメタデータ
```swift
UnifiedMetadata(
    primaryText: playbackManager.currentPlaybackTime,
    secondaryText: nil,
    iconName: nil
)
```

## 📊 統一化効果測定

### Before (改善前) の問題点

#### RecordingDetailView.swift の問題
```swift
// 🚫 不統一なスタイル例
.font(.headline)           // ヘッダー用
.font(.caption)            // 時間用  
.font(.subheadline)        // 文字起こし用

.foregroundColor(.blue)    // 再生ボタン
.foregroundColor(.purple)  // 文字起こしアイコン
.foregroundColor(.orange)  // 編集状態表示
```

#### RecordingsListView.swift の問題
```swift
// 🚫 複雑なカスタム実装
struct EnhancedRecordingCard: View {
    var body: some View {
        VStack { /* 複雑なレイアウト */ }
        .background(/* カスタム背景 */)
        .cornerRadius(/* 個別設定 */)
    }
}
```

### After (改善後) の統一性

#### 統一されたスタイル
```swift
// ✅ テーマベース統一スタイル
.font(ListUITheme.titleFont)      // Title2で統一
.font(ListUITheme.captionFont)    // Captionで統一
.foregroundColor(ListUITheme.primaryColor)  // Blueで統一
```

#### シンプルなコンポーネント使用
```swift
// ✅ 統一コンポーネント使用
UnifiedRecordingCard(
    recording: recording,
    // 必要なパラメータのみ
)
```

### 定量的改善効果

| 指標 | Before | After | 改善 |
|------|--------|-------|------|
| RecordingDetailView行数 | 〜450行 | 412行 | コード整理 |
| カスタムUI実装数 | 15箇所 | 0箇所 | 完全統一 |
| 色定義重複 | 12箇所 | 0箇所 | テーマ統一 |
| フォント指定重複 | 8箇所 | 0箇所 | タイポグラフィ統一 |
| スペーシング値重複 | 6種類 | 4種類標準化 | スペーシング統一 |

## 🚀 今後の拡張可能性

### 新コンポーネント追加予定
1. **UnifiedNavigationButton** - ナビゲーション用統一ボタン
2. **UnifiedFormField** - フォーム入力用統一コンポーネント
3. **UnifiedAlert** - アラート・ダイアログ統一
4. **UnifiedProgressIndicator** - 進捗表示統一

### 他画面への適用計画
1. **SettingsView** - 設定画面の統一
2. **AudioSettingsView** - 音声設定の統一
3. **TranscriptionDebugView** - デバッグ画面の統一
4. **SegmentedRecordingView** - セグメント録音画面の統一

---

**InstantRec統一UIシステムは、スケーラブルで保守しやすい設計を実現しています！** ✨