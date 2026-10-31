import Foundation

/// 利用条件とプライバシー説明の文面。アプリの設定画面と、web/ で作る Web ページの両方で使い、同じ文面を保つ
enum PolicyText {
    struct Section {
        var title: String?
        var paragraphs: [String] = []
        var destinations: [Destination] = []
    }

    /// 外部に情報を送る先
    struct Destination {
        var name: String
        var information: String
        var purpose: String
        var links: [Link] = []
    }

    struct Link {
        var title: String
        var url: URL
    }

    /// 運営者名と問い合わせ先。アプリでは Info.plist から、Web ページでは Config/Local.xcconfig から渡す
    struct Operator {
        var name: String
        var contactEmail: String
    }

    static let appName = "レシピぽけっと"
    static let termsTitle = "利用条件"
    static let privacyTitle = "プライバシーと外部送信"

    static let summary = "レシピぽけっとは、気になったレシピのURLをタイトル・タグとともに端末内に保存し、あとから探して元のサイトを開くためのアプリです。会員登録は不要で、無料で利用できます。"

    static func terms(operator: Operator) -> [Section] {
        [
            Section(title: "このアプリについて", paragraphs: [summary]),
            Section(title: "保存するデータ", paragraphs: ["保存したレシピは、この端末の中だけに保存します。アプリには移行・バックアップの機能はありません。アプリの削除、端末の紛失・故障などで失われたデータは、運営者が復旧できません。iOS標準のバックアップ・移行で引き継げるかは、利用者の設定や状況によります。"]),
            Section(title: "レシピサイトの利用", paragraphs: ["保存したページの閲覧・利用は、各サイトの利用条件に従ってください。本アプリは各サイトの運営会社と提携していません。タイトルの自動取得は、対応サイトの公開レシピについて、利用者が登録したときに限り行います。"]),
            Section(title: "禁止事項", paragraphs: ["法令や公序良俗に反する利用、他者の権利を侵害する利用、本アプリの運営を妨げる行為を禁止します。"]),
            Section(title: "免責", paragraphs: ["本アプリは現状のまま提供します。保存したデータの消失、各サイトの内容の変更・削除、本アプリの利用により生じた損害について、運営者に故意または重大な過失がある場合を除き、責任を負いません。"]),
            Section(title: "利用条件の変更", paragraphs: ["運営者は、必要に応じてこの利用条件を変更することがあります。重要な変更は、アプリの更新時や Web ページでお知らせします。"]),
            Section(title: "運営者・問い合わせ", paragraphs: ["運営者：\(`operator`.name)", "問い合わせ先：\(`operator`.contactEmail)"]),
        ]
    }

    /// プライバシー説明の本文。利用状況の送信の切り替えと運営者の表示は、画面ごとに置く
    static let privacy: [Section] = [
        Section(paragraphs: ["保存したレシピのURL・タイトル・タグは、この端末の中だけに保存します。運営者のサーバーには送りません。"]),
        Section(title: "外部に送る情報", destinations: [
            Destination(
                name: "各レシピサイト",
                information: "対応サイトのレシピを登録したときにタイトルを取得するための、ページのURLと、通信に必要なIPアドレスなど。レシピのページを開くときは、ブラウザなどのアプリがそのサイトと通信します。",
                purpose: "タイトルの取得と、ページの表示。登録したタイトルやタグは送りません。"
            ),
            Destination(
                name: "Google LLC（Google Analytics for Firebase）",
                information: "画面の表示、レシピの登録・編集・削除・並べ替え、検索条件の追加（タグからか入力からか）などの操作の種類と回数、登録時に付けたタグの数、ごみ箱を空にした件数、アプリ・端末の情報（アプリの版、OSの版、機種など）、解析用のアプリの識別子、IPアドレスから推定する地域など。",
                purpose: "利用状況を把握し、アプリを改善するため。広告には使いません。",
                links: [
                    Link(title: "Google によるデータの使用について", url: URL(string: "https://policies.google.com/technologies/partner-sites?hl=ja")!),
                    Link(title: "Google Analytics が収集する情報", url: URL(string: "https://support.google.com/analytics/answer/10285841?hl=ja")!),
                ]
            ),
            Destination(
                name: "運営者（問い合わせ）",
                information: "メールで送られた相談の内容と、返信先のメールアドレス。レシピの情報は自動で添付しません。",
                purpose: "問い合わせへの対応。対応に必要な間だけ保管し、不要になれば削除します。"
            ),
        ]),
        Section(title: "送らない情報", paragraphs: [
            "保存したURL・タイトル・タグ、検索語、記録の識別番号、レシピサイトの閲覧履歴は、解析に送りません。検索の履歴は保存しません。",
            "広告識別子（IDFA）は使わず、他社のアプリやサイトをまたいだ追跡もしません。",
        ]),
        Section(title: "保存期間と削除", paragraphs: [
            "保存したレシピは、アプリの中でいつでも削除できます。削除したレシピは30日間ごみ箱に残り、その後に完全に削除します。",
            "Google Analytics に送った情報のうち、利用者ごと・操作ごとの記録は、2か月を過ぎると Google のサーバーから自動で削除されます。日ごとの利用者数などの集計した数値は残ります。",
            "利用状況の送信は、アプリの「設定」の「プライバシーと外部送信」にある「利用状況を送る」で、いつでも止められます。",
            "問い合わせの内容の削除を求める場合は、問い合わせ先へ連絡してください。",
        ]),
    ]
}
