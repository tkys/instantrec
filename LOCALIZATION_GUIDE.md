# InstantRec 多言語対応ガイド

## 概要
InstantRecにシンプルな多言語対応（日本語・英語）を実装しました。デバイスの言語設定に応じて自動的にUIが切り替わります。

## 実装内容

### 対応言語
- **日本語** (ja) - デフォルト
- **英語** (en)

### ローカライゼーションファイル

#### 日本語 (デフォルト)
`Sources/instantrec/Resources/Localizable.strings`
```
"preparing" = "準備中...";
"recording" = "録音中";
"stop" = "停止";
"starting_recording" = "録音を開始します...";
"processing_audio" = "音声を認識中...";
"microphone_permission_message" = "マイクへのアクセスを許可してください";
"open_settings" = "設定を開く";
"recordings_title" = "録音一覧";
"duration_format" = "再生時間: %.2f秒";
```

#### 英語
`Sources/instantrec/Resources/en.lproj/Localizable.strings`
```
"preparing" = "Preparing...";
"recording" = "Recording";
"stop" = "Stop";
"starting_recording" = "Starting recording...";
"processing_audio" = "Processing audio...";
"microphone_permission_message" = "Please allow microphone access";
"open_settings" = "Open Settings";
"recordings_title" = "Recordings";
"duration_format" = "Duration: %.2fs";
```

### 実装されたUI要素

| UI要素 | ローカライゼーションキー | 日本語 | 英語 |
|--------|-------------------------|--------|------|
| 準備中画面 | `preparing` | 準備中... | Preparing... |
| 録音状態表示 | `recording` | 録音中 | Recording |
| 停止ボタン | `stop` | 停止 | Stop |
| 録音開始表示 | `starting_recording` | 録音を開始します... | Starting recording... |
| 音声処理表示 | `processing_audio` | 音声を認識中... | Processing audio... |
| 権限要求メッセージ | `microphone_permission_message` | マイクへのアクセスを許可してください | Please allow microphone access |
| 設定ボタン | `open_settings` | 設定を開く | Open Settings |
| 録音一覧タイトル | `recordings_title` | 録音一覧 | Recordings |

## 自動言語切り替えの仕組み

### iOS標準機能
1. **デバイス設定**: 設定 > 一般 > 言語と地域 > iPhone の使用言語
2. **自動検出**: アプリが起動時にシステム言語を検出
3. **リソース選択**: 対応する`.lproj`フォルダから文字列を読み込み

### 実装方法
```swift
// 従来（ハードコーディング）
Text("録音中")

// 多言語対応後（LocalizedStringKey）
Text("recording")  // SwiftUIが自動的にLocalizable.stringsから読み込み
```

### 特殊な実装（NSLocalizedString）
```swift
// 動的文字列フォーマット
Text(String(format: NSLocalizedString("duration_format", comment: ""), recording.duration))
```

## テスト方法

### シミュレーターでのテスト
1. **日本語テスト**
   ```bash
   # シミュレーター言語を日本語に設定
   xcrun simctl spawn booted defaults write NSGlobalDomain AppleLanguages -array ja
   xcrun simctl spawn booted defaults write NSGlobalDomain AppleLocale -string ja_JP
   ```

2. **英語テスト**
   ```bash
   # シミュレーター言語を英語に設定
   xcrun simctl spawn booted defaults write NSGlobalDomain AppleLanguages -array en
   xcrun simctl spawn booted defaults write NSGlobalDomain AppleLocale -string en_US
   ```

3. **アプリ再起動** - 言語変更を反映

### 実機でのテスト
1. **設定 > 一般 > 言語と地域**
2. **iPhone の使用言語を変更**
3. **InstantRecアプリを起動**

## 言語追加方法

### 新しい言語を追加する場合

1. **ディレクトリ作成**
   ```bash
   mkdir -p Sources/instantrec/Resources/[言語コード].lproj
   ```

2. **Localizable.strings作成**
   ```bash
   # 例：中国語簡体字の場合
   cp Sources/instantrec/Resources/en.lproj/Localizable.strings Sources/instantrec/Resources/zh-Hans.lproj/
   ```

3. **翻訳**
   - 各文字列を対象言語に翻訳

4. **Xcodeプロジェクト設定**
   - Project Navigator > InstantRec > Project > Localizations > + ボタン

### よく使われる言語コード
- `zh-Hans` - 中国語簡体字
- `zh-Hant` - 中国語繁体字
- `ko` - 韓国語
- `es` - スペイン語
- `fr` - フランス語
- `de` - ドイツ語

## 設計思想

### シンプルさの維持
- **最小限の文字列のみローカライズ**
- **複雑な設定画面は不要**
- **ユーザーの手動言語選択機能は非実装**

### パフォーマンス
- **起動時間への影響なし**
- **メモリ使用量増加: < 1KB**
- **文字列読み込みのキャッシュ効果**

## 注意事項

### フォールバック
- 対応していない言語の場合、英語が表示される
- 英語ファイルが見つからない場合、日本語が表示される

### 文字列の長さ
- 英語は日本語より短い傾向
- 現在のUIレイアウトは両言語で動作確認済み

### 右から左書きの言語
- アラビア語・ヘブライ語は未対応
- 必要に応じてRTL（Right-to-Left）レイアウト対応が必要

---

**実装日**: 2025-07-19  
**対応言語**: 日本語・英語  
**ファイル**: LOCALIZATION_GUIDE.md