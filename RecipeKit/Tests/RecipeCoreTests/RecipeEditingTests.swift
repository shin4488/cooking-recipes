import Foundation
import Testing
import RecipeCore

@Suite("登録・編集のタイトルの扱い")
struct RecipeEditingTests {
    private let supportedURL = "https://www.sirogohan.com/recipe/nikujyaga/"
    private let otherSupportedURL = "https://www.kewpie.co.jp/recipes/recipe/QP10220/"
    private let unsupportedURL = "https://www.kurashiru.com/recipes/abc"
    private let created = Date(timeIntervalSince1970: 1_000)
    private let edited = Date(timeIntervalSince1970: 2_000)

    private func recipe(url: String, title: String?, source: TitleSource, state: TitleFetchState) -> Recipe {
        Recipe(url: url, title: title, titleSource: source, titleFetchState: state, tags: ["主菜"], sortKey: 0, createdAt: created, updatedAt: created)
    }

    @Test("手入力・共有タイトルがない対応サイトの新規登録は、本体での自動取得を待つ")
    func newRecipeWaitsForFetch() {
        let recipe = RecipeEditing.newRecipe(url: supportedURL, title: .none, tags: [], sortKey: 0, now: created)
        #expect(recipe.titleSource == .none)
        #expect(recipe.titleFetchState == .notFetched)
        #expect(recipe.needsTitleFetch)
    }

    @Test("対応サイト以外には取得通信を行わない")
    func unsupportedSite() {
        let recipe = RecipeEditing.newRecipe(url: unsupportedURL, title: .none, tags: [], sortKey: 0, now: created)
        #expect(recipe.titleFetchState == .unsupported)
        #expect(!recipe.needsTitleFetch)
    }

    @Test("共有元や手入力のタイトルがあれば自動取得しない")
    func titleFromUserOrShare() {
        let shared = RecipeEditing.newRecipe(url: supportedURL, title: .shared("肉じゃが"), tags: [], sortKey: 0, now: created)
        #expect(shared.title == "肉じゃが")
        #expect(shared.titleSource == .shared)
        #expect(!shared.needsTitleFetch)

        let blank = RecipeEditing.newRecipe(url: supportedURL, title: .manual(nil), tags: [], sortKey: 0, now: created)
        #expect(blank.title == nil)
        #expect(!blank.needsTitleFetch)
    }

    @Test("URLを変えると旧URLの共有・取得タイトルを消し、タグは入力どおりにする", arguments: [TitleSource.shared, .fetched])
    func urlChangeClearsReceivedTitle(source: TitleSource) {
        let original = recipe(url: supportedURL, title: "肉じゃが", source: source, state: .fetched)
        let updated = RecipeEditing.updated(original, url: otherSupportedURL, title: .unchanged, tags: ["副菜"], now: edited)
        #expect(updated.title == nil)
        #expect(updated.titleSource == .none)
        #expect(updated.titleFetchState == .notFetched)
        #expect(updated.tags == ["副菜"])
        #expect(updated.createdAt == created)
        #expect(updated.updatedAt == edited)
    }

    @Test("URLを変えても本人のタイトルは残す")
    func urlChangeKeepsManualTitle() {
        let original = recipe(url: supportedURL, title: "わが家の肉じゃが", source: .manual, state: .notFetched)
        let updated = RecipeEditing.updated(original, url: otherSupportedURL, title: .unchanged, tags: ["主菜"], now: edited)
        #expect(updated.title == "わが家の肉じゃが")
        #expect(updated.titleSource == .manual)
        #expect(!updated.needsTitleFetch)
    }

    @Test("URLを変えなければタイトルと取得の状態を変えない")
    func sameURLKeepsTitle() {
        let original = recipe(url: supportedURL, title: nil, source: .none, state: .failed)
        let updated = RecipeEditing.updated(original, url: supportedURL, title: .unchanged, tags: ["汁物"], now: edited)
        #expect(updated.titleFetchState == .failed)
        #expect(!updated.needsTitleFetch)
    }

    @Test("本人が空欄にしたら、その指定を守って自動取得しない")
    func userClearsTitle() {
        let original = recipe(url: supportedURL, title: "肉じゃが", source: .fetched, state: .fetched)
        let updated = RecipeEditing.updated(original, url: supportedURL, title: .manual(nil), tags: [], now: edited)
        #expect(updated.title == nil)
        #expect(updated.titleSource == .manual)
        #expect(!updated.needsTitleFetch)
    }

