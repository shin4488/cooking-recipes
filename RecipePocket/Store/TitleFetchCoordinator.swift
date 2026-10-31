import Foundation
import RecipeCore
import RecipeData
import UIKit

/// 対応サイトのタイトルを1件ずつ取得する。自動の再試行や巡回はしない
@MainActor
final class TitleFetchCoordinator {
    private let repository: RecipeRepository
    private let fetcher = TitleFetcher()
    private let onChange: @MainActor () -> Void
    private var isRunning = false

    init(repository: RecipeRepository, onChange: @escaping @MainActor () -> Void) {
        self.repository = repository
        self.onChange = onChange
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        Task {
            await run()
            isRunning = false
        }
    }

    private func run() async {
        try? repository.purgeTitleFetchHistory()
        var tried = Set<UUID>()
        while let recipe = nextRecipe(excluding: tried) {
            tried.insert(recipe.id)
            await fetch(recipe)
        }
    }

    private func nextRecipe(excluding tried: Set<UUID>) -> Recipe? {
        (try? repository.recipesAwaitingTitleFetch())?.first { !tried.contains($0.id) }
    }

    private func fetch(_ recipe: Recipe) async {
        let now = Date.now
        guard let site = SupportedSite.fetchableSite(for: recipe.url) else { return }
        // 拒否したサイトへの取得を止めている間と、同じURLを24時間以内に試した場合は取得しない
        let pausedUntil = try? repository.titleFetchPause(siteID: site.id)
        let lastAttempt = try? repository.lastTitleFetchAttempt(url: recipe.url)
        guard pausedUntil.map({ $0 <= now }) ?? true, TitleFetchThrottle.canAttempt(lastAttempt: lastAttempt, now: now) else {
            try? repository.skipTitleFetch(id: recipe.id)
            onChange()
            return
        }
        guard let fetching = try? repository.beginTitleFetch(id: recipe.id) else { return }
        try? repository.recordTitleFetchAttempt(url: fetching.url, at: now)
        onChange()

        // 取得中に裏へ回っても、通信と保存を終えられるようにする
        let task = UIApplication.shared.beginBackgroundTask(withName: "TitleFetch")
        let outcome = await fetcher.fetchTitle(for: fetching.url)
        if case .refused(_, let retryAfter) = outcome {
            try? repository.pauseTitleFetch(siteID: site.id, until: TitleFetchThrottle.pauseEnd(refusedAt: .now, retryAfter: retryAfter))
        }
        _ = try? repository.finishTitleFetch(id: fetching.id, url: fetching.url, outcome: outcome)
        UIApplication.shared.endBackgroundTask(task)
        onChange()
    }
}
