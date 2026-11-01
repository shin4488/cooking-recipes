# 公開前の作業

App Store で公開する前に入れる値と、行う作業。git で管理しない値は、手元のファイルに入れる。

## 入れる値

| 値 | 入れる場所 | git | 使われる場所 |
| --- | --- | --- | --- |
| Team ID | `Config/Local.xcconfig` の `DEVELOPMENT_TEAM` | 管理しない | 署名 |
| 運営者名 | `Config/Local.xcconfig` の `OPERATOR_NAME` | 管理しない | 設定の「プライバシーと外部送信」「利用条件」と、公開する Web ページ |
| 問い合わせ先のメールアドレス | `Config/Local.xcconfig` の `CONTACT_EMAIL` | 管理しない | 設定の「問い合わせ（メール）」、上の2画面、公開する Web ページ |
| Firebase の設定ファイル | `RecipePocket/Resources/GoogleService-Info.plist` | 管理しない | 解析の送信。置かなければ送信しない |
| AdMob のアプリ ID | `Config/Local.xcconfig` の `ADMOB_APP_ID` | 管理しない | Info.plist の `GADApplicationIdentifier`。広告と同意の確認に使う |
| 一覧のバナーの広告ユニット ID | `Config/Local.xcconfig` の `ADMOB_BANNER_UNIT_ID` | 管理しない | 一覧の下に出す広告 |
| AdMob のパブリッシャー ID | `Config/Local.xcconfig` の `ADMOB_PUBLISHER_ID` | 管理しない | `web/build.sh` で作る `app-ads.txt` |
| 利用条件・プライバシー説明の文面 | `RecipePocket/Support/PolicyText.swift` | 管理する | 設定の「利用条件」「プライバシーと外部送信」と、公開する Web ページ |

