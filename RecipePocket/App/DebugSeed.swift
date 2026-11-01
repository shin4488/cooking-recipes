#if DEBUG
import Foundation
import RecipeData

/// 記録が空のときに、起動引数で見本の記録を入れる。
/// `-SeedRecipes <件数>` は件数の多い一覧や検索の速さを確かめるため、`-SeedScreenshotRecipes` は App Store 用のスクリーンショットを撮るため
enum DebugSeed {
    @MainActor
    static func insertIfRequested(into repository: RecipeRepository) {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-SeedScreenshotRecipes") {
            guard isEmpty(repository) else { return }
            try? repository.insertSamples(count: screenshotSamples.count) { screenshotSamples[$0] }
            return
        }
        guard let index = arguments.firstIndex(of: "-SeedRecipes"),
              arguments.indices.contains(index + 1),
              let count = Int(arguments[index + 1]),
              isEmpty(repository)
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

    @MainActor
    private static func isEmpty(_ repository: RecipeRepository) -> Bool {
        (try? repository.recipes().isEmpty) == true
    }

    /// App Store の素材に他社の商標や文章を載せないよう、実在しない見本のサイト（example.com など）を使う
    private static let screenshotSamples: [(url: String, title: String?, tags: [String])] = [
        ("https://example.com/recipes/nikujaga", "基本の肉じゃが", ["牛肉", "野菜", "夜ごはん"]),
        ("https://example.net/recipes/teriyaki", "鶏の照り焼き", ["鶏肉", "お弁当", "時短"]),
        ("https://example.org/recipes/tonjiru", "具だくさん豚汁", ["豚肉", "野菜", "朝ごはん"]),
        ("https://example.com/recipes/salmon", "鮭のホイル焼き", ["魚介", "夜ごはん", "時短"]),
        ("https://example.net/recipes/tamagoyaki", "だし巻き卵", ["お弁当", "朝ごはん"]),
        ("https://example.org/recipes/potato-salad", "ポテトサラダ", ["野菜", "昼ごはん", "お弁当"]),
        ("https://example.com/recipes/curry", "夏野菜のカレー", ["野菜", "昼ごはん", "夜ごはん"]),
    ]
}
#endif
