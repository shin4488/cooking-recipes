import RecipeCore
import RecipeData
import RecipeUI
import SwiftUI

/// 共有から受け取ったURL・タイトル・タグを確認して保存する
struct ShareRecipeView: View {
    let model: RecipeFormModel
    let repository: RecipeRepository
    let onFinish: () -> Void
    let onCancel: () -> Void

    @State private var alerts = RecipeSaveAlerts()
    @State private var saved = false

    var body: some View {
        NavigationStack {
            RecipeFormView(model: model, showsPasteButton: false)
                .navigationTitle("レシピぽけっとに保存")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル", action: onCancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存", action: save)
                            .disabled(saved || !model.canSave)
                    }
                }
                .overlay {
                    if saved {
                        Label("保存しました", systemImage: "checkmark.circle.fill")
                            .font(.title3.bold())
                            .padding(24)
                            .background(.regularMaterial, in: .rect(cornerRadius: 16))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .recipeSaveAlerts(alerts) { _ in
                    Button("共有を閉じる", action: onCancel)
                } restore: { trashed in
                    RecipeRestoreResult { try repository.restore(id: trashed.id) }
                } restored: { _ in
                    showSavedAndFinish()
                }
        }
    }

    private func save() {
        guard let output = model.makeOutput() else { return }
        let result = RecipeSaveResult { try repository.add(url: output.url, title: output.title, tags: output.tags) }
        alerts.show(result)
        if case .saved = result { showSavedAndFinish() }
    }

    private func showSavedAndFinish() {
        withAnimation { saved = true }
        AccessibilityNotification.Announcement("保存しました").post()
        Task {
            try? await Task.sleep(for: .seconds(0.8))
            onFinish()
        }
    }
}

/// 保存できないときの案内
struct ShareMessageView: View {
    let message: String
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ContentUnavailableView("保存できません", systemImage: "link.badge.plus", description: Text(message))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる", action: onClose)
                    }
                }
        }
    }
}
