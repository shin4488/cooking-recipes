import Foundation

/// 登録・編集画面で決まったタイトル
public enum TitleInput: Equatable, Sendable {
    /// 編集で触れていない
    case unchanged
    /// 本人が入力した。nil は本人が空欄にした
    case manual(String?)
    /// 共有元から受け取り、本人が変えていない
    case shared(String)
    /// タイトルなし
    case none
}

/// 入力内容を記録に反映する規則
public enum RecipeEditing {
    public static func newRecipe(
        id: UUID = UUID(),
        url: String,
        title: TitleInput,
        tags: [String],
        sortKey: Double,
        now: Date
    ) -> Recipe {
        let (value, source) = resolve(title, current: nil)
        return Recipe(
            id: id,
            url: url,
            title: value,
            titleSource: source,
            titleFetchState: initialFetchState(url: url),
            tags: tags,
            sortKey: sortKey,
            createdAt: now,
            updatedAt: now
        )
    }

    /// URLを変えたときは、旧URLの共有・取得タイトルを消し、本人のタイトルとタグは残す
    public static func updated(_ recipe: Recipe, url: String, title: TitleInput, tags: [String], now: Date) -> Recipe {
        var result = recipe
        let urlChanged = recipe.url != url
        (result.title, result.titleSource) = resolve(title, current: recipe)
        if urlChanged, title == .unchanged, recipe.titleSource == .shared || recipe.titleSource == .fetched {
            result.title = nil
            result.titleSource = .none
        }
        if urlChanged || result.titleSource != recipe.titleSource {
            result.titleFetchState = initialFetchState(url: url)
        }
        result.url = url
        result.tags = tags
        result.updatedAt = now
        return result
    }

    /// 取得の結果を反映する。取得中にURLやタイトルが変わった記録には反映しない
    public static func applying(_ outcome: TitleFetchOutcome, to recipe: Recipe, fetchedURL: String, now: Date) -> Recipe? {
        guard recipe.url == fetchedURL, recipe.titleSource == .none, recipe.titleFetchState == .fetching else { return nil }
        var result = recipe
        switch outcome {
        case .fetched(let title):
            result.title = title
            result.titleSource = .fetched
            result.titleFetchState = .fetched
        case .unsupported:
            result.titleFetchState = .unsupported
        case .notFound, .refused, .failed:
            result.titleFetchState = .failed
        }
        result.updatedAt = now
        return result
    }

    static func initialFetchState(url: String) -> TitleFetchState {
        SupportedSite.fetchableSite(for: url) == nil ? .unsupported : .notFetched
    }

    private static func resolve(_ title: TitleInput, current: Recipe?) -> (String?, TitleSource) {
        switch title {
        case .unchanged: (current?.title, current?.titleSource ?? .none)
        case .manual(let value): (value, .manual)
        case .shared(let value): (value, .shared)
        case .none: (nil, .none)
        }
    }
}
