# List画面 UI統一性分析

## 現状の問題点

### 1. RecordingsListView (EnhancedRecordingCard)
#### 問題点
- **フォントサイズ不統一**: `.headline`, `.caption`, `.subheadline`の混在
- **色使い不統一**: `.blue`, `.purple`, `.orange`の散発的使用
- **ボタンスタイル不統一**: Detailsボタンが独自デザイン
- **スペーシング不統一**: 12pt, 8pt, 6ptのばらつき
- **アイコンサイズ不統一**: system(size: 16)と.title3の混在

#### 具体的箇所
```swift
// 不統一なフォント
.font(.headline)     // ヘッダー
.font(.caption)      // 時間
.font(.subheadline)  // 文字起こし

// 不統一な色
.foregroundColor(.blue)    // 再生ボタン
.foregroundColor(.purple)  // 文字起こしアイコン
.background(Color.purple.opacity(0.1))  // Detailsボタン
```

### 2. RecordingDetailView
#### 問題点
- **ナビゲーション不統一**: "Done"ボタンのスタイル
- **ボタンデザイン不統一**: Save/Cancel vs Edit/Reset
- **レイアウト一貫性**: 異なるスペーシングとパディング
- **色のテーマ不統一**: .blue, .orange, .purple の混在

#### 具体的箇所
```swift
// メタデータセクション
.font(.caption)          // 時間表示
.font(.subheadline)      // ステータス

// 編集ボタン
.foregroundColor(.blue)    // Save
.foregroundColor(.orange)  // Reset
.foregroundColor(.secondary) // Cancel
```

### 3. 全体的な問題
- **デザインシステム未統一**: RecordingViewの統一テーマが反映されていない
- **アクション一貫性**: ボタンのスタイル、サイズ、配置が不統一
- **視覚階層不明確**: 重要度に応じた情報の視覚的優先順位が不明確

## 解決すべき統一要素

### 1. カラーシステム
- **Primary**: Blue (.blue) - メインアクション
- **Success**: Green (.green) - 完了状態
- **Warning**: Orange (.orange) - 編集・注意状態
- **Danger**: Red (.red) - 削除・停止アクション
- **Info**: Purple (.purple) - 情報・文字起こし
- **Neutral**: Gray (.gray) - 非アクティブ状態

### 2. タイポグラフィ
- **Title**: .title2 (メインヘッダー)
- **Subtitle**: .headline (サブタイトル)
- **Body**: .subheadline (本文)
- **Caption**: .caption (メタ情報)
- **Action**: .title3 (ボタンテキスト)

### 3. スペーシング
- **Primary**: 16pt (セクション間)
- **Secondary**: 12pt (要素間)
- **Tight**: 8pt (関連要素)
- **Compact**: 4pt (密接要素)

### 4. コンポーネントサイズ
- **Large Button**: 44pt height (メインアクション)
- **Medium Button**: 32pt height (サブアクション)  
- **Small Button**: 24pt height (インラインアクション)
- **Icon Size**: .title3 (統一アイコンサイズ)

## 実装すべき統一コンポーネント

### 1. ListCardComponent
統一されたリストカードデザイン

### 2. ActionButtonComponent  
一貫したボタンスタイルシステム

### 3. StatusIndicatorComponent
統一されたステータス表示

### 4. MetadataComponent
時間・ステータス・アイコンの統一表示

これらの改善により、Recording画面で実現した統一性をList画面にも展開し、アプリ全体で一貫したユーザー体験を提供できます。