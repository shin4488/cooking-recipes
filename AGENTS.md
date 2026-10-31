# 開発ガイド

レシピのURLを端末内に保存する iPhone アプリ「レシピぽけっと」。仕様は `docs/specifications/`、動かし方と構成は [README](README.md) を読む。

## 守ること

- 保存したURL・タイトル・タグ、検索語、記録のID、レシピサイトの閲覧履歴を、解析（`AnalyticsEvent`）や診断ログに渡さない。
- サイトからのタイトル取得は `SupportedSite` の範囲に限る。対応サイトを増やすときは、公式条件または個別許諾の根拠を `docs/specifications/2-data.md` に記録してから行う。
- 保存形式（`RecipeSchemaV1`）を変えるときは、新しい版と移行を `RecipeMigrationPlan` に足し、既存のデータを読めるようにする。
- `Config/Local.xcconfig` と `GoogleService-Info.plist`、運営者名・問い合わせ先を含めて作る `web/public` はコミットしない。
- 利用条件・プライバシー説明の文面は `RecipePocket/Support/PolicyText.swift` で変える。変えたら `web/build.sh` で Web ページを作り直し、公開中のページも更新する。
- Firebase の版は `RecipePocket.xcodeproj` で固定している。上げるときは公開から7日以上たった版を選び、`RecipePocket/Resources/ThirdPartyLicenses.txt` も更新する。

## 検証

- RecipeKit を変えたら `swift test --package-path RecipeKit` を実行する。
- アプリ・共有拡張・プロジェクトの設定を変えたら、README の `xcodebuild test` を実行し、シミュレータで変えた画面を確かめる。
- CI（`.github/workflows/ci.yml`）は RecipeKit のテストとアプリのビルドを行う。
