import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showsMailUnavailable = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("タイトルを取得する対応サイト") { SupportedSitesView() }
                    NavigationLink {
                        TrashView()
                    } label: {
                        LabeledContent("ごみ箱", value: "\(store.trash.count.formatted())件")
                    }
                }
                Section("広告") {
                    // 同意が必要な地域で、UMP が変更の入口を求めているときだけ出す
                    if AppAds.shared.requiresPrivacyOptions {
                        Button("広告の同意の設定") { AppAds.shared.presentPrivacyOptions() }
                    }
                    mailRow(
                        "不適切な広告を報告",
                        subject: "レシピぽけっと：不適切な広告の報告",
                        guide: "表示された広告の内容（広告主・商品など）と、表示された日時を書いてください。広告の画面のスクリーンショットがあれば添付してください。"
                    )
                }
                Section("このアプリについて") {
                    NavigationLink("プライバシーと外部送信") { PrivacyView() }
                    NavigationLink("利用条件") { TermsView() }
                    mailRow("問い合わせ", subject: "レシピぽけっとへのお問い合わせ")
                    NavigationLink("ライセンス") { LicensesView() }
                    LabeledContent("バージョン", value: AppInfo.version)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert("メールを作成できませんでした", isPresented: $showsMailUnavailable) {
                if let email = AppInfo.contactEmail {
                    Button("アドレスをコピー") { UIPasteboard.general.string = email }
                }
                Button("閉じる", role: .cancel) {}
            } message: {
                Text("メールアプリを設定するか、次のアドレスへ送ってください。\n\(AppInfo.contactEmail ?? "")")
            }
        }
        .overlay(alignment: .bottom) {
            ToastView()
        }
        .analyticsScreen(.settings)
    }

    /// 問い合わせ先へのメールを作る行。問い合わせ先を入れていないビルドでは「未設定」と表示する
    @ViewBuilder
    private func mailRow(_ title: String, subject: String, guide: String? = nil) -> some View {
        if let url = AppInfo.contactMailURL(subject: subject, guide: guide) {
            Button("\(title)（メール）") {
                openURL(url) { accepted in
                    if !accepted { showsMailUnavailable = true }
                }
            }
        } else {
            LabeledContent(title, value: "未設定")
        }
    }
}
