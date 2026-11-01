import Foundation
import RecipeCore
import SwiftData
import Testing
@testable import RecipeData

@MainActor
@Suite("タイトルの自動取得の記録")
struct TitleFetchRepositoryTests {
    private let repository: RecipeRepository
    private let titleFetch: TitleFetchRepository
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    init() throws {
        let container = try RecipeContainer.inMemory()
        repository = RecipeRepository(container: container)
        titleFetch = TitleFetchRepository(container: container)
    }

    private func states() throws -> [UUID: TitleFetchState] {
        try Dictionary(uniqueKeysWithValues: repository.recipes().map { ($0.id, $0.titleFetchState) })
    }

    @Test("取得を待つ記録だけを、一覧の順に返す")
    func awaitingFetch() throws {
        let older = try repository.add(url: "https://www.sirogohan.com/recipe/nikujyaga/", title: .none, tags: [], now: now)
        try repository.add(url: "https://www.sirogohan.com/recipe/karaage/", title: .manual("唐揚げ"), tags: [], now: now)
        try repository.add(url: "https://example.com/a", title: .none, tags: [], now: now)
        let newer = try repository.add(url: "https://www.kewpie.co.jp/recipes/recipe/QP00000001/", title: .none, tags: [], now: now.addingTimeInterval(1))
        #expect(try titleFetch.recipesAwaitingFetch().map(\.id) == [newer.id, older.id])

        _ = titleFetch.begin(newer, now: now)
        #expect(try titleFetch.recipesAwaitingFetch().map(\.id) == [older.id])
    }

    @Test("取得してよければ取得中にして試行日時を記録し、取得したタイトルを反映する")
    func beginAndFinish() throws {
        let recipe = try repository.add(url: "https://www.sirogohan.com/recipe/nikujyaga/", title: .none, tags: [], now: now)
        guard case .fetch(let fetching, let site) = titleFetch.begin(recipe, now: now) else {
            Issue.record("取得を始めなかった")
            return
        }
        #expect(fetching.titleFetchState == .fetching)
        #expect(site.id == "sirogohan")
        #expect(try titleFetch.lastAttempt(url: recipe.url) == now)
        #expect(try states()[recipe.id] == .fetching)

        let fetched = titleFetch.finish(fetching, site: site, outcome: .fetched("肉じゃが"), now: now.addingTimeInterval(5))
        #expect(fetched?.title == "肉じゃが")
        #expect(fetched?.titleSource == .fetched)
        #expect(try repository.recipes().first == fetched)
    }

    @Test("取得を始められるのは、手入力・共有のタイトルがなく、取得を待つ記録だけ")
    func beginOnlyAwaiting() throws {
        let manual = try repository.add(url: "https://www.sirogohan.com/recipe/karaage/", title: .manual("唐揚げ"), tags: [], now: now)
        let shared = try repository.add(url: "https://www.sirogohan.com/recipe/tonjiru/", title: .shared("豚汁"), tags: [], now: now)
        let unsupported = try repository.add(url: "https://example.com/a", title: .none, tags: [], now: now)
        #expect(titleFetch.begin(manual, now: now) == .notNeeded)
        #expect(titleFetch.begin(shared, now: now) == .notNeeded)
        #expect(titleFetch.begin(unsupported, now: now) == .notNeeded)
        #expect(try states() == [manual.id: .notFetched, shared.id: .notFetched, unsupported.id: .unsupported])
        #expect(try titleFetch.lastAttempt(url: manual.url) == nil)
    }

