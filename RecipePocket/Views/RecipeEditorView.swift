import RecipeCore
import RecipeData
import RecipeUI
import SwiftUI

/// 登録・編集画面。広告は表示しない
struct RecipeEditorView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(SearchStore.self) private var search
    @Environment(\.dismiss) private var dismiss
    @State private var model: RecipeFormModel
    @State private var alerts = RecipeSaveAlerts()
    @State private var showsDiscardConfirmation = false

    init(target: EditorTarget, savedTags: [String]) {
        switch target {
        case .add:
            _model = State(initialValue: RecipeFormModel(urlChoices: [], sharedTitle: nil, savedTags: savedTags))
        case .edit(let recipe):
            _model = State(initialValue: RecipeFormModel(editing: recipe, savedTags: savedTags))
        }
    }

    var body: some View {
        NavigationStack {
            RecipeFormView(model: model, showsPasteButton: true)
                .navigationTitle(model.isEditing ? "レシピを編集" : "レシピを追加")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            if model.hasChanges { showsDiscardConfirmation = true } else { dismiss() }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存", action: save)
                            .disabled(!model.canSave)
                    }
                }
                .confirmationDialog("入力した内容を破棄しますか？", isPresented: $showsDiscardConfirmation, titleVisibility: .visible) {
                    Button("破棄する", role: .destructive) { dismiss() }
                    Button("編集を続ける", role: .cancel) {}
                }
                .recipeSaveAlerts(alerts) { recipe in
                    Button("登録済みのレシピを表示") { show(recipe) }
                } restore: {
                    store.restore($0)
                } restored: { recipe in
                    show(recipe)
                }
        }
        .interactiveDismissDisabled(model.hasChanges)
        .analyticsScreen(model.isEditing ? .recipeEdit : .recipeAdd)
    }

    private func save() {
        guard let output = model.makeOutput() else { return }
        let result = switch model.mode {
        case .add: store.add(output)
        case .edit(let recipe): store.update(recipe, with: output)
        }
        alerts.show(result)
        if case .saved = result { dismiss() }
    }

    /// 画面を閉じ、一覧でその記録の表示位置を合わせる
    private func show(_ recipe: Recipe) {
        dismiss()
        search.focus(on: recipe)
    }
}
