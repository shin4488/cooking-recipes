import Observation
import RecipeCore
import RecipeData
import SwiftUI

/// 保存できなかったときに出す確認の状態。同じURLの記録があるときと、保存に失敗したとき。
/// 同じURLの確認で「ごみ箱から戻す」を選んで戻せなかったときは、その確認を閉じる操作と、失敗の確認を出す操作が続けて起きる。
/// 片方の書き込みでもう片方の値を上書きしないよう、2つの状態を値の型にまとめずに別々に持つ
@MainActor
@Observable
public final class RecipeSaveAlerts {
    var duplicate: RecipeDuplicate?
    var saveFailed = false

    public init() {}

    /// 保存の結果を受け取り、保存できなかったときは確認を出す
    public func show(_ result: RecipeSaveResult) {
        switch result {
        case .saved: break
        case .duplicate(let found): duplicate = found
        case .failed: saveFailed = true
        }
    }
}

extension View {
    /// 同じURLの記録があるときと、保存できなかったときの確認。本体の登録・編集画面と共有拡張で、同じ文言と分岐を使う。
    /// 同じURLの記録が一覧にあるときの操作（`activeAction`）、ごみ箱から戻す操作（`restore`）と戻せた後の処理（`restored`）は、画面ごとに渡す。
    /// 戻せなかったときは、保存できなかったときと同じ確認を出す
    public func recipeSaveAlerts<ActiveAction: View>(
        _ alerts: RecipeSaveAlerts,
        @ViewBuilder activeAction: @escaping (Recipe) -> ActiveAction,
        restore: @escaping (TrashedRecipe) -> RecipeRestoreResult,
        restored: @escaping (Recipe) -> Void
    ) -> some View {
        modifier(RecipeSaveAlertsModifier(alerts: alerts, activeAction: activeAction, restore: restore, restored: restored))
    }
}

private struct RecipeSaveAlertsModifier<ActiveAction: View>: ViewModifier {
    @Bindable var alerts: RecipeSaveAlerts
    let activeAction: (Recipe) -> ActiveAction
    let restore: (TrashedRecipe) -> RecipeRestoreResult
    let restored: (Recipe) -> Void

    func body(content: Content) -> some View {
        content
            .alert(duplicateTitle, isPresented: duplicateBinding, presenting: alerts.duplicate) { duplicate in
                switch duplicate {
                case .active(let recipe):
                    activeAction(recipe)
                    Button("入力に戻る", role: .cancel) {}
                case .trashed(let trashed):
                    Button("ごみ箱から戻す") {
                        if case .restored(let recipe) = restore(trashed) {
                            restored(recipe)
                        } else {
                            alerts.saveFailed = true
                        }
                    }
                    Button("取消", role: .cancel) {}
                }
            } message: { duplicate in
                Text(duplicateMessage(duplicate))
            }
            .alert("保存できませんでした", isPresented: $alerts.saveFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("入力した内容は残っています。もう一度お試しください。")
            }
    }

    private var duplicateBinding: Binding<Bool> {
        Binding { alerts.duplicate != nil } set: { if !$0 { alerts.duplicate = nil } }
    }

    private var duplicateTitle: String {
        switch alerts.duplicate {
        case .trashed: "同じURLのレシピがごみ箱にあります"
        default: "同じURLのレシピが登録済みです"
        }
    }

    private func duplicateMessage(_ duplicate: RecipeDuplicate) -> String {
        switch duplicate {
        case .active(let recipe):
            "「\(recipe.displayTitle)」として保存されています。この内容は保存していません。"
        case .trashed(let trashed):
            "「\(trashed.recipe.displayTitle)」をごみ箱から戻すか、取り消してください。戻す場合、この画面で入力した内容は保存しません。"
        }
    }
}