    @Test("拒否したサイトへの取得を止めている間は、通信せずに取得失敗にする。止める期限の日時になったら取得する")
    func skipWhilePaused() throws {
        let first = try repository.add(url: "https://www.sirogohan.com/recipe/nikujyaga/", title: .none, tags: [], now: now)
        let second = try repository.add(url: "https://www.sirogohan.com/recipe/karaage/", title: .none, tags: [], now: now)
        try titleFetch.pause(siteID: "sirogohan", until: now.addingTimeInterval(60))
        #expect(titleFetch.begin(first, now: now.addingTimeInterval(59)) == .skipped)
        #expect(try states()[first.id] == .failed)
        #expect(try titleFetch.lastAttempt(url: first.url) == nil)

        guard case .fetch = titleFetch.begin(second, now: now.addingTimeInterval(60)) else {
            Issue.record("止める期限の日時になっても取得しなかった")
            return
        }
    }

    @Test("同じURLを24時間以内に試していれば、通信せずに取得失敗にする")
    func skipWithinInterval() throws {
        let url = "https://www.kewpie.co.jp/recipes/recipe/QP00000001/"
        try titleFetch.recordAttempt(url: url, at: now)
        let recipe = try repository.add(url: url, title: .none, tags: [], now: now)
        #expect(titleFetch.begin(recipe, now: now.addingTimeInterval(day - 1)) == .skipped)
        #expect(try states()[recipe.id] == .failed)

        try titleFetch.recordAttempt(url: "https://www.kewpie.co.jp/recipes/recipe/QP00000002/", at: now)
        let later = try repository.add(url: "https://www.kewpie.co.jp/recipes/recipe/QP00000002/", title: .none, tags: [], now: now)
        guard case .fetch = titleFetch.begin(later, now: now.addingTimeInterval(day)) else {
            Issue.record("24時間たっても取得しなかった")
            return
        }
    }

    @Test("通信制御で取得しないときは、取得中の記録も取得失敗にする")
    func skipFetching() throws {
        let recipe = try repository.add(url: "https://www.sirogohan.com/recipe/nikujyaga/", title: .none, tags: [], now: now)
        guard case .fetch(let fetching, _) = titleFetch.begin(recipe, now: now) else {
            Issue.record("取得を始めなかった")
            return
        }
        #expect(titleFetch.begin(fetching, now: now) == .skipped)
        #expect(try states()[recipe.id] == .failed)
    }

    @Test("拒否の応答なら、24時間かサイトが指定した待ち時間の長いほうまで、そのサイトへの取得を止める")
    func pauseOnRefusal() throws {
        let recipe = try repository.add(url: "https://www.sirogohan.com/recipe/nikujyaga/", title: .none, tags: [], now: now)
        guard case .fetch(let fetching, let site) = titleFetch.begin(recipe, now: now) else {
            Issue.record("取得を始めなかった")
            return
        }
        titleFetch.finish(fetching, site: site, outcome: .refused(statusCode: 429, retryAfter: 60), now: now)
        #expect(try titleFetch.pauseEnd(siteID: "sirogohan") == now.addingTimeInterval(day))
        #expect(try states()[recipe.id] == .failed)

        let other = try repository.add(url: "https://www.kewpie.co.jp/recipes/recipe/QP00000001/", title: .none, tags: [], now: now)
        guard case .fetch(let otherFetching, let otherSite) = titleFetch.begin(other, now: now) else {
            Issue.record("取得を始めなかった")
            return
        }
        titleFetch.finish(otherFetching, site: otherSite, outcome: .refused(statusCode: 403, retryAfter: 2 * day), now: now)
        #expect(try titleFetch.pauseEnd(siteID: "kewpie") == now.addingTimeInterval(2 * day))
    }

    @Test("取得中に本人がタイトルを変えた記録には、取得結果を反映しない")
    func finishIgnoresManualTitle() throws {
        let recipe = try repository.add(url: "https://www.sirogohan.com/recipe/karaage/", title: .none, tags: [], now: now)
        guard case .fetch(let fetching, let site) = titleFetch.begin(recipe, now: now) else {
            Issue.record("取得を始めなかった")
            return
        }
        try repository.update(id: recipe.id, url: recipe.url, title: .manual("自分の唐揚げ"), tags: [], now: now)
        #expect(titleFetch.finish(fetching, site: site, outcome: .fetched("唐揚げ"), now: now) == nil)
        #expect(try repository.recipes().first?.title == "自分の唐揚げ")
    }

