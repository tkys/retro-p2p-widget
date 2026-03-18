# 設計プラン: Issues 1-3 修正

## 概要

2026-03-18 テストで発見された3つの問題に対する設計方針。
開発は後日実施。

---

## Issue 3: スキンごとの時計配置ズレ（最優先）

### 根本原因

`WinampLayout` は Winamp 標準仕様 (275x116) の固定座標をハードコードしている:
```
timeCenterX: 68.5, timeCenterY: 32.5
marqueeCenterX: 188, marqueeCenterY: 27
```

しかし実際のスキンを確認すると:
- **winamp-classic**: 標準レイアウト準拠 → 位置OK
- **njoy-green**: ほぼ標準だがボタンラベル(RW/PL/PS等)が大きめ → 微ズレ
- **dark-materia**: タイトルバー構成が根本的に異なる（"winamp"テキストが右上、
  ウィンドウ枠がピンク、表示エリアの配置が標準と異なる）→ 大きくズレ

### 方針: スキン JSON にオフセットを持たせる

各スキンの JSON に `layout` フィールドを追加。未指定なら標準仕様をフォールバック。

```json
// winamp-classic.json — 標準なので省略可
{
  "images": { ... },
  "layout": null
}

// dark-materia.json — カスタムオフセット
{
  "images": { ... },
  "layout": {
    "timeCenterX": 60,
    "timeCenterY": 34,
    "marqueeCenterX": 175,
    "marqueeCenterY": 28
  }
}
```

### 実装ステップ

1. `SkinDefinition` に `layout: SkinLayout?` を追加
   ```swift
   struct SkinLayout: Codable, Hashable {
       var timeCenterX: CGFloat?
       var timeCenterY: CGFloat?
       var marqueeCenterX: CGFloat?
       var marqueeCenterY: CGFloat?
   }
   ```

2. `WinampLayout.relativePosition()` でスキンの layout 値を優先使用
   ```swift
   static func relativePosition(canvasX: CGFloat, canvasY: CGFloat,
                                 family: WidgetFamily) -> CGPoint
   // ↓ 変更
   static func relativePosition(element: LayoutElement,
                                 skin: SkinDefinition,
                                 family: WidgetFamily) -> CGPoint
   ```

3. 各スキンの main.png を目視確認し、JSON にオフセット値を設定
   - winamp-classic: 省略（デフォルト値を使用）
   - njoy-green: 微調整が必要か確認
   - dark-materia: 個別値を設定

4. 将来の新スキン追加時: compose-skin.sh 実行後に目視確認し、
   ズレがあれば JSON に layout を追記するワークフロー

### 代替案（不採用の理由）

- **画像解析で自動検出**: main.bmp から表示領域を自動検出する案。
  精度が不安定で、スキンによってはビジュアライザ領域と時計領域の区別が困難。
  手動設定の方が確実。

- **compose-skin.sh で座標を抽出**: BMP のピクセル分析は可能だが、
  スキンごとの差異が大きすぎて汎用ロジックが組めない。

---

## Issue 2: EQ バーとデータテキストの重なり

### 根本原因

- EQ バーは `compose-skin.sh` で `bg-large.png` に焼き込み済み
- データテキストは SwiftUI で同じ Y 座標範囲にオーバーレイ
- データソースの有無に関わらず、EQ バーは常に表示される

### 方針: SwiftUI 側で背景マスクを重ねる

bg-large.png を2種類生成する案は、スキン管理の複雑さが増すので不採用。
代わりに SwiftUI 側で解決する。

```
データソースなし:  bg-large.png そのまま表示（EQ バーが見える）
データソースあり:  該当ゾーンに半透明の背景矩形を敷き、その上にテキスト
```

### 実装ステップ

1. `dataOverlay()` を修正: テキスト表示時にバックドロップを追加
   ```swift
   // EQ zone にデータがある場合
   RoundedRectangle(cornerRadius: 4)
       .fill(skin.backgroundColor.opacity(0.85))
       .frame(width: size.width * 0.9, height: eqZoneHeight)
       .position(...)

   Text(eqText)
       .position(...)  // 同じ位置
   ```

2. Playlist zone も同様の処理

3. バックドロップの色はスキンの `background.color` を使用し、
   EQ バーを「暗く覆い隠す」効果を出す

### 代替案（将来検討）

- bg-large.png を EQ バーなし版も生成（`bg-large-clean.png`）
  → データソース設定時に SwiftUI 側で切り替え
  → スキンファイル管理が複雑化するので現時点では不採用

---

## Issue 1: データソース表示ゾーンの重複制御

### 根本原因

- `DataSourceConfigView` でゾーン選択に制約がない
- 同じゾーンに N 個のデータソースを登録可能
- 表示ロジックが曖昧（marquee/eq は先勝ち、playlist は全表示）

### 方針: ゾーン別スロット制 + UI での明示

| Zone | スロット数 | 理由 |
|------|-----------|------|
| marquee | 1 | 1行テキストエリア。複数は物理的に無理 |
| eq | 1〜3 | 複数行表示可能だが、スペース限定 |
| playlist | 1〜5 | トラックリスト風に複数行表示可能 |

### 実装ステップ

1. `DataSourceListView` にゾーン別のセクション表示
   ```swift
   Section("Marquee") {
       // marquee に割り当て済みのソース（0-1個）
   }
   Section("EQ Area") {
       // eq に割り当て済みのソース（0-3個）
   }
   Section("Playlist") {
       // playlist に割り当て済みのソース（0-5個）
   }
   ```

2. ゾーンが上限に達したら、新規追加時にそのゾーンを選択不可にする
   ```swift
   // DataSourceEditView の Picker で
   ForEach(DataSource.DisplayZone.allCases) { z in
       Text(zoneLabel(z))
           .tag(z)
           .disabled(isZoneFull(z) && z != currentZone)
   }
   ```

3. `RetroClockView` の表示ロジックを明確化
   - marquee: 最初の1つのみ
   - eq: 改行区切りで最大3つ
   - playlist: トラックリスト風に最大5つ

---

## 実装の優先順位

1. **Issue 3 (時計ズレ)** — ユーザー体験に最も影響。スキン JSON + SwiftUI 変更
2. **Issue 2 (EQ重なり)** — Issue 3 と同じ領域の修正なので連続で対応
3. **Issue 1 (ゾーン制御)** — UI 改善。機能は動くので優先度やや低め

### 見積もり作業量

| Issue | 変更ファイル数 | 規模 |
|-------|-------------|------|
| 3 | 4 (SkinDefinition, RetroClockView, 3x skin JSON) | Medium |
| 2 | 1 (RetroClockView) | Small |
| 1 | 2 (DataSourceConfigView, RetroClockView) | Medium |
