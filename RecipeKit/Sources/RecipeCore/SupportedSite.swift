import Foundation

/// アプリからタイトルを取得する対応サイト。公開規約と自動アクセスの制限を確認して選んだ
public struct SupportedSite: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let host: String
    /// タイトルを取得するパス。この範囲の公開レシピだけを対象にする
    public let pathPrefixes: [String]

    public static let all = [
        SupportedSite(id: "kewpie", name: "キユーピー", host: "www.kewpie.co.jp", pathPrefixes: ["/recipes/"]),
        SupportedSite(id: "mizkan", name: "ミツカン", host: "www.mizkan.co.jp", pathPrefixes: ["/ouchirecipe/recipe/"]),
        SupportedSite(id: "sirogohan", name: "白ごはん.com", host: "www.sirogohan.com", pathPrefixes: ["/recipe/", "/sp/recipe/"]),
    ]

    /// タイトルを取得できるURLならそのサイトを返す。HTTPSの既定ポートで、対象のパスに限る
    public static func fetchableSite(for url: String) -> SupportedSite? {
        guard let parts = RecipeURL.parse(url.trimmingCharacters(in: .whitespacesAndNewlines)),
              parts.scheme.lowercased() == "https",
              parts.port == nil || parts.port == "443",
              let site = site(forHost: parts.host.lowercased())
        else { return nil }
        let path = parts.path
        return site.pathPrefixes.contains(where: path.hasPrefix) ? site : nil
    }

    public static func site(forHost host: String?) -> SupportedSite? {
        guard let host else { return nil }
        return all.first { $0.host == host }
    }

    /// 対象範囲を示すURLの表記（例: www.sirogohan.com/recipe/）
    public var coveredLocations: [String] {
        pathPrefixes.map { host + $0 }
    }
}
