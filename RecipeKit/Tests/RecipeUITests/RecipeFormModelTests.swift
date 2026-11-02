import Foundation
import RecipeCore
import RecipeData
import Testing
@testable import RecipeUI

@MainActor
@Suite("登録・編集画面の入力")
struct RecipeFormModelTests {
    private let recipe = Recipe(url: "https://example.com/a", title: "肉じゃが", titleSource: .manual, titleFetchState: .unsupported, tags: [], sortKey: 0, createdAt: .now, updatedAt: .now)

    @Test("URLが空白だけのときは保存のボタンを押せない", arguments: ["", " ", "\n", " \t "])
    func cannotSaveBlankURL(url: String) {
        let model = RecipeFormModel(urlChoices: [], sharedTitle: nil, savedTags: [])
        model.url = url
        #expect(!model.canSave)
    }

    @Test("URLに空白以外の文字があれば、検証の前でも保存のボタンを押せる", arguments: ["a", " https://example.com/a ", "not a url"])
    func canSaveNonBlankURL(url: String) {
        let model = RecipeFormModel(urlChoices: [], sharedTitle: nil, savedTags: [])
        model.url = url
        #expect(model.canSave)
    }

    @Test("登録と編集の画面を、記録ごとに区別する")
    func modeID() {
        let other = Recipe(id: UUID(), url: recipe.url, title: recipe.title, titleSource: recipe.titleSource, titleFetchState: recipe.titleFetchState, tags: [], sortKey: 0, createdAt: .now, updatedAt: .now)
        #expect(RecipeFormModel.Mode.add.id == "add")
        #expect(RecipeFormModel.Mode.edit(recipe).id == recipe.id.uuidString)
        #expect(RecipeFormModel.Mode.edit(recipe).id != RecipeFormModel.Mode.edit(other).id)
    }
}

@MainActor
@Suite("保存できなかったときの確認")
struct RecipeSaveAlertsTests {
    private let recipe = Recipe(url: "https://example.com/a", title: nil, titleSource: .none, titleFetchState: .unsupported, tags: [], sortKey: 0, createdAt: .now, updatedAt: .now)

    @Test("保存できたときは確認を出さない")
    func saved() {
        let alerts = RecipeSaveAlerts()
        alerts.show(.saved(recipe))
        #expect(alerts.duplicate == nil)
        #expect(!alerts.saveFailed)
    }

    @Test("同じURLの記録があれば、その記録の確認を出す")
    func duplicate() {
        let alerts = RecipeSaveAlerts()
        alerts.show(.duplicate(.active(recipe)))
        #expect(alerts.duplicate == .active(recipe))
        #expect(!alerts.saveFailed)

        let trashed = TrashedRecipe(recipe: recipe, deletedAt: .now)
        alerts.show(.duplicate(.trashed(trashed)))
        #expect(alerts.duplicate == .trashed(trashed))
    }

    @Test("失敗したら、入力が残っていることを伝える確認を出す")
    func failed() {
        let alerts = RecipeSaveAlerts()
        alerts.show(.failed)
        #expect(alerts.duplicate == nil)
        #expect(alerts.saveFailed)
    }
}

