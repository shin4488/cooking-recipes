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
            let background = BackgroundExecution(name: "TitleFetch")
            let outcome = await fetcher.fetchTitle(for: fetching.url)
            repository.finish(fetching, site: site, outcome: outcome)
            background.end()
            onChange()
        }
    }
}

/// 裏に回っても処理を続けるための許可。裏で使える時間が切れたときは、アプリが終了されないよう、その時点で終える。
/// 終えたあとの取得は、前面に戻ってから結果を反映する
@MainActor
private final class BackgroundExecution {
    private var identifier = UIBackgroundTaskIdentifier.invalid

    init(name: String) {
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            self?.end()
        }
    }

    /// 時間切れと処理の終わりのうち、先に来たほうで1度だけ終える
    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
