import FirebaseAnalytics
import FirebaseCore
import Foundation
import SwiftUI

/// 解析に送る操作。保存したURL・タイトル・タグ・検索語・記録のIDは送らない
enum AnalyticsEvent {
    case recipeAdded(tagCount: Int)
    case recipeUpdated
    case recipeDeleted
    case recipeRestored
    case recipeDeletedPermanently
    case trashEmptied(count: Int)
    case recipeMoved
    case urlCopied
    case searchConditionAdded(fromTag: Bool)
    case searchCleared

    var name: String {
        switch self {
        case .recipeAdded: "recipe_add"
        case .recipeUpdated: "recipe_update"
        case .recipeDeleted: "recipe_delete"
        case .recipeRestored: "recipe_restore"
        case .recipeDeletedPermanently: "recipe_delete_permanently"
        case .trashEmptied: "trash_empty"
        case .recipeMoved: "recipe_move"
        case .urlCopied: "recipe_url_copy"
        case .searchConditionAdded: "search_condition_add"
        case .searchCleared: "search_clear"
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .recipeAdded(let tagCount): ["tag_count": tagCount]
        case .trashEmptied(let count): ["count": count]
        case .searchConditionAdded(let fromTag): ["source": fromTag ? "tag" : "keyword"]
        default: nil
        }
    }
}

enum AnalyticsScreen: String {
    case recipeList = "recipe_list"
    case recipeAdd = "recipe_add"
    case recipeEdit = "recipe_edit"
    case settings
    case trash
    case supportedSites = "supported_sites"
    case privacy
    case terms
    case licenses
}

/// Google Analytics for Firebase。設定ファイル（GoogleService-Info.plist）を置いたときだけ送信する
@MainActor
final class AppAnalytics {
    static let shared = AppAnalytics()

    private static let enabledKey = "analyticsEnabled"
    private(set) var isAvailable = false

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            applyCollectionSetting()
        }
    }

    func configure() {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        FirebaseApp.configure()
        isAvailable = true
        applyCollectionSetting()
    }

    func log(_ event: AnalyticsEvent) {
        guard isAvailable else { return }
        Analytics.logEvent(event.name, parameters: event.parameters)
    }

    func log(_ screen: AnalyticsScreen) {
        guard isAvailable else { return }
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: screen.rawValue])
    }

    private func applyCollectionSetting() {
        guard isAvailable else { return }
        #if DEBUG
        // 開発中の操作で本番の集計を汚さないよう、DebugView で確かめるとき（-FIRDebugEnabled）だけ送る
        let enabled = isEnabled && ProcessInfo.processInfo.arguments.contains("-FIRDebugEnabled")
        #else
        let enabled = isEnabled
        #endif
        Analytics.setAnalyticsCollectionEnabled(enabled)
    }
}

extension View {
    func analyticsScreen(_ screen: AnalyticsScreen) -> some View {
        onAppear { AppAnalytics.shared.log(screen) }
    }
}
