import Foundation
import UIKit

/// 公開前に Config/Local.xcconfig で設定する運営者の情報・広告の ID と、アプリの版
enum AppInfo {
    static var operatorName: String? { infoValue("RPOperatorName") }
    static var contactEmail: String? { infoValue("RPContactEmail") }
    /// AdMob のアプリ ID と、一覧のバナーの広告ユニット ID。Debug ビルドで値を入れていなければ、Google のテスト用の ID になる
    static var adMobAppID: String? { infoValue("GADApplicationIdentifier") }
    static var adMobBannerUnitID: String? { infoValue("RPAdMobBannerUnitID") }

    /// 利用条件・プライバシー説明に載せる運営者。公開前の値を入れていないビルドでは「未設定」と表示する
    static var policyOperator: PolicyText.Operator {
        PolicyText.Operator(name: operatorName ?? "未設定", contactEmail: contactEmail ?? "未設定")
    }

    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(short)（\(build)）"
    }

    /// 問い合わせメールを作る。レシピの情報は添付しない。`guide` は、書いてほしい内容の案内で、本文の先頭に入れる
    @MainActor
    static func contactMailURL(subject: String, guide: String? = nil) -> URL? {
        guard let contactEmail else { return nil }
        let footer = """
        ----
        アプリ: レシピぽけっと \(version)
        iOS: \(UIDevice.current.systemVersion)
        """
        let body = (guide.map { "\($0)\n" } ?? "") + "\n\n" + footer
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = contactEmail
        components.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        return components.url
    }

    private static func infoValue(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.trimmingCharacters(in: .whitespaces).isEmpty
        else { return nil }
        return value
    }
}