    @Test("取得したタイトルを、取得中の記録に反映する")
    func appliesFetchedTitle() {
        let fetching = recipe(url: supportedURL, title: nil, source: .none, state: .fetching)
        let result = RecipeEditing.applying(.fetched("肉じゃが"), to: fetching, fetchedURL: supportedURL, now: edited)
        #expect(result?.title == "肉じゃが")
        #expect(result?.titleSource == .fetched)
        #expect(result?.titleFetchState == .fetched)
    }

    @Test("取得に失敗したら状態だけを変え、記録は消さない")
    func failureKeepsRecord() {
        let fetching = recipe(url: supportedURL, title: nil, source: .none, state: .fetching)
        let result = RecipeEditing.applying(.refused(statusCode: 403, retryAfter: nil), to: fetching, fetchedURL: supportedURL, now: edited)
        #expect(result?.titleFetchState == .failed)
        #expect(result?.url == supportedURL)
    }

    @Test("取得中にURLや本人のタイトルが変わった記録には反映しない")
    func ignoresStaleResult() {
        let changedURL = recipe(url: otherSupportedURL, title: nil, source: .none, state: .fetching)
        #expect(RecipeEditing.applying(.fetched("肉じゃが"), to: changedURL, fetchedURL: supportedURL, now: edited) == nil)

        let manual = recipe(url: supportedURL, title: "自分の名前", source: .manual, state: .notFetched)
        #expect(RecipeEditing.applying(.fetched("肉じゃが"), to: manual, fetchedURL: supportedURL, now: edited) == nil)
    }
}

@Suite("並び順・ごみ箱")
struct OrderAndTrashTests {
    @Test("新しい記録は先頭に入る")
    func newItemOnTop() {
        #expect(SortOrder.keyForNewItem(currentMinimum: 5) < 5)
        #expect(SortOrder.keyForNewItem(currentMinimum: -3) < -3)
    }

    @Test("移動先の上下の記録の間に入れ、間が詰まったら振り直しを求める")
    func keyBetween() throws {
        let middle = try #require(SortOrder.keyBetween(above: 1, below: 2))
        #expect(middle > 1 && middle < 2)
        #expect(try #require(SortOrder.keyBetween(above: nil, below: 3)) < 3)
        #expect(try #require(SortOrder.keyBetween(above: 3, below: nil)) > 3)
        #expect(SortOrder.keyBetween(above: 1, below: 1.0.nextUp) == nil)
    }

    @Test("削除日時から30日間は戻せ、期限を過ぎたら完全に削除する")
    func retention() {
        let deleted = Date(timeIntervalSince1970: 0)
        let thirtyDays: TimeInterval = 30 * 24 * 60 * 60
        #expect(!TrashPolicy.isExpired(deletedAt: deleted, now: deleted.addingTimeInterval(thirtyDays - 1)))
        #expect(TrashPolicy.isExpired(deletedAt: deleted, now: deleted.addingTimeInterval(thirtyDays)))
        #expect(TrashPolicy.daysRemaining(deletedAt: deleted, now: deleted) == 30)
        #expect(TrashPolicy.daysRemaining(deletedAt: deleted, now: deleted.addingTimeInterval(thirtyDays - 60)) == 1)
        #expect(TrashPolicy.daysRemaining(deletedAt: deleted, now: deleted.addingTimeInterval(thirtyDays)) == 0)
    }

    @Test("同じURLの再取得は24時間あけ、拒否したサイトはサイトが指定した待ち時間が長ければそれに従う")
    func throttle() {
        let attempt = Date(timeIntervalSince1970: 0)
        let day: TimeInterval = 24 * 60 * 60
        #expect(TitleFetchThrottle.canAttempt(lastAttempt: nil, now: attempt))
        #expect(!TitleFetchThrottle.canAttempt(lastAttempt: attempt, now: attempt.addingTimeInterval(day - 1)))
        #expect(TitleFetchThrottle.canAttempt(lastAttempt: attempt, now: attempt.addingTimeInterval(day)))
        #expect(TitleFetchThrottle.pauseEnd(refusedAt: attempt, retryAfter: 60) == attempt.addingTimeInterval(day))
        #expect(TitleFetchThrottle.pauseEnd(refusedAt: attempt, retryAfter: 2 * day) == attempt.addingTimeInterval(2 * day))
    }
}
