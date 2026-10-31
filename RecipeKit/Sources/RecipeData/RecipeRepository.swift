import Foundation
import RecipeCore
import SwiftData

public enum RecipeDuplicate: Equatable, Sendable {
    case active(Recipe)
    case trashed(TrashedRecipe)
}

public enum RecipeRepositoryError: Error, Equatable {
    case duplicate(RecipeDuplicate)
    case notFound
}

/// 端末内の記録の読み書き。本体と共有拡張が同時に保存するため、操作ごとに新しいコンテキストで最新の内容を読み、1回の保存で反映する
@MainActor
public final class RecipeRepository {
    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    // MARK: - 読み込み

    /// 並び順（小さい順）、同じ値なら新しい順
    public func recipes() throws -> [Recipe] {
        let descriptor = FetchDescriptor<RecipeRecord>(sortBy: [SortDescriptor(\.sortKey), SortDescriptor(\.createdAt, order: .reverse)])
        return try makeContext().fetch(descriptor).map(Recipe.init)
    }

    /// 削除が新しい順
    public func trashedRecipes() throws -> [TrashedRecipe] {
        let descriptor = FetchDescriptor<TrashedRecipeRecord>(sortBy: [SortDescriptor(\.deletedAt, order: .reverse)])
        return try makeContext().fetch(descriptor).map(TrashedRecipe.init)
    }

    /// 一覧の記録に付いているタグ。ごみ箱の記録だけに付いているタグは含めない
    public func savedTags() throws -> [String] {
        var descriptor = FetchDescriptor<RecipeRecord>()
        descriptor.propertiesToFetch = [\.tags]
        var seen = Set<String>()
        var result: [String] = []
        for record in try makeContext().fetch(descriptor) {
            for tag in record.tags where seen.insert(tag).inserted {
                result.append(tag)
            }
        }
        return result
    }

    /// 同じURL（前後の空白・スキームとホストの大小文字・既定ポートの違いを除く）の記録
    public func duplicate(of url: String, excluding id: UUID? = nil) throws -> RecipeDuplicate? {
        try duplicate(of: url, excluding: id, in: makeContext())
    }

    // MARK: - 登録・編集

    @discardableResult
    public func add(url: String, title: TitleInput, tags: [String], now: Date = .now) throws -> Recipe {
        let context = makeContext()
        if let duplicate = try duplicate(of: url, excluding: nil, in: context) {
            throw RecipeRepositoryError.duplicate(duplicate)
        }
        var first = FetchDescriptor<RecipeRecord>(sortBy: [SortDescriptor(\.sortKey)])
        first.fetchLimit = 1
        let minimum = try context.fetch(first).first?.sortKey
        let recipe = RecipeEditing.newRecipe(url: url, title: title, tags: tags, sortKey: SortOrder.keyForNewItem(currentMinimum: minimum), now: now)
        context.insert(RecipeRecord(recipe))
        try context.save()
        return recipe
    }

    @discardableResult
    public func update(id: UUID, url: String, title: TitleInput, tags: [String], now: Date = .now) throws -> Recipe {
        let context = makeContext()
        guard let record = try record(id, in: context) else { throw RecipeRepositoryError.notFound }
        if let duplicate = try duplicate(of: url, excluding: id, in: context) {
            throw RecipeRepositoryError.duplicate(duplicate)
        }
        let recipe = RecipeEditing.updated(Recipe(record), url: url, title: title, tags: tags, now: now)
        record.apply(recipe)
        try context.save()
        return recipe
    }

