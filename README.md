# レシピぽけっと

レシピのURLをタイトル・タグとともに端末内に保存し、あとから探して元のサイトを開く iPhone アプリ。仕様は [docs/specifications](docs/specifications/README.md)、公開前に入れる値と作業は [公開前の作業](docs/release-checklist.md) にまとめている。

## 動かし方

| 項目 | 内容 |
| --- | --- |
| 開発環境 | Xcode 26 以降 |
| 対象 | iPhone、iOS 18 以降 |

1. `RecipePocket.xcodeproj` を Xcode で開く。
2. スキーム `RecipePocket` を選び、シミュレータで実行する。

Firebase の設定ファイル（`RecipePocket/Resources/GoogleService-Info.plist`）を置かなければ、解析は送信しない。Debug ビルドでは、設定ファイルがあっても起動引数 `-FIRDebugEnabled` を付けたときだけ送信する。

件数の多い一覧や検索を確かめるときは、Debug ビルドで起動引数 `-SeedRecipes 5000` を付けると、記録が空の場合に見本を5,000件入れる。App Store 用のスクリーンショットを撮るときは、`-SeedScreenshotRecipes` を付けると、実在しない見本のサイトの記録を入れる。

## 構成

| 場所 | 内容 |
| --- | --- |
| `RecipePocket/` | 本体アプリの画面と、一覧・検索・タイトル取得の状態 |
| `ShareExtension/` | 共有シートから保存する画面 |
| `Shared/` | 本体と共有拡張の両方に入れる素材（アクセントカラー） |
| `RecipeKit/Sources/RecipeCore/` | URLの検証と重複判定、タグ、検索、対応サイトからのタイトル取得。画面と保存に依存しない |
| `RecipeKit/Sources/RecipeData/` | 端末内の保存（SwiftData）。本体と共有拡張が App Group の同じ保存先を使う |
| `RecipeKit/Sources/RecipeUI/` | 本体と共有拡張が使う登録・編集のフォーム |
| `Config/` | Info.plist、App Group の設定、ビルド設定（xcconfig） |
| `web/` | 公開する Web ページ（利用条件・プライバシー説明・問い合わせ）を作る仕組み。文面はアプリと同じ `RecipePocket/Support/PolicyText.swift` を使い、運営者名・問い合わせ先は `Config/Local.xcconfig` から入れる |

## テスト

RecipeKit のテストは Mac で実行できる。

```bash
swift test --package-path RecipeKit
```

アプリと共有拡張を含めたビルドとテストは、シミュレータを指定して実行する。

```bash
xcodebuild test -project RecipePocket.xcodeproj -scheme RecipePocket -destination 'platform=iOS Simulator,name=iPhone 17'
```
