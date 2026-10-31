import Foundation
import SwiftData

public enum RecipeContainerError: Error {
    case appGroupUnavailable
}

/// 本体と共有拡張が共有する保存先。App Group の中に置き、iOS のデータ保護を適用する
public enum RecipeContainer {
    public static let appGroupIdentifier = "group.com.shin4488.cookingrecipes"

    public static func shared() throws -> ModelContainer {
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw RecipeContainerError.appGroupUnavailable
        }
        let directory = group.appending(path: "Library/Application Support/Recipes", directoryHint: .isDirectory)
        try prepareProtectedDirectory(directory)
        let configuration = ModelConfiguration(
            schema: schema,
            url: directory.appending(path: "Recipes.store"),
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, migrationPlan: RecipeMigrationPlan.self, configurations: configuration)
        try protectExistingFiles(in: directory)
        return container
    }

    public static func inMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: RecipeMigrationPlan.self, configurations: configuration)
    }

    private static var schema: Schema { Schema(versionedSchema: RecipeSchemaV1.self) }

    /// 再起動直後のロック中を除いて読み書きできる保護クラス。共有拡張や本体が裏で保存を終えられるようにする
    private static func prepareProtectedDirectory(_ directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #if os(iOS)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: directory.path(percentEncoded: false)
        )
        #endif
    }

    private static func protectExistingFiles(in directory: URL) throws {
        #if os(iOS)
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: file.path(percentEncoded: false)
            )
        }
        #endif
    }
}
