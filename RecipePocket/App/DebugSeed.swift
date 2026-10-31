#if DEBUG
import Foundation
import RecipeData

/// 件数の多い一覧や検索の速さを確かめるため、起動引数 `-SeedRecipes <件数>` で見本の記録を入れる
enum DebugSeed {
    @MainActor
    static func insertIfRequested(into repository: RecipeRepository) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-SeedRecipes"),
              arguments.indices.contains(index + 1),
              let count = Int(arguments[index + 1]),
              (try? repository.recipes().isEmpty) == true
        else { return }
        let dishes = ["肉じゃが", "鶏の照り焼き", "豚汁", "カレーライス", "親子丼", "ハンバーグ", "ポテトサラダ", "だし巻き卵", "ぶり大根", "麻婆豆腐"]
        let tags = ["主菜", "副菜", "汁物", "ご飯もの", "お弁当", "作り置き", "時短", "鶏肉", "豚肉", "野菜"]
        try? repository.insertSamples(count: count) { index in
            let dish = dishes[index % dishes.count]
            return (
                url: "https://cooking.example.com/recipes/\(index)",
                title: index % 7 == 0 ? nil : "\(dish) \(index)",
                tags: Array(tags.shuffled().prefix(index % 5))
            )
        }
    }
}
#endif
