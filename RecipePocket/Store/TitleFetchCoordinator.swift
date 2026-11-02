import Foundation
import RecipeCore
import RecipeData
import UIKit

/// 対応サイトのタイトルを1件ずつ取得する。自動の再試行や巡回はしない。取得してよいかは TitleFetchRepository が決める
@MainActor
final class TitleFetchCoordinator {
    private let repository: TitleFetchRepository
    private let fetcher = TitleFetcher()
    private let onChange: @MainActor () -> Void
    private var isRunning = false
    /// 取得の途中で呼ばれた。取得中にURLを変えた記録などを、今の回の後に取得する
    private var needsRerun = false

    init(repository: TitleFetchRepository, onChange: @escaping @MainActor () -> Void) {
        self.repository = repository
        self.onChange = onChange
    }

    func start() {
        guard !isRunning else {
            needsRerun = true
            return
        }
        isRunning = true
        Task {
            repeat {
                needsRerun = false
                await run()
            } while needsRerun
            isRunning = false
        }
    }

    private func run() async {
        try? repository.purgeHistory()
        var tried = Set<UUID>()
        while let recipe = nextRecipe(excluding: tried) {
            tried.insert(recipe.id)
            await fetch(recipe)
        }
    }

    private func nextRecipe(excluding tried: Set<UUID>) -> Recipe? {
        (try? repository.recipesAwaitingFetch())?.first { !tried.contains($0.id) }
    }

    private func fetch(_ recipe: Recipe) async {
        switch repository.begin(recipe) {
        case .notNeeded:
            return
        case .skipped:
            onChange()
        case .fetch(let fetching, let site):
            onChange()
            // 取得中に裏へ回っても、通信と保存を終えられるようにする
            let task = UIApplication.shared.beginBackgroundTask(withName: "TitleFetch")
            let outcome = await fetcher.fetchTitle(for: fetching.url)
            repository.finish(fetching, site: site, outcome: outcome)
            UIApplication.shared.endBackgroundTask(task)
            onChange()
        }
    }
}
