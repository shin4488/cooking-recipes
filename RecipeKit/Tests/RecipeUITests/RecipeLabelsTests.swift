import Foundation
import RecipeCore
import Testing
import RecipeUI

@Suite("記録の表記")
struct RecipeLabelsTests {
    private func recipe(url: String, title: String?) -> Recipe {
        Recipe(url: url, title: title, titleSource: .manual, titleFetchState: .unsupported, tags: [], sortKey: 0, createdAt: .now, updatedAt: .now)
    }

    @Test("未設定なら「タイトル未設定」と表示し、ホスト名は加えない")
    func displayTitle() {
        #expect(recipe(url: "https://cooking.example.com/a", title: nil).displayTitle == "タイトル未設定")
        #expect(recipe(url: "https://cooking.example.com/a", title: "").displayTitle == "タイトル未設定")
        #expect(recipe(url: "https://cooking.example.com/a", title: "肉じゃが").displayTitle == "肉じゃが")
    }

    @Test("一覧ではキユーピーなど対応サイトの名前を併記し、他はホスト名を示す")
    func siteLabel() {
        #expect(recipe(url: "https://www.kewpie.co.jp/recipes/recipe/QP10220/", title: "ポテトサラダ").siteLabel == "キユーピー")
        #expect(recipe(url: "https://cooking.example.com/a", title: nil).siteLabel == "cooking.example.com")
        #expect(recipe(url: "not a url", title: nil).siteLabel == nil)
    }
}
