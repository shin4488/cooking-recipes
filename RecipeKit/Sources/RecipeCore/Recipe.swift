import Foundation

/// タイトルをどこから得たか。手入力のタイトルを自動処理で上書きしないために保存する
public enum TitleSource: String, Codable, Sendable {
    case manual
    case shared
    case fetched
    case none
}

/// 対応サイトからのタイトル取得の状態
public enum TitleFetchState: String, Codable, Sendable {
    case notFetched
    case fetching
    case fetched
    case unsupported
    case failed
}

public struct Recipe: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var url: String
    public var title: String?
    public var titleSource: TitleSource
    public var titleFetchState: TitleFetchState
    public var tags: [String]
    public var sortKey: Double
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        url: String,
        title: String?,
        titleSource: TitleSource,
        titleFetchState: TitleFetchState,
        tags: [String],
        sortKey: Double,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.titleSource = titleSource
        self.titleFetchState = titleFetchState
        self.tags = tags
        self.sortKey = sortKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var host: String? { RecipeURL.host(of: url) }

    public var displayTitle: String { TitleRules.displayTitle(title, host: host) }

    /// 一覧でホスト名の代わりに示す名前。対応サイトはサイト名を併記する
    public var siteLabel: String? { SupportedSite.site(forHost: host)?.name ?? host }

    /// 本体がこの記録のタイトルを自動取得するか
    public var needsTitleFetch: Bool { titleSource == .none && titleFetchState == .notFetched }
}

public struct TrashedRecipe: Identifiable, Hashable, Sendable {
    public var recipe: Recipe
    public var deletedAt: Date

    public init(recipe: Recipe, deletedAt: Date) {
        self.recipe = recipe
        self.deletedAt = deletedAt
    }

    public var id: UUID { recipe.id }
}
