import Foundation
import RecipeCore
import SwiftData
import Testing
@testable import RecipeData

@MainActor
@Suite("端末内の記録")
struct RecipeRepositoryTests {
    private let container: ModelContainer
    private let repository: RecipeRepository
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    init() throws {
        container = try RecipeContainer.inMemory()
        repository = RecipeRepository(container: container)
    }

    /// 登録時の重複の確認を通さずに記録を入れる。共有拡張が同時に保存した場合などを作る
    private func insert(_ recipe: Recipe) throws {
        let context = ModelContext(container)
        context.insert(RecipeRecord(recipe))
        try context.save()
    }

    private func makeRecipe(url: String, sortKey: Double = 0, createdAt: Date) -> Recipe {
        Recipe(id: UUID(), url: url, title: nil, titleSource: .none, titleFetchState: .unsupported, tags: [], sortKey: sortKey, createdAt: createdAt, updatedAt: createdAt)
    }

    @Test("新しく登録した記録は一覧の先頭に入る")
    func addPutsNewestFirst() throws {
        try repository.add(url: "https://example.com/1", title: .manual("1件目"), tags: [], now: now)
        try repository.add(url: "https://example.com/2", title: .manual("2件目"), tags: [], now: now.addingTimeInterval(1))
        #expect(try repository.recipes().map(\.title) == ["2件目", "1件目"])
    }

    @Test("並び順の値が同じ記録は、新しく登録した順に並べる")
    func sameSortKeyNewestFirst() throws {
        let older = makeRecipe(url: "https://example.com/older", createdAt: now)
        let newer = makeRecipe(url: "https://example.com/newer", createdAt: now.addingTimeInterval(1))
        try insert(older)
        try insert(newer)
        #expect(try repository.recipes().map(\.id) == [newer.id, older.id])
    }

    @Test("一覧・ごみ箱・復元の間で、記録の項目をすべて保つ")
    func keepsAllFields() throws {
        let added = try repository.add(url: "https://example.com/a", title: .shared("肉じゃが"), tags: ["主菜", "牛肉"], now: now)
        let listed = try #require(try repository.recipes().first)
        #expect(listed.url == "https://example.com/a")
        #expect(listed.title == "肉じゃが")
        #expect(listed.titleSource == .shared)
        #expect(listed.titleFetchState == .unsupported)
        #expect(listed.tags == ["主菜", "牛肉"])
        #expect(listed.createdAt == now)
        #expect(listed.updatedAt == now)
        #expect(listed == added)

        try repository.moveToTrash(id: added.id, now: now.addingTimeInterval(5))
        let trashed = try #require(try repository.trashedRecipes().first)
        #expect(trashed.recipe == added)
        #expect(trashed.deletedAt == now.addingTimeInterval(5))

        #expect(try repository.restore(id: added.id) == added)
        #expect(try repository.recipes() == [added])
    }

    @Test("編集で変えた項目を保存し、IDと登録日時と並び順は変えない")
    func updateKeepsIdentity() throws {
        let original = try repository.add(url: "https://example.com/a", title: .manual("A"), tags: ["主菜"], now: now)
        let edited = now.addingTimeInterval(60)
        try repository.update(id: original.id, url: "https://example.com/b", title: .manual("B"), tags: ["副菜", "時短"], now: edited)
        let saved = try #require(try repository.recipes().first)
        #expect(saved.id == original.id)
        #expect(saved.url == "https://example.com/b")
        #expect(saved.title == "B")
        #expect(saved.titleSource == .manual)
        #expect(saved.tags == ["副菜", "時短"])
        #expect(saved.sortKey == original.sortKey)
        #expect(saved.createdAt == now)
        #expect(saved.updatedAt == edited)
    }

    @Test("保存された値が読めない種類なら、タイトルの入力方法は未設定、取得の状態は未取得として読む")
    func unknownStoredValues() throws {
        let context = ModelContext(container)
        context.insert(RecipeRecord(id: UUID(), url: "https://example.com/a", title: nil, titleSourceValue: "future", titleFetchStateValue: "future", tags: [], sortKey: 0, createdAt: now, updatedAt: now))
        context.insert(TrashedRecipeRecord(id: UUID(), url: "https://example.com/b", title: nil, titleSourceValue: "future", titleFetchStateValue: "future", tags: [], sortKey: 0, createdAt: now, updatedAt: now, deletedAt: now))
        try context.save()
        let listed = try #require(try repository.recipes().first)
        #expect(listed.titleSource == .none)
        #expect(listed.titleFetchState == .notFetched)
        let trashed = try #require(try repository.trashedRecipes().first)
        #expect(trashed.recipe.titleSource == .none)
        #expect(trashed.recipe.titleFetchState == .notFetched)
    }