`Config/Local.xcconfig` は、`Config/Local.example.xcconfig` をコピーして作る。App Store 向けのアーカイブ（Product > Archive）では、`DEVELOPMENT_TEAM`・`OPERATOR_NAME`・`CONTACT_EMAIL`・`ADMOB_APP_ID`・`ADMOB_BANNER_UNIT_ID` のどれかが空のときと、AdMob の ID が Google のテスト用の ID のときに、ビルドを止める。Debug ビルドでは、`ADMOB_APP_ID`・`ADMOB_BANNER_UNIT_ID` が空なら Google のテスト用の ID（[Google の説明](https://developers.google.com/admob/ios/test-ads?hl=ja)）を使う。Release ビルド（Xcode の Profile を含む）はテスト用の ID を使わず、`ADMOB_APP_ID` が空だと Google Mobile Ads SDK が起動の直後に例外（`GADInvalidInitializationException`）でアプリを止める。

```bash
cp Config/Local.example.xcconfig Config/Local.xcconfig
```

## 作業

| 順 | 作業 | 確かめること |
| --- | --- | --- |
| 1 | Apple Developer Program に加入し、Team ID を `Config/Local.xcconfig` に入れる | Xcode の Signing & Capabilities で、本体と共有拡張の両方に App Group `group.com.shin4488.cookingrecipes` が有効になっている |
| 2 | Firebase コンソールでプロジェクトを作り、Google Analytics を有効にする。iOS アプリ（Bundle ID `com.shin4488.cookingrecipes`）を登録し、`GoogleService-Info.plist` を上の場所に置く | Google Analytics のプロパティで、Google シグナルと広告のパーソナライズを無効にする（仕様の「解析データの広告利用は無効にする」）。管理の「データの保持」で、イベントデータとユーザーデータの保持をどちらも14か月にし、「新しいユーザー アクティビティのたびにリセット」をオンにする（プライバシー説明の「保存期間と削除」と同じ扱い） |
| 3 | [Google の同意取得方針](https://business.safety.google/intl/ja/appi/)に基づき、提供する項目・期間と確認した内容を記録する | 仕様の [個人関連情報](specifications/2-data.md#法的な整理) の扱いと合っている |
| 4 | 利用条件・プライバシー説明の下書きを確定し、Web に公開する。`web/build.sh` で、`Config/Local.xcconfig` の運営者名・問い合わせ先を入れたページを `web/public` に作り、下の「Web ページの公開」の手順で Firebase Hosting に公開する | `https://cooking-recipes-ab42e.web.app/privacy`・`/terms`・`/support` が開ける。プライバシー説明に、[審査ガイドライン 5.1.1(i)](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage) が求める、集める情報と使い道・第三者の扱い・保存期間と削除の求め方・同意の取り消し方がある |
| 5 | Debug ビルドに起動引数 `-FIRDebugEnabled` を付け、Firebase の DebugView で送信内容を確かめる | 画面名、操作の種類、登録時に付けたタグの数、ごみ箱を空にした件数、検索条件の追加元（タグか入力か）と、広告の表示などで自動で記録されるイベント（`ad_impression` など、[Google の説明](https://support.google.com/analytics/answer/9234069?hl=ja)）だけが届き、URL・タイトル・タグ名・検索語が含まれない |
| 6 | 実機で確かめる | iPhone SE（第3世代）で[性能目標](specifications/3-technology.md#非機能要件)を満たす。Safari・Chrome の共有から保存できる。設定の「問い合わせ（メール）」「不適切な広告を報告（メール）」からメールを作れる。VoiceOver・文字サイズの変更・ダーク表示で操作できる |
| 7 | App Store Connect でアプリを登録する。入れる文面・回答・スクリーンショットは [App Store に入れる内容](app-store-listing.md) の下書きを使う | プライバシーポリシーのURL、サポートURL（手順4のページ。[審査ガイドライン 1.5](https://developer.apple.com/app-store/review/guidelines/#developer-information) により連絡方法を載せる）、マーケティングURL、App のプライバシー（Firebase の[データ開示の案内](https://firebase.google.com/docs/ios/app-store-data-collection)と AdMob の [App Store のデータ開示](https://developers.google.com/admob/ios/privacy/data-disclosure?hl=ja)に合わせる）、年齢制限、スクリーンショットを入れた |
| 8 | Xcode で Product > Archive を行い、App Store Connect へアップロードする | アーカイブが設定の確認で止まらない |
| 9 | App Store Connect で審査に提出し、承認されたら公開する | 審査担当からの連絡先を入れた |

## 広告を始めるときの作業

一覧の下に AdMob のバナー広告を出し、UMP（Google User Messaging Platform）で必要な同意を扱う。上の作業を済ませ、App Store で公開した後に行う。

| 順 | 作業 | 確かめること |
| --- | --- | --- |
| 1 | [AdMob に申し込む](https://support.google.com/admob/answer/7356219?hl=ja)。Google アカウントでログインし、国または地域（後から変えられない）を選び、お支払い情報を入れてアカウントの確認を受ける | アカウントの確認が済んだ。Google の説明では、通常24時間以内、まれに最大2週間かかる |
| 2 | AdMob の「アプリ」→「アプリを追加」で iOS を選び、「はい、アプリはサポートされているアプリストアに登録されています」から「レシピぽけっと」を探して追加する（[Google の説明](https://support.google.com/admob/answer/9989980?hl=ja)） | アプリが App Store の掲載情報とつながった。AdMob のアプリを Firebase にはリンクしない（仕様の「解析データの広告利用は無効にする」、[リンクの説明](https://support.google.com/admob/answer/6383165?hl=ja)） |
| 3 | 追加したアプリの「広告ユニット」で、バナーの広告ユニットを1つ作り、「詳細設定」の「自動更新」を Google が勧める、Google が最適化した頻度にする（[Google の説明](https://support.google.com/admob/answer/3245199?hl=ja)） | 自動更新が無効になっていない。アプリは表示中のバナーを自分では読み込み直さず、SDK が AdMob の自動更新の設定に従って入れ替える（[Google の説明](https://developers.google.com/admob/ios/banner?hl=ja)） |
| 4 | アプリ ID と広告ユニット ID（[確かめ方](https://support.google.com/admob/answer/7356431?hl=ja)）、AdMob の「設定」にあるパブリッシャー ID を、`Config/Local.xcconfig` の `ADMOB_APP_ID`・`ADMOB_BANNER_UNIT_ID`・`ADMOB_PUBLISHER_ID` に入れる | アプリ ID は `ca-app-pub-…~…`、広告ユニット ID は `ca-app-pub-…/…`、パブリッシャー ID は `pub-…` の形になっている |
| 5 | AdMob の「プライバシーとメッセージ」で、欧州の規制に関するメッセージを作って公開する（[Google の説明](https://support.google.com/admob/answer/10113207?hl=ja)）。欧州経済領域・英国・スイスから使う人に、広告の同意を求めるため | Debug ビルドに起動引数 `-UMPDebugGeographyEEA` を付けてシミュレータで起動すると、作ったメッセージが出る。選んだ後、設定に「広告の同意の設定」が出て、選び直せる |
| 6 | AdMob の「ブロックの管理」→「広告レーティングを管理」で、広告レーティングの上限を選ぶ（[Google の説明](https://support.google.com/admob/answer/7562142?hl=ja)） | App Store の年齢制限と合う上限を選んだ |
| 7 | Debug ビルドで広告を確かめる。実機で手順4の ID を使って確かめるときは、先にその端末を AdMob のテスト端末に登録する（[Google の説明](https://developers.google.com/admob/ios/test-ads?hl=ja)） | 広告は一覧の下にだけ出て、登録・編集の画面・設定・検索の入力中には出ない。読み込めないときは場所を取らず、ほかの操作を続けられる。設定の「不適切な広告を報告（メール）」からメールを作れる |
| 8 | `web/build.sh` でページと `app-ads.txt` を作り、下の「Web ページの公開」の手順（Docker の中の firebase-tools で `deploy --only hosting --project cooking-recipes-ab42e`）で公開する | `https://cooking-recipes-ab42e.web.app/app-ads.txt` に `google.com, pub-…, DIRECT, f08c47fec0942fa0` の1行が出る（[Google の説明](https://developers.google.com/admob/ios/app-ads?hl=ja)）。プライバシー説明に AdMob・UMP の送信先が出る |
| 9 | 上の作業の3の記録に、AdMob・UMP に提供する項目を加える | 仕様の [個人関連情報](specifications/2-data.md#法的な整理) の扱いと合っている |
| 10 | App Store Connect で、[App Store に入れる内容](app-store-listing.md)に合わせて、マーケティングURL・App のプライバシー・年齢制限・App Review へのメモを変える | マーケティングURL が `https://cooking-recipes-ab42e.web.app` になっている。App のプライバシーに広告の SDK の分が入った。年齢制限の質問で、広告（Advertising）があると答えた |
| 11 | 版（`MARKETING_VERSION`）とビルド番号（`CURRENT_PROJECT_VERSION`）を上げ、上の作業の8・9と同じようにアーカイブして審査に提出する | アーカイブが設定の確認で止まらない。提出する前に、Organizer の「Generate Privacy Report」で SDK の申告を見て、App のプライバシーの回答と合っている |
| 12 | 公開した後、AdMob で app-ads.txt とアプリの準備状況を確かめる | app-ads.txt が確認済みになった（Google の説明では、確認に最大24時間かかる）。アプリの準備状況の審査が済んだ |

`Config/RecipePocket-Info.plist` の `SKAdNetworkItems` は、Google の[クイックスタート](https://developers.google.com/admob/ios/quick-start?hl=ja)にある一覧（2026年11月1日に確認した50件）に合わせた。広告を始める前と SDK の版を上げるときに、一覧が変わっていないかを確かめる。

## Web ページの公開

Firebase CLI は PC に入れず、Docker の Node のイメージの中で動かす。ログインの情報は Docker のボリューム `recipe-pocket-firebase-config` に残るため、2回目からはログインを省ける。版を上げるときは、Node・firebase-tools とも公開から7日以上たった版にする。

初回だけログインする。表示された URL をブラウザで開いて Google アカウントで許可し、セッション ID が CLI の表示と同じことを確かめてから、表示された認証コードを入力する。任意の機能を使うかの質問（`(Y/n)`）には `n` で答える。

```bash
docker run --rm -it -v recipe-pocket-firebase-config:/root/.config -v recipe-pocket-npm-cache:/root/.npm node:24.22.1-slim npx -y firebase-tools@15.34.1 login --no-localhost
```

リポジトリの直下で、`web/build.sh` で作ったページを公開する。

```bash
docker run --rm -v recipe-pocket-firebase-config:/root/.config -v recipe-pocket-npm-cache:/root/.npm -v "$PWD/web:/work" -w /work node:24.22.1-slim npx -y firebase-tools@15.34.1 deploy --only hosting --project cooking-recipes-ab42e
```

使わなくなったら、上のログインのコマンドの `login --no-localhost` を `logout` に変えて実行し、`docker volume rm recipe-pocket-firebase-config recipe-pocket-npm-cache` でボリュームを消す。
