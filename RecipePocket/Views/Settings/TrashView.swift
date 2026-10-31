import RecipeCore
import SwiftUI

/// 削除した記録を30日間保持し、戻すか完全に削除する
struct TrashView: View {
    @Environment(RecipeStore.self) private var store
    @State private var pendingDeletion: TrashedRecipe?
    @State private var showsEmptyConfirmation = false
    @State private var blockedRestore: Recipe?

    var body: some View {
        List {
            if !store.trash.isEmpty {
                Section {
                    ForEach(store.trash) { item in
                        row(item)
                    }
                } footer: {
                    Text("削除したレシピは\(RecipeLimits.trashRetentionDays)日間ここから戻せます。期限を過ぎると完全に削除します。")
                }
            }
        }
        .overlay {
            if store.trash.isEmpty {
                ContentUnavailableView(
                    "ごみ箱は空です",
                    systemImage: "trash",
                    description: Text("削除したレシピは\(RecipeLimits.trashRetentionDays)日間ここから戻せます。")
                )
            }
        }
        .navigationTitle("ごみ箱")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("すべて削除", role: .destructive) { showsEmptyConfirmation = true }
                    .disabled(store.trash.isEmpty)
            }
        }
        .confirmationDialog(
            "ごみ箱の\(store.trash.count.formatted())件を完全に削除しますか？",
            isPresented: $showsEmptyConfirmation,
            titleVisibility: .visible
        ) {
            Button("\(store.trash.count.formatted())件を完全に削除", role: .destructive) { store.emptyTrash() }
        } message: {
            Text("完全に削除したレシピは元に戻せません。")
        }
        .confirmationDialog(
            "1件を完全に削除しますか？",
            isPresented: Binding { pendingDeletion != nil } set: { if !$0 { pendingDeletion = nil } },
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { item in
            Button("1件を完全に削除", role: .destructive) { store.deletePermanently(item) }
        } message: { item in
            Text("「\(item.recipe.displayTitle)」は元に戻せません。")
        }
        .alert(
            "同じURLのレシピが一覧にあります",
            isPresented: Binding { blockedRestore != nil } set: { if !$0 { blockedRestore = nil } },
            presenting: blockedRestore
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { recipe in
            Text("「\(recipe.displayTitle)」として保存されているため、戻せません。")
        }
        .analyticsScreen(.trash)
    }

    private func row(_ item: TrashedRecipe) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.recipe.displayTitle)
                .font(.headline)
            if let label = item.recipe.siteLabel {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("あと\(TrashPolicy.daysRemaining(deletedAt: item.deletedAt, now: .now))日で完全に削除")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .swipeActions(edge: .trailing) {
            Button("完全に削除", systemImage: "trash", role: .destructive) { pendingDeletion = item }
            Button("戻す", systemImage: "arrow.uturn.backward") { restore(item) }
                .tint(.green)
        }
        .contextMenu {
            Button("戻す", systemImage: "arrow.uturn.backward") { restore(item) }
            Button("完全に削除", systemImage: "trash", role: .destructive) { pendingDeletion = item }
        }
    }

    private func restore(_ item: TrashedRecipe) {
        switch store.restore(item) {
        case .duplicate(let existing): blockedRestore = existing
        case .failed: store.showToast("戻せませんでした")
        case .restored: break
        }
    }
}
