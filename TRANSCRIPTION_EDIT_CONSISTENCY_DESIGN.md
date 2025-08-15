# 文字起こし編集とタイムスタンプ整合性設計

## 問題の整理

### 1. 現在の課題
- **編集後の整合性**: テキスト編集後にタイムスタンプデータが無効になる
- **データ保全**: オリジナルのタイムスタンプJSONを保持すべきか
- **UI表示**: 編集後のテキストとタイムスタンプ表示の矛盾
- **機能過多**: 表示モード切り替えがメイン機能として主張しすぎ

### 2. ユーザーの編集パターン
- **誤字脱字修正**: 単語レベルの小さな修正（タイムスタンプ維持可能）
- **文章構造変更**: 順序変更、文分割・結合（タイムスタンプ再構築必要）
- **大幅な書き換え**: 意味を変える修正（タイムスタンプ無効化）

## 提案する設計方針

### 1. データ保存戦略

#### A. レイヤー分離アプローチ（推奨）
```swift
struct Recording {
    // 原本データ（編集不可・永続保存）
    var originalTranscription: String?           // 元の文字起こしテキスト
    var originalSegmentsData: String?            // 元のタイムスタンプJSON
    var originalTimestamps: [TranscriptionSegment]? // 元のセグメント配列
    
    // 表示用データ（編集可能）
    var transcription: String?                   // 現在表示されるテキスト
    var editHistory: [EditOperation]?            // 編集履歴
    
    // 整合性状態
    var timestampValidity: TimestampValidity     // タイムスタンプの有効性
    var lastEditDate: Date?                      // 最終編集日時
}

enum TimestampValidity {
    case valid           // 編集なし、タイムスタンプ有効
    case partialValid    // 軽微な編集、部分的に有効
    case invalid         // 大幅編集、タイムスタンプ無効
}

struct EditOperation {
    let id: UUID
    let type: EditType
    let range: NSRange
    let originalText: String
    let newText: String
    let timestamp: Date
}

enum EditType {
    case insert, delete, replace
}
```

#### B. 編集影響度の自動判定
```swift
func analyzeEditImpact(_ edit: EditOperation, segments: [TranscriptionSegment]) -> TimestampValidity {
    let affectedSegments = findAffectedSegments(edit.range, in: segments)
    
    switch edit.type {
    case .replace where edit.originalText.count == edit.newText.count:
        // 同じ文字数の置換（誤字修正等）→ タイムスタンプ維持
        return .valid
        
    case .insert, .delete where edit.newText.count < 10:
        // 短い挿入・削除 → 部分的影響
        return .partialValid
        
    default:
        // 大幅な変更 → タイムスタンプ無効
        return .invalid
    }
}
```

### 2. UI表示戦略

#### A. 編集状態に応じた表示モード自動切り替え
```swift
func getAvailableDisplayModes(for recording: Recording) -> [TranscriptionDisplayMode] {
    switch recording.timestampValidity {
    case .valid:
        return [.plainText, .timestamped, .segmented, .timeline]
    case .partialValid:
        return [.plainText, .timestamped] // セグメント・タイムライン表示は無効
    case .invalid:
        return [.plainText] // タイムスタンプ表示は全て無効
    }
}
```

#### B. 編集状態の視覚的表示
- **有効**: 通常のタイムスタンプ表示（青色）
- **部分的**: 影響範囲をグレーアウト
- **無効**: タイムスタンプ表示を非活性化、警告アイコン表示

### 3. Settings移動による表示モード簡素化

#### A. 現在の問題
- Detail画面で表示モード選択が目立ちすぎ
- 主要機能（テキスト表示・編集・再生）を阻害
- 初回ユーザーにとって複雑

#### B. 提案する改善
```swift
// Settings画面に移動
struct TranscriptionSettings {
    var defaultDisplayMode: TranscriptionDisplayMode = .plainText
    var showTimestampsWhenAvailable: Bool = true
    var autoSwitchModeOnEdit: Bool = true
    var preserveOriginalData: Bool = true
}

// Detail画面では簡潔に
struct RecordingDetailView {
    // メイン表示: デフォルトモードで表示
    // 切り替え: ツールバーの小さなボタンまたはコンテキストメニュー
    var body: some View {
        VStack {
            // 簡潔なツールバー
            HStack {
                // 編集状態表示
                TimestampValidityIndicator(validity: recording.timestampValidity)
                
                Spacer()
                
                // 表示モード（控えめ）
                if availableModes.count > 1 {
                    Menu("表示") {
                        ForEach(availableModes, id: \.self) { mode in
                            Button(mode.displayName) {
                                selectedMode = mode
                            }
                        }
                    }
                    .font(.caption)
                }
            }
            
            // メインコンテンツ
            TranscriptionDisplayView(recording: recording, displayMode: selectedMode)
        }
    }
}
```

### 4. 編集時の具体的な動作

#### A. 編集開始時
1. 現在のタイムスタンプ有効性をチェック
2. 編集モードに応じた警告表示
3. 自動バックアップ作成

#### B. 編集中
1. リアルタイムで影響範囲を分析
2. タイムスタンプ表示の動的更新
3. 影響を受けるセグメントのハイライト

#### C. 編集完了時
1. 最終的な影響度判定
2. タイムスタンプ有効性の更新
3. 利用可能な表示モードの更新

### 5. 進行表示の改善

#### A. 現在の問題
- 予測時間が不正確（体感とずれ）
- 静的すぎて停止している印象
- 進行している感覚が薄い

#### B. 改善提案
```swift
struct ImprovedTranscriptionProgress: View {
    let progress: Float
    let stage: String
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // 動的アイコン
                Image(systemName: "waveform.and.mic")
                    .foregroundColor(.blue)
                    .scaleEffect(isActive ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isActive)
                
                Text(stage)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                // パーセンテージのみ（時間予測削除）
                Text("\(Int(progress * 100))%")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            // 流れるようなプログレスバー
            ProgressView(value: progress)
                .progressViewStyle(FlowingProgressStyle())
                .scaleEffect(y: 2.0)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct FlowingProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color(.systemGray4))
            
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .blue, .blue.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .scaleEffect(x: configuration.fractionCompleted ?? 0, anchor: .leading)
                .animation(.easeOut(duration: 0.3), value: configuration.fractionCompleted)
        }
        .frame(height: 4)
        .cornerRadius(2)
    }
}
```

## 実装優先度

### P0 (即時実装)
1. **タイムスタンプ有効性判定**: 編集影響度の自動検出
2. **表示モード制限**: 編集状態に応じた利用可能モード制御
3. **進行表示改善**: 予測時間削除、動的アニメーション追加

### P1 (次期実装)
1. **Settings移動**: 表示モード設定のSettings移動
2. **編集履歴**: 操作の取り消し・やり直し機能
3. **部分タイムスタンプ**: 影響範囲の可視化

### P2 (将来実装)
1. **スマート修正**: AI支援による整合性維持
2. **タイムスタンプ再構築**: 編集後の自動タイムスタンプ推定

この設計により、編集機能とタイムスタンプの整合性を保ちながら、ユーザーにとって直感的で使いやすいインターフェースを実現できます。