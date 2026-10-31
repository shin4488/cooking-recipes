import RecipeCore
import RecipeData
import RecipeUI
import SwiftUI

/// 登録・編集画面。広告は表示しない
struct RecipeEditorView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var model: RecipeFormModel
    @State private var duplicate: RecipeDuplicate?
    @State private var showsDiscardConfirmation = false
    @State private var saveFailed = false

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
                            .disabled(model.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .confirmationDialog("入力した内容を破棄しますか？", isPresented: $showsDiscardConfirmation, titleVisibility: .visible) {
                    Button("破棄する", role: .destructive) { dismiss() }
                    Button("編集を続ける", role: .cancel) {}
                }
                .alert(duplicateTitle, isPresented: duplicateBinding, presenting: duplicate) { duplicate in
                    duplicateActions(duplicate)
                } message: { duplicate in
                    Text(duplicateMessage(duplicate))
                }
                .alert("保存できませんでした", isPresented: $saveFailed) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("入力した内容は残っています。もう一度お試しください。")
                }
        }
        .interactiveDismissDisabled(model.hasChanges)
        .analyticsScreen(model.isEditing ? .recipeEdit : .recipeAdd)
    }

    private func save() {
        guard let output = model.makeOutput() else { return }
        let result: SaveResult
        switch model.mode {
        case .add: result = store.add(output)
        case .edit(let recipe): result = store.update(recipe, with: output)
        }
        switch result {
        case .saved: dismiss()
        case .duplicate(let found): duplicate = found
        case .failed: saveFailed = true
        }
    }

    private var duplicateBinding: Binding<Bool> {
        Binding { duplicate != nil } set: { if !$0 { duplicate = nil } }
    }

    private var duplicateTitle: String {
        switch duplicate {
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

    @ViewBuilder
    private func duplicateActions(_ duplicate: RecipeDuplicate) -> some View {
        switch duplicate {
        case .active(let recipe):
            Button("登録済みのレシピを表示") {
                dismiss()
                store.focus(on: recipe)
            }
            Button("入力に戻る", role: .cancel) {}
        case .trashed(let trashed):
            Button("ごみ箱から戻す") {
                if case .restored(let recipe) = store.restore(trashed) {
                    dismiss()
                    store.focus(on: recipe)
                } else {
                    saveFailed = true
                }
            }
            Button("取消", role: .cancel) {}
        }
    }
}
