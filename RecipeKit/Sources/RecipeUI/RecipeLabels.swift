import RecipeCore

/// 記録を画面に出すときの表記。本体の一覧・ごみ箱・確認と、共有拡張の確認で使う
extension Recipe {
    /// タイトルが未設定のときの表記
    public static let untitledLabel = "タイトル未設定"

    /// 画面に出すタイトル。未設定でもホスト名は加えない。どのサイトかはタイトルとは別に表示する
    public var displayTitle: String {
        if let title, !title.isEmpty { return title }
        return Self.untitledLabel
    }

    /// 一覧でホスト名の代わりに示す名前。対応サイトはサイト名を併記する
    public var siteLabel: String? { SupportedSite.site(forHost: host)?.name ?? host }
}
