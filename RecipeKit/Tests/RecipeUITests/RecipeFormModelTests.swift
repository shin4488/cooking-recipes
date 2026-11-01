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
