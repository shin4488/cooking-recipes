import Foundation
import RecipeCore
import SwiftData

/// `TitleFetchRepository.recipesAwaitingFetch()` で得た記録の取得を始めようとした結果
public enum TitleFetchStart: Equatable, Sendable {
    /// 「取得中」にして試行日時を記録した。通信して、結果を `TitleFetchRepository.finish` で反映する
    case fetch(Recipe, SupportedSite)
    /// 拒否したサイトへの取得を止めている間か、同じURLを24時間以内に試したため、通信しない。取得を待つ記録と取得中の記録は「取得失敗」にする
    case skipped
    /// 通信しない。取得の対象でないか、「取得中」にできなかった（記録が見つからない・書き込めないなど）か、通信制御の記録を読み書きできなかった。
    /// 取得を待つ記録は、そのまま残す
    case notNeeded
}

/// 対応サイトからのタイトルの自動取得に使う記録の読み書き。取得を待つ記録の状態と、通信制御のためのURLごとの最終試行日時・サイトごとの停止（TitleFetchHistory）を扱う。
/// 通信は呼び出し側が行う。通信制御の記録を読み書きできないときは、通信してよいか分からないため通信しない
@MainActor
public final class TitleFetchRepository {
    private let container: ModelContainer
    /// 通信制御の記録。テストでは、読み書きの失敗を起こす差し替えを渡す
    let history: any TitleFetchHistory

    public convenience init(container: ModelContainer) {
        self.init(container: container, history: StoredTitleFetchHistory(container: container))
    }

    init(container: ModelContainer, history: any TitleFetchHistory) {
        self.container = container
        self.history = history
    }

    /// 本体がタイトルを自動取得する記録。一覧の並び順で返す
    public func recipesAwaitingFetch() throws -> [Recipe] {
        let notFetched = TitleFetchState.notFetched.rawValue
        let descriptor = FetchDescriptor<RecipeRecord>(predicate: #Predicate { $0.titleFetchStateValue == notFetched }, sortBy: RecipeRecord.listOrder)
        return try container.makeContext().fetch(descriptor).map(\.recipe).filter(\.needsTitleFetch)
    }

    /// 取得を始める。拒否したサイトへの取得を止めている間と、同じURLを24時間以内に試した場合は、通信せずに「取得失敗」にする。
    /// 停止期限・試行日時を読めないときと、試行日時を書き込めないときは、通信せずに取得を待つ状態のまま残し、次に始めるときに判断し直す
    public func begin(_ recipe: Recipe, now: Date = .now) -> TitleFetchStart {
        guard let site = SupportedSite.fetchableSite(for: recipe.url) else { return .notNeeded }
        let canFetch: Bool
        do {
            canFetch = TitleFetchThrottle.canFetch(
                pausedUntil: try history.pauseEnd(siteID: site.id),
                lastAttempt: try history.lastAttempt(url: recipe.url),
                now: now
            )
        } catch {
            return .notNeeded
        }
        guard canFetch else {
            try? markSkipped(id: recipe.id)
            return .skipped
        }
        guard let fetching = try? markFetching(id: recipe.id) else { return .notNeeded }
        do {
            try history.recordAttempt(url: fetching.url, at: now)
        } catch {
            // 試行日時を残せないと24時間の間隔を守れないため、取得中にした記録を戻す
            try? markAwaiting(id: recipe.id)
            return .notNeeded
        }
        return .fetch(fetching, site)
    }

    /// 取得の結果を反映する。拒否の応答なら、そのサイトへの取得を止める。取得中にURLや本人のタイトルが変わっていれば反映しない
    @discardableResult
    public func finish(_ fetching: Recipe, site: SupportedSite, outcome: TitleFetchOutcome, now: Date = .now) -> Recipe? {
        if case .refused(_, let retryAfter) = outcome {
            try? history.pause(siteID: site.id, until: TitleFetchThrottle.pauseEnd(refusedAt: now, retryAfter: retryAfter))
        }
        return try? apply(outcome, to: fetching, now: now)
    }

    /// 取得中のまま終了した記録を「取得失敗」にする。通信したかが分からないため、いつ起動しても取り直さない
    public func resetInterrupted() throws {
        let context = container.makeContext()
        let fetching = TitleFetchState.fetching.rawValue
        let records = try context.fetch(FetchDescriptor<RecipeRecord>(predicate: #Predicate { $0.titleFetchStateValue == fetching }))
        guard !records.isEmpty else { return }
        records.forEach { $0.titleFetchStateValue = TitleFetchState.failed.rawValue }
        try context.save()
    }

    /// 24時間を過ぎた試行日時と、期限を過ぎた停止を消す
    public func purgeHistory(now: Date = .now) throws {
        try history.purge(now: now)
    }

    // MARK: - 記録の取得の状態

    /// 取得の対象なら「取得中」にして返す
    private func markFetching(id: UUID) throws -> Recipe? {
        let context = container.makeContext()
        guard let record = try context.recipeRecord(id), record.recipe.needsTitleFetch else { return nil }
        record.titleFetchStateValue = TitleFetchState.fetching.rawValue
        try context.save()
        return record.recipe
    }

    /// 取得中にした記録を、取得を待つ状態に戻す
    private func markAwaiting(id: UUID) throws {
        let context = container.makeContext()
        guard let record = try context.recipeRecord(id), record.titleFetchStateValue == TitleFetchState.fetching.rawValue else { return }
        record.titleFetchStateValue = TitleFetchState.notFetched.rawValue
        try context.save()
    }

    /// 取得を待つ記録か取得中の記録を「取得失敗」にする
    private func markSkipped(id: UUID) throws {
        let context = container.makeContext()
        guard let record = try context.recipeRecord(id), record.recipe.needsTitleFetch || record.titleFetchStateValue == TitleFetchState.fetching.rawValue else { return }
        record.titleFetchStateValue = TitleFetchState.failed.rawValue
        try context.save()
    }

    private func apply(_ outcome: TitleFetchOutcome, to fetching: Recipe, now: Date) throws -> Recipe? {
        let context = container.makeContext()
        guard let record = try context.recipeRecord(fetching.id),
              let recipe = RecipeEditing.applying(outcome, to: record.recipe, fetchedURL: fetching.url, now: now)
        else { return nil }
        record.apply(recipe)
        try context.save()
        return recipe
    }
}
