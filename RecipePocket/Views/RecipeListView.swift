import RecipeCore
import RecipeUI
import SwiftUI
import UIKit

/// レシピ一覧。検索・並べ替え・各操作の起点
struct RecipeListView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(SearchStore.self) private var search
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.openURL) private var openURL
    @State private var editor: RecipeFormModel.Mode?
    @State private var showsSettings = false
    @State private var isReordering = false
    @State private var expandedTagIDs: Set<UUID> = []
    @State private var highlightedID: UUID?
    @State private var isKeyboardVisible = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                recipeList
                    .onChange(of: search.focusedRecipeID) { _, id in
                        guard let id else { return }
                        withAnimation { proxy.scrollTo(id, anchor: .center) }
                        highlight(id)
                        search.focusedRecipeID = nil
                    }
            }
            .navigationTitle("レシピぽけっと")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .sheet(item: $editor) { mode in
            RecipeEditorView(mode: mode, savedTags: store.savedTags)
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .analyticsScreen(.recipeList)
    }

    private var recipeList: some View {
        List {
            Section {
                ForEach(search.results) { recipe in
                    RecipeRowView(
                        recipe: recipe,
                        isReordering: isReordering,
                        tagsExpanded: expandedTagIDs.contains(recipe.id),
                        actions: actions(for: recipe)
                    )
                    // 警告を閉じる途中に色を付けるため、その間は灰色になる accentColor ではなく、アセットの色を使う
                    .listRowBackground(highlightedID == recipe.id ? Color("AccentColor").opacity(0.15) : nil)
                }
                .onMove(perform: isReordering ? { store.move(fromOffsets: $0, toOffset: $1) } : nil)
            }
            // 検索欄との境目は背景の色で分かるため、最初の行の上には区切り線を出さない
            .listSectionSeparator(.hidden, edges: .top)
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(isReordering ? .active : .inactive))
        .overlay { emptyState }
        .overlay(alignment: .bottom) {
            // 設定を開いている間は、設定の画面に表示する
            if !showsSettings { ToastView() }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            SearchBar()
        }
        // 広告は一覧の下にだけ出し、一覧の行と完了の表示を広告に重ねない。検索の入力中と、登録・編集や設定を開いている間は出さない
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AdBannerView(isHidden: isKeyboardVisible || editor != nil || showsSettings)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(isReordering ? "完了" : "並べ替え") {
                withAnimation { isReordering.toggle() }
            }
            .disabled(!isReordering && search.results.count < 2)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                showsSettings = true
            } label: {
                Label(PolicyText.settingsTitle, systemImage: "gearshape")
            }
            Button {
                editor = .add
            } label: {
                Label("レシピを追加", systemImage: "plus")
            }
            .disabled(isReordering)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if store.loadFailed {
            ContentUnavailableView("レシピを読み込めませんでした", systemImage: "exclamationmark.triangle", description: Text("アプリを再起動してください。保存済みのデータは削除していません。"))
        } else if store.recipes.isEmpty {
            ContentUnavailableView {
                Label("レシピはまだありません", systemImage: "fork.knife")
            } description: {
                Text("右上の＋からURLを貼り付けるか、SafariやChromeの共有ボタンから「レシピぽけっと」を選んで登録できます。")
            } actions: {
                Button("レシピを追加") { editor = .add }
                    .buttonStyle(.borderedProminent)
            }
        } else if search.results.isEmpty {
            ContentUnavailableView {
                Label("条件に合うレシピはありません", systemImage: "magnifyingglass")
            } description: {
                Text("検索条件を減らすか、すべて解除してください。")
            } actions: {
                Button("条件をすべて解除") { search.clear() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func actions(for recipe: Recipe) -> RecipeRowView.Actions {
        RecipeRowView.Actions(
            open: { open(recipe) },
            searchTag: { search.addCondition(tag: $0) },
            toggleTags: {
                if expandedTagIDs.contains(recipe.id) { expandedTagIDs.remove(recipe.id) } else { expandedTagIDs.insert(recipe.id) }
            },
            edit: { editor = .edit(recipe) },
            copyURL: { store.copyURL(of: recipe) },
            delete: { withAnimation { store.delete(recipe) } },
            moveUp: store.canMoveUp(recipe) ? { store.moveUp(recipe) } : nil,
            moveDown: store.canMoveDown(recipe) ? { store.moveDown(recipe) } : nil
        )
    }

    /// 既定のブラウザ、またはOSの設定に応じた対応アプリで開く
    private func open(_ recipe: Recipe) {
        guard let url = URL(string: recipe.url) else {
            toasts.show("このURLは開けません")
            return
        }
        openURL(url) { accepted in
            if !accepted { toasts.show("このURLを開けるアプリがありません") }
        }
    }

    private func highlight(_ id: UUID) {
        highlightedID = id
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { if highlightedID == id { highlightedID = nil } }
        }
    }
}
