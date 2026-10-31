import Foundation

/// 共有で受け取ったURLとタイトル候補
public struct SharedContent: Equatable, Sendable {
    /// 受け取った順に並べ、同じURLは1つにまとめる
    public var urls: [String]
    public var title: String?

    public init(urls: [String], title: String?) {
        self.urls = urls
        self.title = title
    }

    /// - Parameters:
    ///   - urls: URLとして受け取った項目
    ///   - texts: 文字列として受け取った項目。含まれるURLも取り出す
    ///   - titles: 共有元がタイトルとして渡した文字列（件名・本文の候補）
    public static func make(urls: [URL], texts: [String], titles: [String]) -> SharedContent {
        var seen = Set<String>()
        var found: [String] = []
        let candidates = urls.map(\.absoluteString) + texts.flatMap(webURLs(in:))
        for url in candidates where isWebURL(url) && seen.insert(RecipeURL.duplicateKey(for: url)).inserted {
            found.append(url)
        }
        // 共有文全体をタイトルにしないよう、URLや改行を含む文字列は使わない
        let title = (titles + texts).lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.contains(where: \.isNewline) && webURLs(in: $0).isEmpty }
            .compactMap(TitleRules.acceptReceived)
            .first
        // 対応サイトのページなら、取得したタイトルと同じく末尾のサイト名を除く
        let site = found.first.flatMap { SupportedSite.site(forHost: RecipeURL.host(of: $0)) }
        return SharedContent(urls: found, title: title.map { site?.removingSiteName(from: $0) ?? $0 })
    }

    /// 文中の http・https のURLを順に返す
    public static func webURLs(in text: String) -> [String] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let value = String(text[range])
            return isWebURL(value) ? value : nil
        }
    }

    private static func isWebURL(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.hasPrefix("https://") || lowered.hasPrefix("http://")
    }
}