    /// 上下の記録の間に移す。間が詰まっていれば全体の並び順を振り直す
    public func move(id: UUID, above: UUID?, below: UUID?) throws {
        let context = makeContext()
        guard let record = try record(id, in: context) else { throw RecipeRepositoryError.notFound }
        let aboveKey = try above.flatMap { try self.record($0, in: context)?.sortKey }
        let belowKey = try below.flatMap { try self.record($0, in: context)?.sortKey }
        if let key = SortOrder.keyBetween(above: aboveKey, below: belowKey) {
            record.sortKey = key
        } else {
            var ordered = try context.fetch(FetchDescriptor<RecipeRecord>(sortBy: [SortDescriptor(\.sortKey), SortDescriptor(\.createdAt, order: .reverse)]))
            ordered.removeAll { $0.id == id }
            let index = below.flatMap { below in ordered.firstIndex { $0.id == below } }
                ?? above.flatMap { above in ordered.firstIndex { $0.id == above }.map { $0 + 1 } }
                ?? ordered.endIndex
            ordered.insert(record, at: index)
            for (offset, item) in ordered.enumerated() {
                item.sortKey = Double(offset)
            }
        }
        try context.save()
    }

    // MARK: - ごみ箱

    /// 記録一式をごみ箱へ移す。移動は1回の保存で行い、失敗したら移動前の状態のまま
    public func moveToTrash(id: UUID, now: Date = .now) throws {
        let context = makeContext()
        guard let record = try record(id, in: context) else { throw RecipeRepositoryError.notFound }
        context.insert(TrashedRecipeRecord(TrashedRecipe(recipe: Recipe(record), deletedAt: now)))
        context.delete(record)
        try context.save()
    }

    /// 元の並び順の位置に戻す。同じURLの記録が一覧にあれば戻さない
    @discardableResult
    public func restore(id: UUID) throws -> Recipe {
        let context = makeContext()
        guard let trashed = try trashedRecord(id, in: context) else { throw RecipeRepositoryError.notFound }
        let recipe = TrashedRecipe(trashed).recipe
        if let duplicate = try activeDuplicate(of: recipe.url, excluding: nil, in: context) {
            throw RecipeRepositoryError.duplicate(.active(duplicate))
        }
        context.insert(RecipeRecord(recipe))
        context.delete(trashed)
        try context.save()
        return recipe
    }

    public func deletePermanently(id: UUID) throws {
        let context = makeContext()
        guard let trashed = try trashedRecord(id, in: context) else { throw RecipeRepositoryError.notFound }
        context.delete(trashed)
        try context.save()
    }

    @discardableResult
    public func emptyTrash() throws -> Int {
        let context = makeContext()
        let records = try context.fetch(FetchDescriptor<TrashedRecipeRecord>())
        for item in records { context.delete(item) }
        try context.save()
        return records.count
    }

    /// 削除日時から30日を過ぎた記録を完全に削除する
    @discardableResult
    public func purgeExpiredTrash(now: Date = .now) throws -> Int {
        let context = makeContext()
        let records = try context.fetch(FetchDescriptor<TrashedRecipeRecord>()).filter {
            TrashPolicy.isExpired(deletedAt: $0.deletedAt, now: now)
        }
        for item in records { context.delete(item) }
        try context.save()
        return records.count
    }

    // MARK: - タイトルの自動取得

