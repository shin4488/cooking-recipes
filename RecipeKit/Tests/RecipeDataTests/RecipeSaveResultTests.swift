import Foundation
import RecipeCore
import SwiftData
import Testing
@testable import RecipeData

@MainActor
@Suite("保存とごみ箱から戻す操作の結果")
struct RecipeSaveResultTests {
    private let container: ModelContainer
    private let repository: RecipeRepository
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    init() throws {
        container = try RecipeContainer.inMemory()
        repository = RecipeRepository(container: container)
    }

    @Test("保存できたら、保存した記録を返す")
    func saved() throws {
        let result = RecipeSaveResult { try repository.add(url: "https://example.com/a", title: .manual("肉じゃが"), tags: ["主菜"], now: now) }
        let recipes = try repository.recipes()
        #expect(recipes.count == 1)
        #expect(result == .saved(try #require(recipes.first)))
    }

    @Test("同じURLの記録が一覧にあれば、その記録を返す")
    func duplicateActive() throws {
        let existing = try repository.add(url: "https://example.com/a", title: .none, tags: [], now: now)
        let result = RecipeSaveResult { try repository.add(url: "https://EXAMPLE.com/a", title: .manual("別名"), tags: [], now: now) }
        #expect(result == .duplicate(.active(existing)))
    }

    @Test("同じURLの記録がごみ箱にあれば、ごみ箱の記録を返す")
    func duplicateTrashed() throws {
        let existing = try repository.add(url: "https://example.com/a", title: .none, tags: [], now: now)
        try repository.moveToTrash(id: existing.id, now: now)
        let result = RecipeSaveResult { try repository.add(url: "https://example.com/a", title: .none, tags: [], now: now) }
        #expect(result == .duplicate(.trashed(TrashedRecipe(recipe: existing, deletedAt: now))))
    }

    @Test("同じURLの記録があること以外のエラーは、失敗にする")
    func failed() {
        #expect(RecipeSaveResult { try repository.update(id: UUID(), url: "https://example.com/a", title: .unchanged, tags: [], now: now) } == .failed)
        #expect(RecipeSaveResult { throw CocoaError(.fileWriteUnknown) } == .failed)
    }

    @Test("ごみ箱から戻せたら、戻した記録を返す")
    func restored() throws {
        let recipe = try repository.add(url: "https://example.com/a", title: .none, tags: [], now: now)
        try repository.moveToTrash(id: recipe.id, now: now)
        #expect(RecipeRestoreResult { try repository.restore(id: recipe.id) } == .restored(recipe))
        #expect(try repository.trashedRecipes().isEmpty)
    }

    @Test("同じURLの記録が一覧にあれば、戻さずにその記録を返す")
    func restoreDuplicate() throws {
        let original = try repository.add(url: "https://example.com/a", title: .none, tags: [], now: now)
        try repository.moveToTrash(id: original.id, now: now)
        // 登録時はごみ箱との重複も止めるため、共有拡張が同時に保存した場合を直接作る
        let concurrent = Recipe(id: UUID(), url: "https://example.com/a", title: nil, titleSource: .none, titleFetchState: .unsupported, tags: [], sortKey: 0, createdAt: now, updatedAt: now)
        let context = ModelContext(container)
        context.insert(RecipeRecord(concurrent))
        try context.save()
        #expect(RecipeRestoreResult { try repository.restore(id: original.id) } == .duplicate(concurrent))
        #expect(try repository.trashedRecipes().count == 1)
    }

    @Test("ごみ箱にない記録を戻そうとしたときや、一覧にある記録との重複以外のエラーは、失敗にする")
    func restoreFailed() throws {
        #expect(RecipeRestoreResult { try repository.restore(id: UUID()) } == .failed)
        let trashed = TrashedRecipe(recipe: try repository.add(url: "https://example.com/a", title: .none, tags: [], now: now), deletedAt: now)
        #expect(RecipeRestoreResult { throw RecipeRepositoryError.duplicate(.trashed(trashed)) } == .failed)
    }
}
