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

/// 一覧とごみ箱の記録の読み書き。本体と共有拡張の両方が使う。タイトルの自動取得に使う記録は TitleFetchRepository が扱う
@MainActor
public final class RecipeRepository {
    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    // MARK: - 読み込み

    /// 並び順（小さい順）、同じ値なら新しい順
    public func recipes() throws -> [Recipe] {
        try container.makeContext().fetch(FetchDescriptor(sortBy: RecipeRecord.listOrder)).map(\.recipe)
    }

    /// 削除が新しい順
    public func trashedRecipes() throws -> [TrashedRecipe] {
        try container.makeContext().fetch(FetchDescriptor(sortBy: TrashedRecipeRecord.trashOrder)).map(\.trashedRecipe)
    }

    /// 一覧の記録に付いているタグ。ごみ箱の記録だけに付いているタグは含めない
    public func savedTags() throws -> [String] {
        var descriptor = FetchDescriptor<RecipeRecord>()
        descriptor.propertiesToFetch = [\.tags]
        var seen = Set<String>()
        var result: [String] = []
        for record in try container.makeContext().fetch(descriptor) {
            for tag in record.tags where seen.insert(tag).inserted {
                result.append(tag)
            }
        }
        return result
    }

    /// 同じURL（前後の空白・スキームとホストの大小文字・既定ポートの違いを除く）の記録
    public func duplicate(of url: String, excluding id: UUID? = nil) throws -> RecipeDuplicate? {
        try duplicate(of: url, excluding: id, in: container.makeContext())
    }

    // MARK: - 登録・編集

    @discardableResult
    public func add(url: String, title: TitleInput, tags: [String], now: Date = .now) throws -> Recipe {
        let context = container.makeContext()
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
        let context = container.makeContext()
        guard let record = try context.recipeRecord(id) else { throw RecipeRepositoryError.notFound }
        if let duplicate = try duplicate(of: url, excluding: id, in: context) {
            throw RecipeRepositoryError.duplicate(duplicate)
        }
        let recipe = RecipeEditing.updated(record.recipe, url: url, title: title, tags: tags, now: now)
        record.apply(recipe)
        try context.save()
        return recipe
    }

    /// 上下の記録の間に移す。間が詰まっていれば全体の並び順を振り直す
    public func move(id: UUID, above: UUID?, below: UUID?) throws {
        let context = container.makeContext()
        guard let record = try context.recipeRecord(id) else { throw RecipeRepositoryError.notFound }
        let aboveKey = try above.flatMap { try context.recipeRecord($0)?.sortKey }
        let belowKey = try below.flatMap { try context.recipeRecord($0)?.sortKey }
        if let key = SortOrder.keyBetween(above: aboveKey, below: belowKey) {
            record.sortKey = key
        } else {
            var ordered = try context.fetch(FetchDescriptor(sortBy: RecipeRecord.listOrder))
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
        let context = container.makeContext()
        guard let record = try context.recipeRecord(id) else { throw RecipeRepositoryError.notFound }
        context.insert(TrashedRecipeRecord(TrashedRecipe(recipe: record.recipe, deletedAt: now)))
        context.delete(record)
        try context.save()
    }

    /// 元の並び順の位置に戻す。同じURLの記録が一覧にあれば戻さない
    @discardableResult
    public func restore(id: UUID) throws -> Recipe {
        let context = container.makeContext()
        guard let trashed = try trashedRecord(id, in: context) else { throw RecipeRepositoryError.notFound }
        let recipe = trashed.recipe
        if let duplicate = try activeDuplicate(of: recipe.url, excluding: nil, in: context) {
            throw RecipeRepositoryError.duplicate(.active(duplicate))
        }
        context.insert(RecipeRecord(recipe))
        context.delete(trashed)
        try context.save()
        return recipe
    }

    public func deletePermanently(id: UUID) throws {
        let context = container.makeContext()
        guard let trashed = try trashedRecord(id, in: context) else { throw RecipeRepositoryError.notFound }
        context.delete(trashed)
        try context.save()
    }

    @discardableResult
    public func emptyTrash() throws -> Int {
        let context = container.makeContext()
        let records = try context.fetch(FetchDescriptor<TrashedRecipeRecord>())
        for item in records { context.delete(item) }
        try context.save()
        return records.count
    }

    /// 削除日時から30日を過ぎた記録を完全に削除する
    @discardableResult
    public func purgeExpiredTrash(now: Date = .now) throws -> Int {
        let context = container.makeContext()
        let records = try context.fetch(FetchDescriptor<TrashedRecipeRecord>()).filter {
            TrashPolicy.isExpired(deletedAt: $0.deletedAt, now: now)
        }
        for item in records { context.delete(item) }
        try context.save()
        return records.count
    }

    #if DEBUG
    /// 件数の多い状態を確かめるための見本。重複判定をせずに1回の保存でまとめて入れる
    public func insertSamples(count: Int, make: (Int) -> (url: String, title: String?, tags: [String])) throws {
        let context = container.makeContext()
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

    private func trashedRecord(_ id: UUID, in context: ModelContext) throws -> TrashedRecipeRecord? {
        try context.fetch(FetchDescriptor<TrashedRecipeRecord>(predicate: #Predicate { $0.id == id })).first
    }

    private func duplicate(of url: String, excluding id: UUID?, in context: ModelContext) throws -> RecipeDuplicate? {
        if let active = try activeDuplicate(of: url, excluding: id, in: context) {
            return .active(active)
        }
        let key = RecipeURL.duplicateKey(for: url)
        let trashed = try context.fetch(FetchDescriptor(sortBy: TrashedRecipeRecord.trashOrder))
        return trashed.first { $0.id != id && RecipeURL.duplicateKey(for: $0.url) == key }.map { .trashed($0.trashedRecipe) }
    }

    private func activeDuplicate(of url: String, excluding id: UUID?, in context: ModelContext) throws -> Recipe? {
        let key = RecipeURL.duplicateKey(for: url)
        var descriptor = FetchDescriptor<RecipeRecord>()
        descriptor.propertiesToFetch = [\.id, \.url]
        return try context.fetch(descriptor)
            .first { $0.id != id && RecipeURL.duplicateKey(for: $0.url) == key }
            .map(\.recipe)
    }
}
