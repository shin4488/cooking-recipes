# 公開前の作業

App Store で公開する前に入れる値と、行う作業。git で管理しない値は、手元のファイルに入れる。

## 入れる値

| 値 | 入れる場所 | git | 使われる場所 |
| --- | --- | --- | --- |
| Team ID | `Config/Local.xcconfig` の `DEVELOPMENT_TEAM` | 管理しない | 署名 |
| 運営者名 | `Config/Local.xcconfig` の `OPERATOR_NAME` | 管理しない | 設定の「プライバシーと外部送信」「利用条件」と、公開する Web ページ |
| 問い合わせ先のメールアドレス | `Config/Local.xcconfig` の `CONTACT_EMAIL` | 管理しない | 設定の「問い合わせ（メール）」、上の2画面、公開する Web ページ |
| Firebase の設定ファイル | `RecipePocket/Resources/GoogleService-Info.plist` | 管理しない | 解析の送信。置かなければ送信しない |
| 利用条件・プライバシー説明の文面 | `RecipePocket/Support/PolicyText.swift` | 管理する | 設定の「利用条件」「プライバシーと外部送信」と、公開する Web ページ |

`Config/Local.xcconfig` は、`Config/Local.example.xcconfig` をコピーして作る。App Store 向けのアーカイブ（Product > Archive）では、`DEVELOPMENT_TEAM`・`OPERATOR_NAME`・`CONTACT_EMAIL` のどれかが空ならビルドを止める。

```bash
cp Config/Local.example.xcconfig Config/Local.xcconfig
```

## 作業

| 順 | 作業 | 確かめること |
| --- | --- | --- |
| 1 | Apple Developer Program に加入し、Team ID を `Config/Local.xcconfig` に入れる | Xcode の Signing & Capabilities で、本体と共有拡張の両方に App Group `group.com.shin4488.cookingrecipes` が有効になっている |
| 2 | Firebase コンソールでプロジェクトを作り、Google Analytics を有効にする。iOS アプリ（Bundle ID `com.shin4488.cookingrecipes`）を登録し、`GoogleService-Info.plist` を上の場所に置く | Google Analytics のプロパティで、Google シグナルと広告のパーソナライズを無効にする（仕様の「解析データの広告利用は無効にする」）。データの保持期間を、プライバシー説明と同じ2か月にする |
| 3 | [Google の同意取得方針](https://business.safety.google/intl/ja/appi/)に基づき、提供する項目・期間と確認した内容を記録する | 仕様の [個人関連情報](specifications/2-data.md#法的な整理) の扱いと合っている |
| 4 | 利用条件・プライバシー説明の下書きを確定し、Web に公開する。`web/build.sh` で、`Config/Local.xcconfig` の運営者名・問い合わせ先を入れたページを `web/public` に作り、`web` フォルダで `firebase deploy --only hosting --project <プロジェクトID>` を実行する（初回は `npm install -g firebase-tools` と `firebase login` を先に行う） | `https://<プロジェクトID>.web.app/privacy`・`/terms`・`/support` が開ける。プライバシー説明に、[審査ガイドライン 5.1.1(i)](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage) が求める、集める情報と使い道・第三者の扱い・保存期間と削除の求め方・同意の取り消し方がある |
| 5 | Debug ビルドに起動引数 `-FIRDebugEnabled` を付け、Firebase の DebugView で送信内容を確かめる | 画面名、操作の種類、登録時に付けたタグの数、ごみ箱を空にした件数、検索条件の追加元（タグか入力か）だけが届き、URL・タイトル・タグ名・検索語が含まれない |
| 6 | 実機で確かめる | iPhone SE（第3世代）で[性能目標](specifications/3-technology.md#非機能要件)を満たす。Safari・Chrome の共有から保存できる。設定の「問い合わせ（メール）」からメールを作れる。VoiceOver・文字サイズの変更・ダーク表示で操作できる |
| 7 | App Store Connect でアプリを登録する。入れる文面・回答・スクリーンショットは [App Store に入れる内容](app-store-listing.md) の下書きを使う | プライバシーポリシーのURL、サポートURL（手順4のページ。[審査ガイドライン 1.5](https://developer.apple.com/app-store/review/guidelines/#developer-information) により連絡方法を載せる）、App のプライバシー（Firebase の[データ開示の案内](https://firebase.google.com/docs/ios/app-store-data-collection)に合わせる）、年齢制限、スクリーンショットを入れた |
| 8 | Xcode で Product > Archive を行い、App Store Connect へアップロードする | アーカイブが設定の確認で止まらない |
| 9 | App Store Connect で審査に提出し、承認されたら公開する | 審査担当からの連絡先を入れた |

## このビルドに含めていないもの

広告（AdMob・UMP）はまだ組み込んでいない。追加するときは、同意の扱い、プライバシー説明の送信先、Web に置く `app-ads.txt` を合わせて用意する。
