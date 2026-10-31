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

    @State private var duplicate: RecipeDuplicate?
    @State private var saved = false
    @State private var saveFailed = false

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
                            .disabled(saved || model.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                .alert(duplicateTitle, isPresented: duplicateBinding, presenting: duplicate) { duplicate in
                    switch duplicate {
                    case .active:
                        Button("共有を閉じる", action: onCancel)
                        Button("入力に戻る", role: .cancel) {}
                    case .trashed(let trashed):
                        Button("ごみ箱から戻す") { restore(trashed) }
                        Button("取消", role: .cancel) {}
                    }
                } message: { duplicate in
                    switch duplicate {
                    case .active(let recipe):
                        Text("「\(recipe.displayTitle)」として保存されています。この内容は保存していません。")
                    case .trashed(let trashed):
                        Text("「\(trashed.recipe.displayTitle)」をごみ箱から戻すか、取り消してください。戻す場合、この画面で入力した内容は保存しません。")
                    }
                }
                .alert("保存できませんでした", isPresented: $saveFailed) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("入力した内容は残っています。もう一度お試しください。")
                }
        }
    }

    private var duplicateTitle: String {
        switch duplicate {
        case .trashed: "同じURLのレシピがごみ箱にあります"
        default: "同じURLのレシピが登録済みです"
        }
    }

    private var duplicateBinding: Binding<Bool> {
        Binding { duplicate != nil } set: { if !$0 { duplicate = nil } }
    }

    private func save() {
        guard let output = model.makeOutput() else { return }
        do {
            try repository.add(url: output.url, title: output.title, tags: output.tags)
            showSavedAndFinish()
        } catch RecipeRepositoryError.duplicate(let found) {
            duplicate = found
        } catch {
            saveFailed = true
        }
    }

    private func restore(_ trashed: TrashedRecipe) {
        do {
            try repository.restore(id: trashed.id)
            showSavedAndFinish()
        } catch {
            saveFailed = true
        }
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
