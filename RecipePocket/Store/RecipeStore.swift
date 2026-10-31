import Foundation
import Observation
import RecipeCore
import RecipeData
import RecipeUI
import UIKit

/// 画面下部に一時的に出す案内。操作を1つ付けられる
struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    var actionTitle: String?
    var action: (@MainActor () -> Void)?

    static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
}

enum SaveResult {
    case saved(Recipe)
    case duplicate(RecipeDuplicate)
    case failed
}

enum RestoreResult {
    case restored(Recipe)
    case duplicate(Recipe)
    case failed
}

/// 一覧・検索・ごみ箱の状態と操作
@MainActor
@Observable
final class RecipeStore {
    private(set) var recipes: [Recipe] = []
    private(set) var results: [Recipe] = []
    private(set) var trash: [TrashedRecipe] = []
    private(set) var savedTags: [String] = []
    private(set) var loadFailed = false
    var search = SearchState() {
        didSet { if search != oldValue { updateResults() } }
    }
    var toast: Toast?
    /// 一覧で表示位置を合わせて目立たせる記録
    var focusedRecipeID: UUID?

    @ObservationIgnored private let repository: RecipeRepository
    @ObservationIgnored private let analytics: AppAnalytics
    @ObservationIgnored private lazy var titleFetch = TitleFetchCoordinator(repository: repository) { [weak self] in
        self?.reload()
    }
    /// 検索用に表記ゆれをそろえた値。更新日時が変わった記録だけ作り直す
    @ObservationIgnored private var searchTargets: [UUID: (updatedAt: Date, target: SearchTarget)] = [:]

    init(repository: RecipeRepository, analytics: AppAnalytics) {
        self.repository = repository
        self.analytics = analytics
        try? repository.resetInterruptedTitleFetches()
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
        var seen = Set<String>()
        savedTags = recipes.flatMap(\.tags).filter { seen.insert($0).inserted }
        updateResults()
    }

    // MARK: - 登録・編集

    func add(_ output: RecipeFormOutput) -> SaveResult {
        save(event: .recipeAdded(tagCount: output.tags.count)) {
            try repository.add(url: output.url, title: output.title, tags: output.tags)
        }
    }

    func update(_ recipe: Recipe, with output: RecipeFormOutput) -> SaveResult {
        save(event: .recipeUpdated) {
            try repository.update(id: recipe.id, url: output.url, title: output.title, tags: output.tags)
        }
    }

    private func save(event: AnalyticsEvent, _ operation: () throws -> Recipe) -> SaveResult {
        do {
            let recipe = try operation()
            analytics.log(event)
            reload()
            showToast("保存しました")
            titleFetch.start()
            return .saved(recipe)
        } catch RecipeRepositoryError.duplicate(let duplicate) {
            return .duplicate(duplicate)
        } catch {
            return .failed
        }
    }

    func copyURL(of recipe: Recipe) {
        UIPasteboard.general.string = recipe.url
        analytics.log(.urlCopied)
        showToast("URLをコピーしました")
    }

    /// 一覧で見つけやすいよう、検索条件を外して表示位置を合わせる
    func focus(on recipe: Recipe) {
        if !results.contains(where: { $0.id == recipe.id }) { search.removeAll() }
        focusedRecipeID = recipe.id
    }

    // MARK: - 並べ替え

    /// 表示中の一覧（検索結果を含む）での移動を、全体の並び順に反映する
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var list = results
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
            showToast("並べ替えを保存できませんでした")
        }
        reload()
    }

    func canMoveUp(_ recipe: Recipe) -> Bool { results.first?.id != recipe.id }
    func canMoveDown(_ recipe: Recipe) -> Bool { results.last?.id != recipe.id }

    func moveUp(_ recipe: Recipe) {
        guard let index = results.firstIndex(of: recipe), index > 0 else { return }
        move(fromOffsets: [index], toOffset: index - 1)
    }

    func moveDown(_ recipe: Recipe) {
        guard let index = results.firstIndex(of: recipe), index < results.count - 1 else { return }
        move(fromOffsets: [index], toOffset: index + 2)
    }

    // MARK: - 削除・ごみ箱

    func delete(_ recipe: Recipe) {
        do {
            try repository.moveToTrash(id: recipe.id)
            analytics.log(.recipeDeleted)
            reload()
            toast = Toast(message: "ごみ箱に移動しました", actionTitle: "元に戻す") { [weak self] in
                guard let self, let trashed = trash.first(where: { $0.id == recipe.id }) else { return }
                _ = restore(trashed)
            }
        } catch {
            showToast("削除できませんでした")
        }
    }

    func restore(_ trashed: TrashedRecipe) -> RestoreResult {
        do {
            let recipe = try repository.restore(id: trashed.id)
            analytics.log(.recipeRestored)
            reload()
            showToast("一覧に戻しました")
            return .restored(recipe)
        } catch RecipeRepositoryError.duplicate(.active(let existing)) {
            return .duplicate(existing)
        } catch {
            return .failed
        }
    }

    func deletePermanently(_ trashed: TrashedRecipe) {
        do {
            try repository.deletePermanently(id: trashed.id)
            analytics.log(.recipeDeletedPermanently)
            reload()
        } catch {
            showToast("削除できませんでした")
        }
    }

    func emptyTrash() {
        do {
            let count = try repository.emptyTrash()
            analytics.log(.trashEmptied(count: count))
            reload()
            showToast("\(count.formatted())件を完全に削除しました")
        } catch {
            showToast("削除できませんでした")
        }
    }

    // MARK: - 検索

    /// 入力欄の文字が変わったとき。日本語の変換中はチップにしない
    func searchInputChanged(isComposing: Bool) {
        guard !isComposing else { return }
        var state = search
        let chipCount = state.chips.count
        let result = state.commitCompletedWords()
        search = state
        if search.chips.count > chipCount { analytics.log(.searchConditionAdded(fromTag: false)) }
        if result == .limitReached { showSearchLimit() }
    }

    /// 入力中の語を確定してチップにする
    func commitSearchInput() {
        search.input += " "
        searchInputChanged(isComposing: false)
    }

    func addSearchCondition(tag: String) {
        switch search.addChip(tag) {
        case .added: analytics.log(.searchConditionAdded(fromTag: true))
        case .duplicate: break
        case .limitReached: showSearchLimit()
        }
    }

    func removeSearchChip(at index: Int) {
        search.removeChip(at: index)
    }

    func clearSearch() {
        search.removeAll()
        analytics.log(.searchCleared)
    }

    private func showSearchLimit() {
        showToast("検索条件は\(RecipeLimits.searchConditions)個・合計\(RecipeLimits.searchTotalLength)文字までです")
    }

    private func updateResults() {
        let conditions = search.conditions
        guard !conditions.isEmpty else {
            results = recipes
            return
        }
        let keywords = conditions.map(SearchKeyword.init)
        results = recipes.filter { target(for: $0).matches(keywords) }
    }

    private func target(for recipe: Recipe) -> SearchTarget {
        if let cached = searchTargets[recipe.id], cached.updatedAt == recipe.updatedAt {
            return cached.target
        }
        let target = SearchTarget(title: recipe.title, tags: recipe.tags, host: recipe.host)
        searchTargets[recipe.id] = (recipe.updatedAt, target)
        return target
    }

    // MARK: - 案内

    func showToast(_ message: String) {
        toast = Toast(message: message)
    }
}