    @Test("同じURLの記録があれば保存せず、既存の記録を返す")
    func duplicateActive() throws {
        let existing = try repository.add(url: "https://example.com/a", title: .none, tags: [], now: now)
        #expect(throws: RecipeRepositoryError.duplicate(.active(existing))) {
            try repository.add(url: " HTTPS://EXAMPLE.COM:443/a ", title: .manual("別名"), tags: ["主菜"], now: now)
        }
        #expect(try repository.recipes().count == 1)
    }

    @Test("タイトルやタグが同じでもURLが違えば保存できる")
    func sameTitleDifferentURL() throws {
        try repository.add(url: "https://example.com/a", title: .manual("肉じゃが"), tags: ["主菜"], now: now)
        try repository.add(url: "https://example.com/b", title: .manual("肉じゃが"), tags: ["主菜"], now: now)
        #expect(try repository.recipes().count == 2)
    }

    @Test("ごみ箱に同じURLがあれば、ごみ箱の記録を案内する")
    func duplicateTrashed() throws {
        let recipe = try repository.add(url: "https://example.com/a", title: .manual("肉じゃが"), tags: [], now: now)
        try repository.moveToTrash(id: recipe.id, now: now)
        #expect(throws: RecipeRepositoryError.duplicate(.trashed(TrashedRecipe(recipe: recipe, deletedAt: now)))) {
            try repository.add(url: "https://example.com/a", title: .none, tags: [], now: now)
        }
    }

    @Test("同じURLが一覧とごみ箱の両方にあれば一覧の記録を、ごみ箱に複数あれば最後に削除した記録を案内する")
    func duplicatePreference() throws {
        let url = "https://example.com/a"
        let first = try repository.add(url: url, title: .manual("1回目"), tags: [], now: now)
        try repository.moveToTrash(id: first.id, now: now.addingTimeInterval(1))
        // 登録時はごみ箱との重複も止めるため、共有拡張が同時に保存した場合を直接作る
        let second = makeRecipe(url: url, createdAt: now)
        try insert(second)
        try repository.moveToTrash(id: second.id, now: now.addingTimeInterval(2))
        #expect(try repository.duplicate(of: url) == .trashed(TrashedRecipe(recipe: second, deletedAt: now.addingTimeInterval(2))))

        let third = makeRecipe(url: url, createdAt: now)
        try insert(third)
        #expect(try repository.duplicate(of: url) == .active(third))
    }

    @Test("URLを編集して別の記録と同じになる場合は保存しない。自分自身との一致は重複にしない")
    func duplicateOnEdit() throws {
        let first = try repository.add(url: "https://example.com/a", title: .none, tags: [], now: now)
        let second = try repository.add(url: "https://example.com/b", title: .none, tags: [], now: now)
        #expect(throws: RecipeRepositoryError.duplicate(.active(first))) {
            try repository.update(id: second.id, url: "https://example.com/a", title: .unchanged, tags: [], now: now)
        }
        let updated = try repository.update(id: first.id, url: "https://EXAMPLE.com/a", title: .unchanged, tags: ["副菜"], now: now)
        #expect(updated.tags == ["副菜"])
    }

    @Test("削除した記録はごみ箱へ移り、一覧・検索の対象から外れる。復元すると元の位置に戻る")
    func trashAndRestore() throws {
        let a = try repository.add(url: "https://example.com/a", title: .manual("A"), tags: [], now: now)
        let b = try repository.add(url: "https://example.com/b", title: .manual("B"), tags: [], now: now.addingTimeInterval(1))
        let c = try repository.add(url: "https://example.com/c", title: .manual("C"), tags: [], now: now.addingTimeInterval(2))
        try repository.moveToTrash(id: b.id, now: now.addingTimeInterval(10))
        #expect(try repository.recipes().map(\.id) == [c.id, a.id])
        #expect(try repository.trashedRecipes().map(\.id) == [b.id])
        #expect(try repository.trashedRecipes().first?.deletedAt == now.addingTimeInterval(10))

        try repository.restore(id: b.id)
        #expect(try repository.recipes().map(\.id) == [c.id, b.id, a.id])
        #expect(try repository.trashedRecipes().isEmpty)
    }

    @Test("ごみ箱は削除が新しい順に並べる")
    func trashOrder() throws {
        let recipes = try (1...3).map { index in
            try repository.add(url: "https://example.com/\(index)", title: .none, tags: [], now: now)
        }
        try repository.moveToTrash(id: recipes[1].id, now: now.addingTimeInterval(1))
        try repository.moveToTrash(id: recipes[0].id, now: now.addingTimeInterval(3))
        try repository.moveToTrash(id: recipes[2].id, now: now.addingTimeInterval(2))
        #expect(try repository.trashedRecipes().map(\.id) == [recipes[0].id, recipes[2].id, recipes[1].id])
    }

    @Test("一覧に同じURLの記録があれば、ごみ箱から戻さない")
    func restoreBlockedByDuplicate() throws {
        let original = try repository.add(url: "https://example.com/a", title: .none, tags: [], now: now)
        try repository.moveToTrash(id: original.id, now: now)
        // 登録時はごみ箱との重複も止めるため、共有拡張が同時に保存した場合を直接作る
        let concurrent = Recipe(id: UUID(), url: "https://example.com/a", title: nil, titleSource: .none, titleFetchState: .unsupported, tags: [], sortKey: 0, createdAt: now, updatedAt: now)
        let context = ModelContext(container)
        context.insert(RecipeRecord(concurrent))
        try context.save()
        #expect(throws: RecipeRepositoryError.duplicate(.active(concurrent))) {
            try repository.restore(id: original.id)
        }
        #expect(try repository.trashedRecipes().count == 1)
    }

    @Test("ごみ箱は削除日時から30日を過ぎた記録だけを完全に削除する")
    func purge() throws {
        let old = try repository.add(url: "https://example.com/old", title: .none, tags: [], now: now)
        let recent = try repository.add(url: "https://example.com/recent", title: .none, tags: [], now: now)
        try repository.moveToTrash(id: old.id, now: now)
        try repository.moveToTrash(id: recent.id, now: now.addingTimeInterval(24 * 60 * 60))
        let removed = try repository.purgeExpiredTrash(now: now.addingTimeInterval(30 * 24 * 60 * 60))
        #expect(removed == 1)
        #expect(try repository.trashedRecipes().map(\.id) == [recent.id])
    }

    @Test("完全削除・全件消去は件数を返す")
    func emptyTrash() throws {
        for index in 1...3 {
            let recipe = try repository.add(url: "https://example.com/\(index)", title: .none, tags: [], now: now)
            try repository.moveToTrash(id: recipe.id, now: now)
        }
        let first = try #require(try repository.trashedRecipes().first)
        try repository.deletePermanently(id: first.id)
        #expect(try repository.emptyTrash() == 2)
        #expect(try repository.trashedRecipes().isEmpty)
    }

    @Test("並べ替えた順序を保存する。間が詰まっても全体を振り直して順序を保つ")
    func reorder() throws {
        let a = try repository.add(url: "https://example.com/a", title: .none, tags: [], now: now)
        let b = try repository.add(url: "https://example.com/b", title: .none, tags: [], now: now.addingTimeInterval(1))
        let c = try repository.add(url: "https://example.com/c", title: .none, tags: [], now: now.addingTimeInterval(2))
        // 表示順は c, b, a。a を c と b の間へ移す
        try repository.move(id: a.id, above: c.id, below: b.id)
        #expect(try repository.recipes().map(\.id) == [c.id, a.id, b.id])

        for _ in 0..<80 {
            try repository.move(id: b.id, above: c.id, below: a.id)
            try repository.move(id: a.id, above: c.id, below: b.id)
        }
        #expect(try repository.recipes().map(\.id) == [c.id, a.id, b.id])
    }

    @Test("タグの候補には一覧の記録のタグだけを含める")
    func savedTags() throws {
        try repository.add(url: "https://example.com/a", title: .none, tags: ["主菜", "鶏肉"], now: now)
        let trashed = try repository.add(url: "https://example.com/b", title: .none, tags: ["ごみ箱だけ"], now: now)
        try repository.moveToTrash(id: trashed.id, now: now)
        #expect(Set(try repository.savedTags()) == ["主菜", "鶏肉"])
    }

    @Test("保存済みのタグは、同じ文字列を1つにし、表記ゆれはまとめない")
    func savedTagsKeepNotations() throws {
        try repository.add(url: "https://example.com/a", title: .none, tags: ["主菜", "ＣＵＲＲＹ"], now: now)
        try repository.add(url: "https://example.com/b", title: .none, tags: ["主菜", "curry"], now: now)
        let tags = try repository.savedTags()
        #expect(tags.count == 3)
        #expect(Set(tags) == ["主菜", "ＣＵＲＲＹ", "curry"])
    }

    @Test("取得を始められるのは、手入力・共有のタイトルがなく、取得を待つ記録だけ")
    func beginOnlyAwaiting() throws {
        let waiting = try repository.add(url: "https://www.sirogohan.com/recipe/nikujyaga/", title: .none, tags: [], now: now)
        let manual = try repository.add(url: "https://www.sirogohan.com/recipe/karaage/", title: .manual("唐揚げ"), tags: [], now: now)
        let unsupported = try repository.add(url: "https://example.com/a", title: .none, tags: [], now: now)
        #expect(try repository.beginTitleFetch(id: manual.id) == nil)
        #expect(try repository.beginTitleFetch(id: unsupported.id) == nil)
        #expect(try repository.beginTitleFetch(id: waiting.id)?.titleFetchState == .fetching)
        let states = try Dictionary(uniqueKeysWithValues: repository.recipes().map { ($0.id, $0.titleFetchState) })
        #expect(states == [waiting.id: .fetching, manual.id: .notFetched, unsupported.id: .unsupported])
    }

    @Test("通信制御で取得しない記録は、取得を待つ状態か取得中のときだけ取得失敗にする")
    func skipOnlyAwaitingOrFetching() throws {
        let waiting = try repository.add(url: "https://www.sirogohan.com/recipe/nikujyaga/", title: .none, tags: [], now: now)
        let fetching = try repository.add(url: "https://www.sirogohan.com/recipe/karaage/", title: .none, tags: [], now: now)
        _ = try repository.beginTitleFetch(id: fetching.id)
        let manual = try repository.add(url: "https://www.sirogohan.com/recipe/tonjiru/", title: .manual("豚汁"), tags: [], now: now)
        let unsupported = try repository.add(url: "https://example.com/a", title: .none, tags: [], now: now)
        for recipe in [waiting, fetching, manual, unsupported] {
            try repository.skipTitleFetch(id: recipe.id)
        }
        let states = try Dictionary(uniqueKeysWithValues: repository.recipes().map { ($0.id, $0.titleFetchState) })
        #expect(states == [waiting.id: .failed, fetching.id: .failed, manual.id: .notFetched, unsupported.id: .unsupported])
    }

    @Test("取得中にURLが変わった記録には、旧URLの取得結果を反映しない")
    func finishIgnoresChangedURL() throws {
        let oldURL = "https://www.sirogohan.com/recipe/nikujyaga/"
        let newURL = "https://www.sirogohan.com/recipe/karaage/"
        let recipe = try repository.add(url: oldURL, title: .none, tags: [], now: now)
        _ = try repository.beginTitleFetch(id: recipe.id)
        try repository.update(id: recipe.id, url: newURL, title: .unchanged, tags: [], now: now)
        #expect(try repository.finishTitleFetch(id: recipe.id, url: oldURL, outcome: .fetched("肉じゃが"), now: now) == nil)
        let saved = try #require(try repository.recipes().first)
        #expect(saved.title == nil)
        #expect(saved.titleFetchState == .notFetched)
    }

    @Test("拒否したサイトの停止は、あとから短い期限を記録しても長いほうを保つ")
    func pauseKeepsLaterEnd() throws {
        try repository.pauseTitleFetch(siteID: "sirogohan", until: now.addingTimeInterval(100))
        try repository.pauseTitleFetch(siteID: "sirogohan", until: now.addingTimeInterval(50))
        #expect(try repository.titleFetchPause(siteID: "sirogohan") == now.addingTimeInterval(100))
        try repository.pauseTitleFetch(siteID: "sirogohan", until: now.addingTimeInterval(200))
        #expect(try repository.titleFetchPause(siteID: "sirogohan") == now.addingTimeInterval(200))
        #expect(try repository.titleFetchPause(siteID: "kewpie") == nil)
    }

    @Test("同じURLの試行日時は、最後に試した日時で上書きする")
    func attemptOverwrites() throws {
        let url = "https://www.sirogohan.com/recipe/nikujyaga/"
        try repository.recordTitleFetchAttempt(url: url, at: now)
        try repository.recordTitleFetchAttempt(url: url, at: now.addingTimeInterval(10))
        #expect(try repository.lastTitleFetchAttempt(url: url) == now.addingTimeInterval(10))
        #expect(try repository.lastTitleFetchAttempt(url: "https://www.sirogohan.com/recipe/karaage/") == nil)
    }

    @Test("試行日時は24時間たったときに、停止は期限の日時になったときに消す")
    func purgeBoundaries() throws {
        let url = "https://www.sirogohan.com/recipe/nikujyaga/"
        let day: TimeInterval = 24 * 60 * 60
        try repository.recordTitleFetchAttempt(url: url, at: now)
        try repository.pauseTitleFetch(siteID: "sirogohan", until: now.addingTimeInterval(day - 1))
        try repository.purgeTitleFetchHistory(now: now.addingTimeInterval(day - 2))
        #expect(try repository.lastTitleFetchAttempt(url: url) == now)
        #expect(try repository.titleFetchPause(siteID: "sirogohan") == now.addingTimeInterval(day - 1))

        try repository.purgeTitleFetchHistory(now: now.addingTimeInterval(day - 1))
        #expect(try repository.lastTitleFetchAttempt(url: url) == now)
        #expect(try repository.titleFetchPause(siteID: "sirogohan") == nil)

        try repository.purgeTitleFetchHistory(now: now.addingTimeInterval(day))
        #expect(try repository.lastTitleFetchAttempt(url: url) == nil)
    }

    @Test("自動取得は取得中にしてから結果を反映し、取得中に本人がタイトルを変えたら反映しない")
    func titleFetch() throws {
        let url = "https://www.sirogohan.com/recipe/nikujyaga/"
        let recipe = try repository.add(url: url, title: .none, tags: [], now: now)
        let fetching = try #require(try repository.beginTitleFetch(id: recipe.id))
        #expect(fetching.titleFetchState == .fetching)
        #expect(try repository.beginTitleFetch(id: recipe.id) == nil)

        let fetched = try repository.finishTitleFetch(id: recipe.id, url: url, outcome: .fetched("肉じゃが"), now: now)
        #expect(fetched?.title == "肉じゃが")

        let other = try repository.add(url: "https://www.sirogohan.com/recipe/karaage/", title: .none, tags: [], now: now)
        _ = try repository.beginTitleFetch(id: other.id)
        try repository.update(id: other.id, url: other.url, title: .manual("自分の唐揚げ"), tags: [], now: now)
        #expect(try repository.finishTitleFetch(id: other.id, url: other.url, outcome: .fetched("唐揚げ"), now: now) == nil)
        #expect(try repository.recipes().first { $0.id == other.id }?.title == "自分の唐揚げ")
    }

    @Test("自動取得を待つ記録だけを、一覧の順に返す")
    func awaitingTitleFetch() throws {
        let older = try repository.add(url: "https://www.sirogohan.com/recipe/nikujyaga/", title: .none, tags: [], now: now)
        try repository.add(url: "https://www.sirogohan.com/recipe/karaage/", title: .manual("唐揚げ"), tags: [], now: now)
        try repository.add(url: "https://example.com/a", title: .none, tags: [], now: now)
        let newer = try repository.add(url: "https://www.kewpie.co.jp/recipes/recipe/QP00000001/", title: .none, tags: [], now: now.addingTimeInterval(1))
        #expect(try repository.recipesAwaitingTitleFetch().map(\.id) == [newer.id, older.id])

        _ = try repository.beginTitleFetch(id: newer.id)
        #expect(try repository.recipesAwaitingTitleFetch().map(\.id) == [older.id])
    }

    @Test("取得中のまま終了した記録は、次の起動で取得を待つ状態に戻す")
    func resetInterrupted() throws {
        let recipe = try repository.add(url: "https://www.sirogohan.com/recipe/nikujyaga/", title: .none, tags: [], now: now)
        _ = try repository.beginTitleFetch(id: recipe.id)
        try repository.resetInterruptedTitleFetches()
        #expect(try repository.recipes().first?.needsTitleFetch == true)
    }

    @Test("URLごとの最終試行日時は24時間保持し、拒否したサイトの停止は期限まで保持する")
    func fetchHistory() throws {
        let url = "https://www.sirogohan.com/recipe/nikujyaga/"
        try repository.recordTitleFetchAttempt(url: url, at: now)
        try repository.pauseTitleFetch(siteID: "sirogohan", until: now.addingTimeInterval(60))
        try repository.purgeTitleFetchHistory(now: now.addingTimeInterval(59))
        #expect(try repository.lastTitleFetchAttempt(url: url) == now)
        #expect(try repository.titleFetchPause(siteID: "sirogohan") == now.addingTimeInterval(60))

        try repository.purgeTitleFetchHistory(now: now.addingTimeInterval(24 * 60 * 60))
        #expect(try repository.lastTitleFetchAttempt(url: url) == nil)
        #expect(try repository.titleFetchPause(siteID: "sirogohan") == nil)
    }
}
