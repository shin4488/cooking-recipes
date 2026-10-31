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
                Section("このアプリについて") {
                    NavigationLink("プライバシーと外部送信") { PrivacyView() }
                    NavigationLink("利用条件") { TermsView() }
                    contactRow
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
        .analyticsScreen(.settings)
    }

    @ViewBuilder
    private var contactRow: some View {
        if let url = AppInfo.contactMailURL(subject: "レシピぽけっとへのお問い合わせ") {
            Button("問い合わせ（メール）") {
                openURL(url) { accepted in
                    if !accepted { showsMailUnavailable = true }
                }
            }
        } else {
            LabeledContent("問い合わせ", value: "未設定")
        }
    }
}