    @Test("取得中にURLが変わった記録には、旧URLの取得結果を反映しない")
    func finishIgnoresChangedURL() throws {
        let oldURL = "https://www.sirogohan.com/recipe/nikujyaga/"
        let recipe = try repository.add(url: oldURL, title: .none, tags: [], now: now)
        guard case .fetch(let fetching, let site) = titleFetch.begin(recipe, now: now) else {
            Issue.record("取得を始めなかった")
            return
        }
        try repository.update(id: recipe.id, url: "https://www.sirogohan.com/recipe/karaage/", title: .unchanged, tags: [], now: now)
        #expect(titleFetch.finish(fetching, site: site, outcome: .fetched("肉じゃが"), now: now) == nil)
        let saved = try #require(try repository.recipes().first)
        #expect(saved.title == nil)
        #expect(saved.titleFetchState == .notFetched)
    }

    @Test("取得中のまま終了した記録は、次の起動で取得を待つ状態に戻す")
    func resetInterrupted() throws {
        let recipe = try repository.add(url: "https://www.sirogohan.com/recipe/nikujyaga/", title: .none, tags: [], now: now)
        _ = titleFetch.begin(recipe, now: now)
        try titleFetch.resetInterrupted()
        #expect(try repository.recipes().first?.needsTitleFetch == true)
    }

    @Test("拒否したサイトの停止は、あとから短い期限を記録しても長いほうを保つ")
    func pauseKeepsLaterEnd() throws {
        try titleFetch.pause(siteID: "sirogohan", until: now.addingTimeInterval(100))
        try titleFetch.pause(siteID: "sirogohan", until: now.addingTimeInterval(50))
        #expect(try titleFetch.pauseEnd(siteID: "sirogohan") == now.addingTimeInterval(100))
        try titleFetch.pause(siteID: "sirogohan", until: now.addingTimeInterval(200))
        #expect(try titleFetch.pauseEnd(siteID: "sirogohan") == now.addingTimeInterval(200))
        #expect(try titleFetch.pauseEnd(siteID: "kewpie") == nil)
    }

    @Test("同じURLの試行日時は、最後に試した日時で上書きする")
    func attemptOverwrites() throws {
        let url = "https://www.sirogohan.com/recipe/nikujyaga/"
        try titleFetch.recordAttempt(url: url, at: now)
        try titleFetch.recordAttempt(url: url, at: now.addingTimeInterval(10))
        #expect(try titleFetch.lastAttempt(url: url) == now.addingTimeInterval(10))
        #expect(try titleFetch.lastAttempt(url: "https://www.sirogohan.com/recipe/karaage/") == nil)
    }

    @Test("URLごとの最終試行日時は24時間保持し、拒否したサイトの停止は期限まで保持する")
    func purgeHistory() throws {
        let url = "https://www.sirogohan.com/recipe/nikujyaga/"
        try titleFetch.recordAttempt(url: url, at: now)
        try titleFetch.pause(siteID: "sirogohan", until: now.addingTimeInterval(day - 1))
        try titleFetch.purgeHistory(now: now.addingTimeInterval(day - 2))
        #expect(try titleFetch.lastAttempt(url: url) == now)
        #expect(try titleFetch.pauseEnd(siteID: "sirogohan") == now.addingTimeInterval(day - 1))

        try titleFetch.purgeHistory(now: now.addingTimeInterval(day - 1))
        #expect(try titleFetch.lastAttempt(url: url) == now)
        #expect(try titleFetch.pauseEnd(siteID: "sirogohan") == nil)

        try titleFetch.purgeHistory(now: now.addingTimeInterval(day))
        #expect(try titleFetch.lastAttempt(url: url) == nil)
    }
}
