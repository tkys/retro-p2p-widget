# Winamp Classic Skin Layout Specification

Source: [captbaritone/webamp](https://github.com/captbaritone/webamp) - `packages/webamp/css/main-window.css`

## Main Window

- Canvas: **275 × 116 px**
- All positions are absolute pixel coordinates from top-left origin

## Element Map

### Title Bar (y: 0-14)

| Element | Left | Top | Width | Height | Description |
|---------|------|-----|-------|--------|-------------|
| #title-bar | 0 | 0 | 275 | 14 | タイトルバー全体 |
| #option-context | 6 | 3 | 9 | 9 | メニューボタン |
| #minimize | 244 | 3 | 9 | 9 | 最小化ボタン |
| #shade | 254 | 3 | 9 | 9 | シェードモードボタン |
| #close | 264 | 3 | 9 | 9 | 閉じるボタン |

### Display Area (y: 22-55)

| Element | Left | Top | Width | Height | Description |
|---------|------|-----|-------|--------|-------------|
| #clutter-bar | 10 | 22 | 8 | 43 | 左サイドバー |
| #play-pause | 26 | 28 | 9 | 9 | 再生/一時停止インジケータ |
| **#time** | **39** | **26** | **59** | **13** | **時刻表示コンテナ** |
| #visualizer | 24 | 43 | - | - | ビジュアライザ |
| **#marquee** | **111** | **24** | **154** | **6** | **曲名スクロール表示** |
| **#kbps** | **111** | **43** | **15** | **6** | **ビットレート表示** |
| **#khz** | **156** | **43** | **10** | **6** | **サンプルレート表示** |
| #mono/#stereo | 212 | 41 | 57 | 12 | モノラル/ステレオ表示 |

### Time Digits (relative to #time container at 39, 26)

| Element | Offset Left | Width | Height | Absolute X |
|---------|-------------|-------|--------|------------|
| minus-sign | -1 | 5 | 1 (top:6) | 38 |
| minute-first-digit | 9 | 9 | 13 | 48 |
| minute-second-digit | 21 | 9 | 13 | 60 |
| second-first-digit | 39 | 9 | 13 | 78 |
| second-second-digit | 51 | 9 | 13 | 90 |

- numbers.bmp sprite: 各数字 **9 × 13 px**, 0-9 が横一列 (total 99×13 or 108×13)

### Controls (y: 57-82)

| Element | Left | Top | Width | Height | Description |
|---------|------|-----|-------|--------|-------------|
| #volume | 107 | 57 | 68 | 13 | 音量スライダー |
| #balance | 177 | 57 | 38 | 13 | バランススライダー |
| #eq-button | 219 | 58 | 23 | 12 | EQ トグル |
| #playlist-button | 242 | 58 | 23 | 12 | プレイリストトグル |
| #position | 16 | 72 | 248 | 10 | シークバー |

### Action Buttons (y: 88-106)

| Element | Left | Top | Width | Height | Description |
|---------|------|-----|-------|--------|-------------|
| #previous | 16 | 88 | 23 | 18 | 前の曲 |
| #play | 39 | 88 | 23 | 18 | 再生 |
| #pause | 62 | 88 | 23 | 18 | 一時停止 |
| #stop | 85 | 88 | 23 | 18 | 停止 |
| #next | 108 | 88 | 22 | 18 | 次の曲 |
| #eject | 136 | 89 | 22 | 16 | イジェクト |
| #shuffle | 164 | 89 | 47 | 15 | シャッフル |
| #repeat | 210 | 89 | 28 | 15 | リピート |

## Widget で活用する要素

Widget は静的表示のため、以下を優先的に再現する:

1. **#time** — 現在時刻をスプライト数字で表示（必須）
2. **#marquee** — 日付やカスタムテキストのスクロール表示に転用
3. **#kbps / #khz** — 日付・曜日などの固定テキスト表示に転用
4. **#title-bar** — titlebar.bmp によるヘッダー装飾
5. **#visualizer** — 静的なバー/波形風装飾
6. **背景** — main.bmp をそのまま使用

## .wsz ファイル構造

`.wsz` は `.zip` のリネーム。主要な画像ファイル:

| File | Size | Description |
|------|------|-------------|
| main.bmp | 275×116 | メインウィンドウ背景 |
| titlebar.bmp | 344×87 | タイトルバー各状態のスプライトシート |
| numbers.bmp | 99×13 or 108×13 | 数字 0-9 のスプライトシート |
| text.bmp | varies | テキスト文字のビットマップフォント |
| playpaus.bmp | varies | 再生状態インジケータ |
| posbar.bmp | varies | シークバー |
| volume.bmp | varies | 音量バー |
| balance.bmp | varies | バランスバー |
| cbuttons.bmp | varies | コントロールボタン |
| monoster.bmp | varies | モノ/ステレオインジケータ |
| shufrep.bmp | varies | シャッフル/リピートボタン |
| eqmain.bmp | varies | イコライザウィンドウ |
| pledit.bmp | varies | プレイリストウィンドウ |
| viscolor.txt | - | ビジュアライザの色定義 |
| pledit.txt | - | プレイリストのテキスト色定義 |

## スキン入手先

- https://skins.webamp.org/ — 100K+ スキンアーカイブ
- https://qmmp.ylsoftware.com/files/skins/winamp-skins/ — ダウンロード可能な .wsz コレクション
