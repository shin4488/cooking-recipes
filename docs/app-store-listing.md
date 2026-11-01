# App Store に入れる内容

App Store Connect に入れる文面と、質問への回答の下書き。運営者名・連絡先などの個人の情報はここに書かず、App Store Connect に入力するときに入れる。

他社の商標をアプリ名・キーワード・スクリーンショットに使わないよう、対応サイトの名前は載せない（[審査ガイドライン 5.2.1](https://developer.apple.com/app-store/review/guidelines/#intellectual-property)・[2.3.7](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata)）。

## アプリの情報

| 項目 | 内容 |
| --- | --- |
| 名前（30文字まで） | レシピぽけっと |
| サブタイトル（30文字まで） | 気になるレシピを、タグで整理してとっておける |
| カテゴリ | フード/ドリンク |
| 価格 | 無料 |
| 配信する国・地域 | 日本 |
| Apple シリコン搭載の Mac での配信 | しない（案）。Mac での動作を確かめていないため |
| プライバシーポリシーのURL | `https://cooking-recipes-ab42e.web.app/privacy` |
| サポートURL | `https://cooking-recipes-ab42e.web.app/support` |
| マーケティングURL | `https://cooking-recipes-ab42e.web.app`。AdMob は、ここに入れたサイトの直下の `app-ads.txt` でアプリの販売者を確かめる（[Google の説明](https://developers.google.com/admob/ios/app-ads?hl=ja)） |
| 著作権 | 入力するときに、年と運営者名を入れる |
| App Review のサインイン | 不要（「サインインが必要です」のチェックを外す） |
| App Review の連絡先 | 入力するときに、氏名・電話番号・メールアドレスを入れる（公開されない） |
| リリースの方法 | 承認されたあとに手動でリリースする |

## 説明文

プロモーションテキスト（170文字まで）:

```text
ネットで見つけたレシピを、共有ボタンからそのまま保存できます。「鶏肉」「お弁当」などのタグを付けておけば、作りたい日にすぐ見つかります。会員登録はいりません。
```

説明（4,000文字まで）:

```text
ネットで見つけたレシピを、あとで作るときのためにとっておくアプリです。

Safari などで気になるレシピを見つけたら、共有ボタンから「レシピぽけっと」を選んで保存できます。「鶏肉」「お弁当」「時短」といったタグを付けておけば、献立に迷ったときもすぐに探せます。

【できること】
・Safari や Chrome の共有ボタンから保存
・URL を貼り付けて保存
・一部のレシピサイトは、保存したあとにタイトルが自動で入ります
・タグを付けて整理（前に使ったタグは候補から選べます）
・タイトル、タグ、サイト名で検索（一覧のタグをタップしても絞り込めます）
・好きな順番に並べ替え
・削除したレシピは30日間、ごみ箱から戻せます

【データについて】
会員登録やログインはいりません。レシピのデータは、お使いの iPhone の中にだけ保存されます。
アプリをよくするために、どの画面を開いたかなどの利用状況を送っています。送りたくないときは、設定からいつでも止められます。利用状況には、保存したレシピの URL・タイトル・タグや、検索した言葉は含めません。
```

キーワード（100文字まで、カンマ区切り）:

```text
保存,料理,献立,レシピ帳,ブックマーク,タグ,整理,お気に入り,メモ,自炊,時短,スクラップ,あとで見る,クリップ
```

## App のプライバシー（回答案）

Apple は、アプリが端末の外へ送ったデータを、運営者や、アプリに組み込んだ他社のコード（解析ツール・SDK など）が、要求に応じるのに必要な間より長く読めることを「収集」とする（[App のプライバシーの説明](https://developer.apple.com/app-store/app-privacy-details/)）。このアプリで当たるのは、Google Analytics for Firebase に送る利用状況と、広告の SDK（Google Mobile Ads SDK・User Messaging Platform SDK）が送る情報。タイトルの取得でレシピサイトに送る要求は、レシピサイトがアプリに組み込んだ他社に当たらないため、含めない。

| 質問 | 回答案 |
| --- | --- |
| データを収集するか | はい |
| データの種類 | 使用状況データ（製品の操作・広告データ）、識別子（デバイス ID）、位置情報（おおよその位置情報）、診断（クラッシュデータ・パフォーマンスデータ・その他の診断データ） |
| ユーザーに関連付けるか | 製品の操作・広告データ・デバイス ID・おおよその位置情報は「はい」、診断の3種類は「いいえ」 |
| トラッキングに使うか | いいえ |
| 利用目的 | 下の表のとおり |

| データの種類 | Apple の定義 | このアプリで当たるもの | 利用目的 | 関連付け |
| --- | --- | --- | --- | --- |
| 製品の操作 | アプリの起動・タップ・スクロールなど、アプリの操作の情報 | Google Analytics に送る、画面の表示、登録・検索などの操作の種類と回数。広告の SDK が集める、アプリの起動・タップなどの操作 | アナリティクス、サードパーティ広告、デベロッパの広告やマーケティング、アプリの機能 | はい |
| 広告データ | ユーザーが見た広告の情報など | 広告の SDK が集める、表示した広告の情報。Google Analytics が自動で記録する、広告の表示などのイベント（[Google の説明](https://support.google.com/analytics/answer/9234069?hl=ja)） | サードパーティ広告、デベロッパの広告やマーケティング、アナリティクス | はい |
| デバイス ID | 端末の広告識別子など、端末単位の ID | Google Analytics がアプリのインストールごとに割り当てるアプリインスタンス ID（[Google の説明](https://support.google.com/analytics/answer/10285841?hl=ja)）と、広告の SDK が使う、アプリや開発者ごとの端末の識別子 | アナリティクス、サードパーティ広告、デベロッパの広告やマーケティング | はい |
| おおよその位置情報 | 緯度・経度の小数第3位より粗い位置 | Google Analytics と広告の SDK が IP アドレスから推定する地域。iOS の位置情報サービスは使わない | アナリティクス、サードパーティ広告、デベロッパの広告やマーケティング、アプリの機能 | はい |
| クラッシュデータ | クラッシュログなど | 広告の SDK が集める、利用者に結び付かないクラッシュの記録 | アナリティクス | いいえ |
| パフォーマンスデータ | 起動時間・ハング率・エネルギー使用量など | 広告の SDK が集める、アプリの起動時間など | サードパーティ広告、デベロッパの広告やマーケティング、アナリティクス、アプリの機能 | いいえ |
| その他の診断データ | アプリの技術的な診断のために集める、そのほかのデータ | Firebase Installations が集める、端末・OS・アプリの種類（ユーザーエージェント）（[Firebase の説明](https://firebase.google.com/docs/ios/app-store-data-collection)）と、広告の SDK が集める診断の情報 | アナリティクス、サードパーティ広告、デベロッパの広告やマーケティング | いいえ |

- 広告の SDK の分: Google Mobile Ads SDK 13.11.0 と User Messaging Platform SDK 3.1.0 のプライバシーマニフェスト（`PrivacyInfo.xcprivacy`）の申告と、Google の [App Store のデータ開示](https://developers.google.com/admob/ios/privacy/data-disclosure?hl=ja)に合わせた。利用目的と関連付けは、SDK ごとの申告を合わせ、どれかで当たるものを選んだ。User Messaging Platform SDK は、おおよその位置情報・パフォーマンスデータ・製品の操作を、関連付けない・アプリの機能の目的として申告している。
- デバイス ID: Apple・Google とも、アプリインスタンス ID をどの種類に当てはめるかを書いていない。利用者・アカウント単位の「ユーザー ID」ではなく、端末上のアプリを区別する ID のため、デバイス ID として申告する。
- その他の診断データ: Firebase Installations のプライバシーマニフェストが、関連付けない・トラッキングに使わない・アナリティクス目的として申告している。
- Google Analytics の SDK（GoogleAppMeasurement）にはプライバシーマニフェストが含まれないため、Google Analytics の分は Google の説明から当てはめた。この SDK は、Apple がプライバシーマニフェストを必須とする [SDK の一覧](https://developer.apple.com/support/third-party-SDK-requirements/)に含まれていない。
- ユーザーに関連付けるか: Apple は、直接の識別子を除いて集め、集めた後に本人や他のデータと結び付けなければ、関連付けないものとする。Google Analytics の分は、アプリがユーザー ID を設定せず、Google シグナルを無効にするため関連付けない。Google Mobile Ads SDK は、製品の操作・広告データ・デバイス ID・おおよその位置情報を「関連付ける」と申告しているため、この4種類は「はい」と答える。関係する法律で個人情報に当たるものは関連付けるものとされるが、仕様の[法的な整理](specifications/2-data.md#法的な整理)では、広告・解析の識別子を個人関連情報として扱う。
- トラッキングに使うか: Apple は、集めたデータを広告や広告の効果測定のために他社のアプリ・サイトのデータと結び付けることと、データブローカーに渡すことをトラッキングとする。Google Analytics の分は、広告識別子を使わない `FirebaseAnalyticsCore` を使い、他社のデータと結び付けず、データブローカーにも渡さない。広告の分は、ATT（App Tracking Transparency）で許可を求めないため、iOS 14.5 以降では広告識別子が0だけの値になる（[Apple の説明](https://developer.apple.com/documentation/adsupport/asidentifiermanager/advertisingidentifier)）。さらに、パーソナライズしない広告だけを求める（[Google の説明](https://developers.google.com/admob/ios/targeting?hl=ja)）。このため「いいえ」と答える案にする。ただし Google Mobile Ads SDK のプライバシーマニフェストは、デバイス ID を「トラッキングに使う」と申告している。提出する前に、Xcode の Organizer でアーカイブを Control キーを押しながらクリックし、「Generate Privacy Report」で SDK の申告をまとめた報告を作り（[Apple の説明](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests)）、この回答でよいかを確かめる。
- 問い合わせと不適切な広告の報告のメールは申告しない。アプリは `mailto:` でメールアプリを開くだけで、メールは利用者がメールアプリから送り、アプリからは何も送らないため、上の「収集」に当たらない。Apple の説明に `mailto:` の扱いは書かれていない。アプリが送る問い合わせフォームでも、任意で、主な機能と関係がなく、ほかの条件を満たすものは、申告しなくてよい例に挙げている。

## 年齢制限の質問に答えるための事実

| 内容 | このアプリ |
| --- | --- |
| 暴力・性的な表現・ギャンブルなど | ない |
| アプリの中で自由に Web を見る機能 | ない。レシピのページは Safari などの別のアプリで開く |
| 利用者が作った内容の公開・共有 | ない。保存した内容は本人の端末にだけあり、ほかの人には見えない |
| 広告 | あり。レシピの一覧の画面の下に、AdMob のバナー広告を1つ表示する。年齢制限の質問の「Advertising」に当たる。Apple の定義では、4+ の App にも広告は含まれ得る（[Apple の説明](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)）。表示する広告の内容の上限は、AdMob の「広告レーティングを管理」で選ぶ（[公開前の作業](release-checklist.md#広告を始めるときの作業)） |
| 端末の位置情報サービス・連絡先などの利用 | ない |

## コンテンツ配信権（回答案）

質問「あなたのアプリはサードパーティ製のコンテンツを含む、表示する、またはそれにアクセスしますか？」には「はい」と答える。対応サイトのページからタイトルを取得して表示し、保存したページへリンクするため、「いいえ」には当たらない。Apple は、そのようなアプリに、必要な権利を持っているか、配信する地域の法律で使用が認められていることを求めている。このアプリは仕様の[法的な整理](specifications/2-data.md#法的な整理)のとおり、日本の法律と各サイトの公開条件に基づいて扱い、各社の個別の許諾は得ていない。

## App Review へのメモ

審査の担当者が日本語を読めない場合に備えて、英語でも書く。

```text
ログインは不要です。
Safari でレシピのページを開き、共有ボタンから「レシピぽけっと」を選ぶと、保存の画面が開きます。アプリの右上の＋から URL を貼り付けて保存することもできます。
設定の「タイトルを取得する対応サイト」にあるサイトの公開レシピだけ、保存したあとにタイトルを自動で取得します。
利用状況の送信は、設定の「プライバシーと外部送信」にある「利用状況を送る」でオフにできます。
広告は、レシピの一覧の画面の下にだけ表示します。登録・編集の画面と共有の画面には表示しません。

No login is required.
To save a recipe, open a recipe page in Safari, tap the Share button, and choose "レシピぽけっと". You can also tap + at the top right of the app and paste a URL.
After saving, the app fetches the page title automatically only for public recipes on the sites listed in Settings > "タイトルを取得する対応サイト" (supported sites).
Usage analytics can be turned off with the "利用状況を送る" switch in Settings > "プライバシーと外部送信" (privacy).
Ads appear only at the bottom of the recipe list screen. They are not shown on the add/edit screen or in the share extension.
```

## スクリーンショット

必須の「Dynamic Island 搭載 iPhone（中サイズのディスプレイ）」に入れる 1206 × 2622 の画像（[スクリーンショットの仕様](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)）。iPhone 17 のシミュレータで撮った。

| ファイル | 画面 |
| --- | --- |
| [1-list.png](app-store/screenshots/1-list.png) | 一覧 |
| [2-search.png](app-store/screenshots/2-search.png) | タグで絞り込んだ一覧 |
| [3-edit.png](app-store/screenshots/3-edit.png) | 登録・編集 |

撮り直すときは、記録を空にして、Debug ビルドに起動引数 `-SeedScreenshotRecipes` を付けて起動する。実在しない見本のサイト（example.com など）の記録が入り、テスト用の広告は表示しない。
