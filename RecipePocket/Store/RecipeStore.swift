import Foundation
import Observation
import RecipeCore
import RecipeData
import RecipeUI
import UIKit

/// 一覧とごみ箱の記録と、記録を変える操作。操作の結果は画面下部の案内で伝え、読み込んだ一覧は検索に渡す
@MainActor
@Observable
final class RecipeStore {
    private(set) var recipes: [Recipe] = []
    private(set) var trash: [TrashedRecipe] = []
    private(set) var savedTags: [String] = []
    private(set) var loadFailed = false

    /// 検索の条件と、その条件で絞り込んだ一覧
    @ObservationIgnored let search: SearchStore
    /// 画面下部の案内
    @ObservationIgnored let toasts: ToastCenter
    @ObservationIgnored private let repository: RecipeRepository
    @ObservationIgnored private let titleFetchRepository: TitleFetchRepository
    @ObservationIgnored private let analytics: AppAnalytics
    @ObservationIgnored private lazy var titleFetch = TitleFetchCoordinator(repository: titleFetchRepository) { [weak self] in
        self?.reload()
    }

    init(repository: RecipeRepository, titleFetchRepository: TitleFetchRepository, analytics: AppAnalytics) {
        self.repository = repository
        self.titleFetchRepository = titleFetchRepository
        self.analytics = analytics
        toasts = ToastCenter()
        search = SearchStore(analytics: analytics, toasts: toasts)
        try? titleFetchRepository.resetInterrupted()
    }

    // MARK: - 読み込み

    /// 起動時と前面に戻ったとき。共有拡張で保存した記録を読み込み、期限切れのごみ箱を消し、タイトルを取得する
    func refresh() {
        _ = try? repository.purgeExpiredTrash()
        reload()
        titleFetch.start()
    }

    func reload() {
        do {
            recipes = try repository.recipes()
            trash = try repository.trashedRecipes()
            loadFailed = false
        } catch {
            loadFailed = true
        }
        savedTags = TagRules.savedTags(in: recipes.map(\.tags))
        search.update(recipes)
    }

    // MARK: - 登録・編集

    func add(_ output: RecipeFormOutput) -> RecipeSaveResult {
        save(event: .recipeAdded(tagCount: output.tags.count)) {
            try repository.add(url: output.url, title: output.title, tags: output.tags)
        }
    }

    func update(_ recipe: Recipe, with output: RecipeFormOutput) -> RecipeSaveResult {
        save(event: .recipeUpdated) {
            try repository.update(id: recipe.id, url: output.url, title: output.title, tags: output.tags)
        }
    }

    private func save(event: AnalyticsEvent, _ operation: () throws -> Recipe) -> RecipeSaveResult {
        let result = RecipeSaveResult(operation)
        if case .saved = result {
            analytics.log(event)
            reload()
            toasts.show("保存しました")
            titleFetch.start()
        }
        return result
    }

    func copyURL(of recipe: Recipe) {
        UIPasteboard.general.string = recipe.url
        analytics.log(.urlCopied)
        toasts.show("URLをコピーしました")
    }

    // MARK: - 並べ替え

    /// 表示中の一覧（検索結果を含む）での移動を、全体の並び順に反映する
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var list = search.results
        guard let first = source.first, list.indices.contains(first) else { return }
        let moved = list[first]
        list.move(fromOffsets: source, toOffset: destination)
        guard let index = list.firstIndex(of: moved) else { return }
        let above = index > 0 ? list[index - 1].id : nil
        let below = index < list.count - 1 ? list[index + 1].id : nil
        do {
            try repository.move(id: moved.id, above: above, below: below)
            analytics.log(.recipeMoved)
        } catch {
            toasts.show("並べ替えを保存できませんでした")
        }
        reload()
    }

    func canMoveUp(_ recipe: Recipe) -> Bool { search.results.first?.id != recipe.id }
    func canMoveDown(_ recipe: Recipe) -> Bool { search.results.last?.id != recipe.id }

    func moveUp(_ recipe: Recipe) {
        guard let index = search.results.firstIndex(of: recipe), index > 0 else { return }
        move(fromOffsets: [index], toOffset: index - 1)
    }

    func moveDown(_ recipe: Recipe) {
        guard let index = search.results.firstIndex(of: recipe), index < search.results.count - 1 else { return }
        move(fromOffsets: [index], toOffset: index + 2)
    }

    // MARK: - 削除・ごみ箱

    func delete(_ recipe: Recipe) {
        do {
            try repository.moveToTrash(id: recipe.id)
            analytics.log(.recipeDeleted)
            reload()
            toasts.show("ごみ箱に移動しました", actionTitle: "元に戻す") { [weak self] in
                guard let self, let trashed = trash.first(where: { $0.id == recipe.id }) else { return }
                _ = restore(trashed)
            }
        } catch {
            toasts.show("削除できませんでした")
        }
    }

    func restore(_ trashed: TrashedRecipe) -> RecipeRestoreResult {
        let result = RecipeRestoreResult { try repository.restore(id: trashed.id) }
        if case .restored = result {
            analytics.log(.recipeRestored)
            reload()
            toasts.show("一覧に戻しました")
        }
        return result
    }

    func deletePermanently(_ trashed: TrashedRecipe) {
        do {
            try repository.deletePermanently(id: trashed.id)
            analytics.log(.recipeDeletedPermanently)
            reload()
        } catch {
            toasts.show("削除できませんでした")
        }
    }

    func emptyTrash() {
        do {
            let count = try repository.emptyTrash()
            analytics.log(.trashEmptied(count: count))
            reload()
            toasts.show("\(count.formatted())件を完全に削除しました")
        } catch {
            toasts.show("削除できませんでした")
        }
    }
}