@MainActor
@Suite("タイトルの案内と保存の結果")
struct RecipeFormNoteTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let sirogohan = "https://www.sirogohan.com/recipe/nikujyaga/"
    private let sirogohanOther = "https://www.sirogohan.com/recipe/karaage/"
    private let other = "https://example.com/a"

    private func recipe(url: String, title: String?, source: TitleSource, state: TitleFetchState) -> Recipe {
        Recipe(url: url, title: title, titleSource: source, titleFetchState: state, tags: [], sortKey: 0, createdAt: now, updatedAt: now)
    }

    /// 保存した記録の取得を、本体が行うか（取得を待つ、または取得中のまま結果を反映する）
    private func willFetch(_ saved: Recipe) -> Bool {
        saved.titleSource == .none && (saved.titleFetchState == .notFetched || saved.titleFetchState == .fetching)
            && SupportedSite.fetchableSite(for: saved.url) != nil
    }

    @Test("編集で、タイトル欄に入力してから消し、URLを対応サイトに変えたときは、保存後に取得すると案内する")
    func noteAfterTypingAndClearing() {
        let model = RecipeFormModel(editing: recipe(url: other, title: nil, source: .none, state: .unsupported), savedTags: [])
        model.title = "仮"
        model.title = ""
        model.url = sirogohan
        #expect(model.siteForTitleFetch?.id == "sirogohan")
    }

    @Test("URLを変えて消えたタイトルを、同じ文字で入力し直したら、そのタイトルを保存する")
    func reenteredTitleIsSaved() {
        let model = RecipeFormModel(editing: recipe(url: sirogohan, title: "肉じゃが", source: .fetched, state: .fetched), savedTags: [])
        model.url = sirogohanOther
        #expect(model.title.isEmpty)
        model.title = "肉じゃが"
        #expect(model.makeOutput()?.title == .manual("肉じゃが"))
    }

    @Test("取得を待っている記録の編集では、保存後に取得すると案内する")
    func noteForAwaitingRecipe() {
        let model = RecipeFormModel(editing: recipe(url: sirogohan, title: nil, source: .none, state: .notFetched), savedTags: [])
        #expect(model.siteForTitleFetch?.id == "sirogohan")
    }

    enum Edit: CaseIterable, Sendable {
        case nothing, typeTitle, typeAndClear, sameTitleAgain, clearTitle, toSupported, toOtherSupported, toUnsupported, toSupportedThenTypeSame
    }

    nonisolated static let starts: [(String, String?, TitleSource, TitleFetchState)] = [
        ("https://www.sirogohan.com/recipe/nikujyaga/", nil, .none, .notFetched),
        ("https://www.sirogohan.com/recipe/nikujyaga/", nil, .none, .fetching),
        ("https://www.sirogohan.com/recipe/nikujyaga/", nil, .none, .failed),
        ("https://www.sirogohan.com/recipe/nikujyaga/", "肉じゃが", .fetched, .fetched),
        ("https://www.sirogohan.com/recipe/nikujyaga/", "肉じゃが", .shared, .notFetched),
        ("https://www.sirogohan.com/recipe/nikujyaga/", "肉じゃが", .manual, .notFetched),
        ("https://www.sirogohan.com/recipe/nikujyaga/", nil, .manual, .notFetched),
        ("https://example.com/a", nil, .none, .unsupported),
        ("https://example.com/a", "肉じゃが", .manual, .unsupported),
    ]

    @Test("編集の案内は、保存したときに本体が取得するかと合う", arguments: 0..<starts.count, Edit.allCases)
    func noteMatchesSavedRecipe(start: Int, edit: Edit) {
        let (url, title, source, state) = Self.starts[start]
        let original = recipe(url: url, title: title, source: source, state: state)
        let model = RecipeFormModel(editing: original, savedTags: [])
        switch edit {
        case .nothing: break
        case .typeTitle: model.title = "手入力"
        case .typeAndClear: model.title = "仮"; model.title = ""
        case .sameTitleAgain: model.title = "仮"; model.title = title ?? ""
        case .clearTitle: model.title = ""
        case .toSupported: model.url = sirogohanOther
        case .toOtherSupported: model.url = "https://www.kewpie.co.jp/recipes/recipe/QP00000001/"
        case .toUnsupported: model.url = "https://example.org/b"
        case .toSupportedThenTypeSame: model.url = sirogohanOther; model.title = title ?? ""
        }
        let note = model.siteForTitleFetch
        guard let output = model.makeOutput() else {
            Issue.record("入力の検証に通らなかった")
            return
        }
        let saved = RecipeEditing.updated(original, url: output.url, title: output.title, tags: output.tags, now: now)
        #expect((note != nil) == willFetch(saved), "案内 \(note?.id ?? "なし")・保存後 \(saved.titleSource) \(saved.titleFetchState)")
    }
}
