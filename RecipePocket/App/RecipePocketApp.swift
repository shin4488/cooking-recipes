import RecipeData
import SwiftUI

@main
struct RecipePocketApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: RecipeStore?
    @State private var openFailed = false
    @State private var wasInBackground = false

    init() {
        AppAnalytics.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let store {
                    RecipeListView()
                        .environment(store)
                        .environment(store.search)
                        .environment(store.toasts)
                } else if openFailed {
                    ContentUnavailableView(
                        "保存データを開けませんでした",
                        systemImage: "exclamationmark.triangle",
                        description: Text("端末の空き容量を確認し、アプリを再起動してください。保存済みのデータは削除していません。")
                    )
                }
            }
            .task {
                openStore()
                // 同意の画面を出せるよう、画面ができてから広告の同意を確かめる
                AppAds.shared.gatherConsent()
            }
            .onChange(of: scenePhase) { _, phase in
                // 裏にある間に共有拡張で保存した記録を、前面に戻ったときに読み込む
                if phase == .background { wasInBackground = true }
                if phase == .active, wasInBackground {
                    wasInBackground = false
                    store?.refresh()
                }
            }
        }
    }

    private func openStore() {
        guard store == nil else { return }
        do {
            let container = try RecipeContainer.shared()
            let repository = RecipeRepository(container: container)
            #if DEBUG
            DebugSeed.insertIfRequested(into: repository)
            #endif
            let store = RecipeStore(repository: repository, titleFetchRepository: TitleFetchRepository(container: container), analytics: .shared)
            self.store = store
            store.refresh()
        } catch {
            openFailed = true
        }
    }
}
