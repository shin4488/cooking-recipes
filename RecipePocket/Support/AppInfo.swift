import Foundation
import UIKit

/// 公開前に Config/Local.xcconfig で設定する運営者の情報と、アプリの版
enum AppInfo {
    static var operatorName: String? { infoValue("RPOperatorName") }
    static var contactEmail: String? { infoValue("RPContactEmail") }

    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(short)（\(build)）"
    }

    /// 問い合わせメールを作る。レシピの情報は添付しない
    @MainActor
    static func contactMailURL(subject: String) -> URL? {
        guard let contactEmail else { return nil }
        let body = """


        ----
        アプリ: レシピぽけっと \(version)
        iOS: \(UIDevice.current.systemVersion)
        """
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
