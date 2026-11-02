import Foundation
import Observation
import RecipeCore

/// 検索ボックスの状態と、その条件で一覧を絞り込んだ結果。一覧で表示位置を合わせる記録も持つ
@MainActor
@Observable
final class SearchStore {
    var state = SearchState() {
        didSet { if state != oldValue { updateResults() } }
    }
    /// 検索の条件に合う記録。一覧の順に並ぶ
    private(set) var results: [Recipe] = []
    /// 一覧で表示位置を合わせて目立たせる記録
    var focusedRecipeID: UUID?

    @ObservationIgnored private var recipes: [Recipe] = []
    @ObservationIgnored private var index = RecipeSearchIndex()
    @ObservationIgnored private let analytics: AppAnalytics
    @ObservationIgnored private let toasts: ToastCenter

    init(analytics: AppAnalytics, toasts: ToastCenter) {
        self.analytics = analytics
        self.toasts = toasts
    }

    /// 読み込み直した一覧を絞り込み直す
    func update(_ recipes: [Recipe]) {
        self.recipes = recipes
        updateResults()
    }

    /// 入力欄の文字が変わったとき。日本語の変換中はチップにしない
    func inputChanged(isComposing: Bool) {
        guard !isComposing else { return }
        var next = state
        let chipCount = next.chips.count
        let result = next.commitCompletedWords()
        state = next
        if state.chips.count > chipCount { analytics.log(.searchConditionAdded(fromTag: false)) }
        if result == .limitReached { showLimit() }
    }

    /// 入力中の語を確定してチップにする
    func commitInput() {
        state.input += " "
        inputChanged(isComposing: false)
    }

    func addCondition(tag: String) {
        switch state.addChip(tag) {
        case .added: analytics.log(.searchConditionAdded(fromTag: true))
        case .duplicate: break
        case .limitReached: showLimit()
        }
    }

    func removeChip(at index: Int) {
        state.removeChip(at: index)
    }

    func clear() {
        state.removeAll()
        analytics.log(.searchCleared)
    }

    /// 一覧で見つけやすいよう、検索条件を外して表示位置を合わせる
    func focus(on recipe: Recipe) {
        if !results.contains(where: { $0.id == recipe.id }) { state.removeAll() }
        focusedRecipeID = recipe.id
    }

    private func showLimit() {
        toasts.show("検索条件は\(RecipeLimits.searchConditions)個・合計\(RecipeLimits.searchTotalLength)文字までです")
    }

    private func updateResults() {
        results = index.results(in: recipes, matching: state.conditions)
    }
}