    /// 本体がタイトルを自動取得する記録。一覧の並び順で返す
    public func recipesAwaitingTitleFetch() throws -> [Recipe] {
        let notFetched = TitleFetchState.notFetched.rawValue
        let descriptor = FetchDescriptor<RecipeRecord>(
            predicate: #Predicate { $0.titleFetchStateValue == notFetched },
            sortBy: [SortDescriptor(\.sortKey), SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try makeContext().fetch(descriptor).map(Recipe.init).filter(\.needsTitleFetch)
    }

    /// 取得の対象なら「取得中」にして返す
    public func beginTitleFetch(id: UUID, now: Date = .now) throws -> Recipe? {
        let context = makeContext()
        guard let record = try record(id, in: context), Recipe(record).needsTitleFetch else { return nil }
        record.titleFetchStateValue = TitleFetchState.fetching.rawValue
        try context.save()
        return Recipe(record)
    }

    /// 取得の結果を反映する。取得中にURLや本人のタイトルが変わっていれば反映しない
    @discardableResult
    public func finishTitleFetch(id: UUID, url: String, outcome: TitleFetchOutcome, now: Date = .now) throws -> Recipe? {
        let context = makeContext()
        guard let record = try record(id, in: context),
              let recipe = RecipeEditing.applying(outcome, to: Recipe(record), fetchedURL: url, now: now)
        else { return nil }
        record.apply(recipe)
        try context.save()
        return recipe
    }

    /// 通信制御のため取得しない記録を「取得失敗」にする
    public func skipTitleFetch(id: UUID) throws {
        let context = makeContext()
        guard let record = try record(id, in: context), Recipe(record).needsTitleFetch || record.titleFetchStateValue == TitleFetchState.fetching.rawValue else { return }
        record.titleFetchStateValue = TitleFetchState.failed.rawValue
        try context.save()
    }

    /// 取得中のまま終了した記録を、取得を待つ状態に戻す
    public func resetInterruptedTitleFetches() throws {
        let context = makeContext()
        let fetching = TitleFetchState.fetching.rawValue
        let records = try context.fetch(FetchDescriptor<RecipeRecord>(predicate: #Predicate { $0.titleFetchStateValue == fetching }))
        guard !records.isEmpty else { return }
        records.forEach { $0.titleFetchStateValue = TitleFetchState.notFetched.rawValue }
        try context.save()
    }

    public func lastTitleFetchAttempt(url: String) throws -> Date? {
        try makeContext().fetch(FetchDescriptor<TitleFetchAttempt>(predicate: #Predicate { $0.url == url })).first?.attemptedAt
    }

    public func recordTitleFetchAttempt(url: String, at date: Date) throws {
        let context = makeContext()
        if let attempt = try context.fetch(FetchDescriptor<TitleFetchAttempt>(predicate: #Predicate { $0.url == url })).first {
            attempt.attemptedAt = date
        } else {
            context.insert(TitleFetchAttempt(url: url, attemptedAt: date))
        }
        try context.save()
    }

    public func titleFetchPause(siteID: String) throws -> Date? {
        try makeContext().fetch(FetchDescriptor<TitleFetchPause>(predicate: #Predicate { $0.siteID == siteID })).first?.until
    }

    public func pauseTitleFetch(siteID: String, until: Date) throws {
        let context = makeContext()
        if let pause = try context.fetch(FetchDescriptor<TitleFetchPause>(predicate: #Predicate { $0.siteID == siteID })).first {
            pause.until = max(pause.until, until)
        } else {
            context.insert(TitleFetchPause(siteID: siteID, until: until))
        }
        try context.save()
    }

    /// 24時間を過ぎた試行日時と、期限を過ぎた停止を消す
    public func purgeTitleFetchHistory(now: Date = .now) throws {
        let context = makeContext()
        let attempts = try context.fetch(FetchDescriptor<TitleFetchAttempt>()).filter {
            TitleFetchThrottle.canAttempt(lastAttempt: $0.attemptedAt, now: now)
        }
        let pauses = try context.fetch(FetchDescriptor<TitleFetchPause>()).filter { $0.until <= now }
        guard !attempts.isEmpty || !pauses.isEmpty else { return }
        for item in attempts { context.delete(item) }
        for item in pauses { context.delete(item) }
        try context.save()
    }

    #if DEBUG
    /// 件数の多い状態を確かめるための見本。重複判定をせずに1回の保存でまとめて入れる
    public func insertSamples(count: Int, make: (Int) -> (url: String, title: String?, tags: [String])) throws {
        let context = makeContext()
        let now = Date.now
        for index in 0..<count {
            let sample = make(index)
            let recipe = RecipeEditing.newRecipe(
                url: sample.url,
                title: sample.title.map(TitleInput.manual) ?? .none,
                tags: sample.tags,
                sortKey: Double(index),
                now: now.addingTimeInterval(-Double(index))
            )
            context.insert(RecipeRecord(recipe))
        }
        try context.save()
    }
    #endif

    // MARK: - 内部

    private func makeContext() -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func record(_ id: UUID, in context: ModelContext) throws -> RecipeRecord? {
        try context.fetch(FetchDescriptor<RecipeRecord>(predicate: #Predicate { $0.id == id })).first
    }

    private func trashedRecord(_ id: UUID, in context: ModelContext) throws -> TrashedRecipeRecord? {
        try context.fetch(FetchDescriptor<TrashedRecipeRecord>(predicate: #Predicate { $0.id == id })).first
    }

    private func duplicate(of url: String, excluding id: UUID?, in context: ModelContext) throws -> RecipeDuplicate? {
        if let active = try activeDuplicate(of: url, excluding: id, in: context) {
            return .active(active)
        }
        let key = RecipeURL.duplicateKey(for: url)
        let trashed = try context.fetch(FetchDescriptor<TrashedRecipeRecord>(sortBy: [SortDescriptor(\.deletedAt, order: .reverse)]))
        return trashed.first { $0.id != id && RecipeURL.duplicateKey(for: $0.url) == key }.map { .trashed(TrashedRecipe($0)) }
    }

    private func activeDuplicate(of url: String, excluding id: UUID?, in context: ModelContext) throws -> Recipe? {
        let key = RecipeURL.duplicateKey(for: url)
        var descriptor = FetchDescriptor<RecipeRecord>()
        descriptor.propertiesToFetch = [\.id, \.url]
        return try context.fetch(descriptor)
            .first { $0.id != id && RecipeURL.duplicateKey(for: $0.url) == key }
            .map(Recipe.init)
    }
}

extension Recipe {
    init(_ record: RecipeRecord) {
        self.init(
            id: record.id,
            url: record.url,
            title: record.title,
            titleSource: TitleSource(rawValue: record.titleSourceValue) ?? .none,
            titleFetchState: TitleFetchState(rawValue: record.titleFetchStateValue) ?? .notFetched,
            tags: record.tags,
            sortKey: record.sortKey,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }
}

extension TrashedRecipe {
    init(_ record: TrashedRecipeRecord) {
        self.init(
            recipe: Recipe(
                id: record.id,
                url: record.url,
                title: record.title,
                titleSource: TitleSource(rawValue: record.titleSourceValue) ?? .none,
                titleFetchState: TitleFetchState(rawValue: record.titleFetchStateValue) ?? .notFetched,
                tags: record.tags,
                sortKey: record.sortKey,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            ),
            deletedAt: record.deletedAt
        )
    }
}

extension RecipeRecord {
    convenience init(_ recipe: Recipe) {
        self.init(
            id: recipe.id,
            url: recipe.url,
            title: recipe.title,
            titleSourceValue: recipe.titleSource.rawValue,
            titleFetchStateValue: recipe.titleFetchState.rawValue,
            tags: recipe.tags,
            sortKey: recipe.sortKey,
            createdAt: recipe.createdAt,
            updatedAt: recipe.updatedAt
        )
    }

    func apply(_ recipe: Recipe) {
        url = recipe.url
        title = recipe.title
        titleSourceValue = recipe.titleSource.rawValue
        titleFetchStateValue = recipe.titleFetchState.rawValue
        tags = recipe.tags
        sortKey = recipe.sortKey
        updatedAt = recipe.updatedAt
    }
}

extension TrashedRecipeRecord {
    convenience init(_ trashed: TrashedRecipe) {
        let recipe = trashed.recipe
        self.init(
            id: recipe.id,
            url: recipe.url,
            title: recipe.title,
            titleSourceValue: recipe.titleSource.rawValue,
            titleFetchStateValue: recipe.titleFetchState.rawValue,
            tags: recipe.tags,
            sortKey: recipe.sortKey,
            createdAt: recipe.createdAt,
            updatedAt: recipe.updatedAt,
            deletedAt: trashed.deletedAt
        )
    }
}
