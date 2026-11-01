import Foundation
import RecipeCore

/// 登録・編集の結果。同じURLの記録があれば保存せず、その記録を返す
public enum RecipeSaveResult: Equatable, Sendable {
    case saved(Recipe)
    case duplicate(RecipeDuplicate)
    case failed

    /// 保存の操作を行い、`RecipeRepository` が投げたエラーを結果に振り分ける
    @MainActor
    public init(_ save: () throws -> Recipe) {
        do {
            self = .saved(try save())
        } catch RecipeRepositoryError.duplicate(let duplicate) {
            self = .duplicate(duplicate)
        } catch {
            self = .failed
        }
    }
}

/// ごみ箱から戻した結果。同じURLの記録が一覧にあれば戻さず、その記録を返す
public enum RecipeRestoreResult: Equatable, Sendable {
    case restored(Recipe)
    case duplicate(Recipe)
    case failed

    /// 戻す操作を行い、`RecipeRepository` が投げたエラーを結果に振り分ける
    @MainActor
    public init(_ restore: () throws -> Recipe) {
        do {
            self = .restored(try restore())
        } catch RecipeRepositoryError.duplicate(.active(let existing)) {
            self = .duplicate(existing)
        } catch {
            self = .failed
        }
    }
}
