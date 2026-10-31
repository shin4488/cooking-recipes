import Foundation

/// アプリからタイトルを取得する対応サイト。公開規約と自動アクセスの制限を確認して選んだ
public struct SupportedSite: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let host: String
    /// タイトルを取得するパス。この範囲の公開レシピだけを対象にする
    public let pathPrefixes: [String]
    /// ページのタイトルの末尾に区切りを挟んで付くサイト名。末尾から順に並べる
    public let titleSuffixes: [String]

    public static let all = [
        SupportedSite(id: "kewpie", name: "キユーピー", host: "www.kewpie.co.jp", pathPrefixes: ["/recipes/"], titleSuffixes: ["キユーピー", "とっておきレシピ"]),
        SupportedSite(id: "mizkan", name: "ミツカン", host: "www.mizkan.co.jp", pathPrefixes: ["/ouchirecipe/recipe/"], titleSuffixes: ["ミツカングループ", "おうちレシピ"]),
        SupportedSite(id: "sirogohan", name: "白ごはん.com", host: "www.sirogohan.com", pathPrefixes: ["/recipe/", "/sp/recipe/"], titleSuffixes: ["白ごはん.com"]),
    ]

    /// タイトルとサイト名を区切る記号
    private static let titleSeparators: Set<Character> = ["|", "｜", ":", "："]

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

    /// 末尾のサイト名を除いたタイトル（例: 「肉じゃがの作り方：白ごはん.com」→「肉じゃがの作り方」）。
    /// 一覧ではサイト名をタイトルとは別に表示するため。区切りがない場合とサイト名しかない場合はそのまま返す
    public func removingSiteName(from title: String) -> String {
        var result = Substring(title)
        while let rest = titleSuffixes.lazy.compactMap({ Self.dropping($0, from: result) }).first {
            result = rest
        }
        return String(result)
    }

    /// 末尾が「区切り＋サイト名」なら、それより前の部分を返す
    private static func dropping(_ siteName: String, from title: Substring) -> Substring? {
        let text = trimmingTrailingWhitespace(title)
        guard text.hasSuffix(siteName) else { return nil }
        let beforeName = trimmingTrailingWhitespace(text.dropLast(siteName.count))
        guard let separator = beforeName.last, titleSeparators.contains(separator) else { return nil }
        let rest = trimmingTrailingWhitespace(beforeName.dropLast())
        return rest.isEmpty ? nil : rest
    }

    private static func trimmingTrailingWhitespace(_ text: Substring) -> Substring {
        var result = text
        while result.last?.isWhitespace == true { result.removeLast() }
        return result
    }
}
