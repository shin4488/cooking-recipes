import Foundation
import SwiftData

/// 保存形式の版1。形式を変えるときは新しい版を足し、RecipeMigrationPlan に移行を書く
public enum RecipeSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [RecipeRecord.self, TrashedRecipeRecord.self, TitleFetchAttempt.self, TitleFetchPause.self]
    }

    /// 一覧・検索の対象になるレシピ
    @Model
    public final class RecipeRecord {
        @Attribute(.unique) public var id: UUID
        public var url: String
        public var title: String?
        public var titleSourceValue: String
        public var titleFetchStateValue: String
        public var tags: [String]
        public var sortKey: Double
        public var createdAt: Date
        public var updatedAt: Date

        init(id: UUID, url: String, title: String?, titleSourceValue: String, titleFetchStateValue: String, tags: [String], sortKey: Double, createdAt: Date, updatedAt: Date) {
            self.id = id
            self.url = url
            self.title = title
            self.titleSourceValue = titleSourceValue
            self.titleFetchStateValue = titleFetchStateValue
            self.tags = tags
            self.sortKey = sortKey
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    /// ごみ箱。削除した記録一式を削除日時とともに移す
    @Model
    public final class TrashedRecipeRecord {
        @Attribute(.unique) public var id: UUID
        public var url: String
        public var title: String?
        public var titleSourceValue: String
        public var titleFetchStateValue: String
        public var tags: [String]
        public var sortKey: Double
        public var createdAt: Date
        public var updatedAt: Date
        public var deletedAt: Date

        init(id: UUID, url: String, title: String?, titleSourceValue: String, titleFetchStateValue: String, tags: [String], sortKey: Double, createdAt: Date, updatedAt: Date, deletedAt: Date) {
            self.id = id
            self.url = url
            self.title = title
            self.titleSourceValue = titleSourceValue
            self.titleFetchStateValue = titleFetchStateValue
            self.tags = tags
            self.sortKey = sortKey
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }
    }

    /// タイトル取得の通信制御のため、URLごとの最終試行日時を24時間だけ持つ
    @Model
    public final class TitleFetchAttempt {
        @Attribute(.unique) public var url: String
        public var attemptedAt: Date

        init(url: String, attemptedAt: Date) {
            self.url = url
            self.attemptedAt = attemptedAt
        }
    }

    /// 取得を拒否したサイトへの取得を再開できる日時
    @Model
    public final class TitleFetchPause {
        @Attribute(.unique) public var siteID: String
        public var until: Date

        init(siteID: String, until: Date) {
            self.siteID = siteID
            self.until = until
        }
    }
}

public typealias RecipeRecord = RecipeSchemaV1.RecipeRecord
public typealias TrashedRecipeRecord = RecipeSchemaV1.TrashedRecipeRecord
public typealias TitleFetchAttempt = RecipeSchemaV1.TitleFetchAttempt
public typealias TitleFetchPause = RecipeSchemaV1.TitleFetchPause

public enum RecipeMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [RecipeSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}
