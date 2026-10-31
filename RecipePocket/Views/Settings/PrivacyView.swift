import SwiftUI

/// 外部送信の公表と、利用状況の送信の設定
struct PrivacyView: View {
    @State private var analyticsEnabled = AppAnalytics.shared.isEnabled

    var body: some View {
        List {
            Section {
                Text("保存したレシピのURL・タイトル・タグは、この端末の中だけに保存します。運営者のサーバーには送りません。")
            }

            Section("外部に送る情報") {
                Destination(
                    name: "各レシピサイト",
                    information: "対応サイトのレシピを登録したときにタイトルを取得するための、ページのURLと、通信に必要なIPアドレスなど。レシピのページを開くときは、ブラウザなどのアプリがそのサイトと通信します。",
                    purpose: "タイトルの取得と、ページの表示。登録したタイトルやタグは送りません。"
                )
                Destination(
                    name: "Google LLC（Google Analytics for Firebase）",
                    information: "画面の表示、レシピの登録・編集・削除・並べ替え、検索条件の追加などの操作の種類と回数、アプリ・端末の情報（アプリの版、OSの版、機種など）、解析用のアプリの識別子、IPアドレスから推定する地域など。",
                    purpose: "利用状況を把握し、アプリを改善するため。広告には使いません。"
                )
                Link("Google によるデータの使用について", destination: URL(string: "https://policies.google.com/technologies/partner-sites?hl=ja")!)
                Link("Google Analytics が収集する情報", destination: URL(string: "https://support.google.com/analytics/answer/10285841?hl=ja")!)
                Destination(
                    name: "運営者（問い合わせ）",
                    information: "メールで送られた相談の内容と、返信先のメールアドレス。レシピの情報は自動で添付しません。",
                    purpose: "問い合わせへの対応。対応に必要な間だけ保管し、不要になれば削除します。"
                )
            }

            Section("送らない情報") {
                Text("保存したURL・タイトル・タグ、検索語、記録の識別番号、レシピサイトの閲覧履歴は、解析に送りません。検索の履歴は保存しません。")
                Text("広告識別子（IDFA）は使わず、他社のアプリやサイトをまたいだ追跡もしません。")
            }

            Section {
                Toggle("利用状況を送る", isOn: $analyticsEnabled)
                    .onChange(of: analyticsEnabled) { _, enabled in
                        AppAnalytics.shared.isEnabled = enabled
                    }
            } header: {
                Text("利用状況の送信")
            } footer: {
                Text("オフにすると、この端末から Google Analytics へ情報を送りません。")
            }

            Section("運営者") {
                LabeledContent("運営者", value: AppInfo.operatorName ?? "未設定")
                LabeledContent("問い合わせ先", value: AppInfo.contactEmail ?? "未設定")
            }
        }
        .navigationTitle("プライバシーと外部送信")
        .analyticsScreen(.privacy)
    }
}

private struct Destination: View {
    let name: String
    let information: String
    let purpose: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.headline)
            Text("送る情報：\(information)")
            Text("目的：\(purpose)")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
