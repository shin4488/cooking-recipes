import Foundation
import RecipeCore
import SwiftData

/// 一覧の記録とごみ箱の記録に共通する項目。値との変換を1か所にするために使う
protocol RecipeFields: AnyObject {
    var id: UUID { get }
    var url: String { get set }
    var title: String? { get set }
    var titleSourceValue: String { get set }
    var titleFetchStateValue: String { get set }
    var tags: [String] { get set }
    var sortKey: Double { get set }
    var createdAt: Date { get }
    var updatedAt: Date { get set }
}

extension RecipeFields {
    /// 保存された値が読めない種類なら、タイトルの入力方法は未設定、取得の状態は未取得として読む
    var recipe: Recipe {
        Recipe(
            id: id,
            url: url,
            title: title,
            titleSource: TitleSource(rawValue: titleSourceValue) ?? .none,
            titleFetchState: TitleFetchState(rawValue: titleFetchStateValue) ?? .notFetched,
            tags: tags,
            sortKey: sortKey,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// IDと登録日時のほかの項目を書き込む
    func apply(_ recipe: Recipe) {
        url = recipe.url
        title = recipe.title
        titleSourceValue = recipe.titleSource.rawValue
        titleFetchStateValue = recipe.titleFetchState.rawValue
        tags = recipe.tags
        sortKey = recipe.sortKey
        updatedAt = recipe.updatedAt
    }
}

extension RecipeRecord: RecipeFields {
    /// 一覧の並び順。並び順の値の小さい順、同じ値なら新しい順
    static var listOrder: [SortDescriptor<RecipeRecord>] {
        [SortDescriptor(\.sortKey), SortDescriptor(\.createdAt, order: .reverse)]
    }

    convenience init(_ recipe: Recipe) {
        self.init(
            id: recipe.id,
            url: recipe.url,
            title: recipe.title,
            titleSourceValue: recipe.titleSource.rawValue,
            titleFetchStateValue: recipe.titleFetchState.rawValue,
            tags: recipe.tags,
            sortKey: recipe.sortKey,
            createdAt: recipe.createdAt,
            updatedAt: recipe.updatedAt
        )
    }
}

extension TrashedRecipeRecord: RecipeFields {
    /// ごみ箱の並び順。削除が新しい順
    static var trashOrder: [SortDescriptor<TrashedRecipeRecord>] {
        [SortDescriptor(\.deletedAt, order: .reverse)]
    }

    var trashedRecipe: TrashedRecipe {
        TrashedRecipe(recipe: recipe, deletedAt: deletedAt)
    }

    convenience init(_ trashed: TrashedRecipe) {
        let recipe = trashed.recipe
        self.init(
            id: recipe.id,
            url: recipe.url,
            title: recipe.title,
            titleSourceValue: recipe.titleSource.rawValue,
            titleFetchStateValue: recipe.titleFetchState.rawValue,
            tags: recipe.tags,
            sortKey: recipe.sortKey,
            createdAt: recipe.createdAt,
            updatedAt: recipe.updatedAt,
            deletedAt: trashed.deletedAt
        )
    }
}

extension ModelContainer {
    /// 操作ごとに使う新しいコンテキスト。本体と共有拡張が同時に保存するため、操作ごとに最新の内容を読み、1回の保存で反映する
    func makeContext() -> ModelContext {
        let context = ModelContext(self)
        context.autosaveEnabled = false
        return context
    }
}

extension ModelContext {
    func recipeRecord(_ id: UUID) throws -> RecipeRecord? {
        try fetch(FetchDescriptor<RecipeRecord>(predicate: #Predicate { $0.id == id })).first
    }
}
