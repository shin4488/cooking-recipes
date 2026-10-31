import RecipeCore
import RecipeUI
import SwiftUI

/// 一覧の1行。元サイトを開くタイトル、検索に使うタグ、その他の操作の領域を分ける
struct RecipeRowView: View {
    struct Actions {
        var open: () -> Void
        var searchTag: (String) -> Void
        var toggleTags: () -> Void
        var edit: () -> Void
        var copyURL: () -> Void
        var delete: () -> Void
        var moveUp: (() -> Void)?
        var moveDown: (() -> Void)?
    }

    /// 折りたたんだときに表示するタグの数
    private static let collapsedTagCount = 6

    let recipe: Recipe
    let isReordering: Bool
    let tagsExpanded: Bool
    let actions: Actions

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: actions.open) {
                    // 強い色の文字が並ばないよう、タイトルは本文の色にする。未設定は太さで区別する。
                    // ボタンの中では .primary がアクセントカラーになるため、Color.primary を指定する
                    Text(recipe.displayTitle)
                        .font(.headline)
                        .fontWeight(recipe.title == nil ? .regular : nil)
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .accessibilityAddTraits(.isLink)
                .accessibilityHint("レシピのページを開きます")

                siteLine

                if !recipe.tags.isEmpty {
                    tagList
                }
            }
            .disabled(isReordering)

            if !isReordering {
                Menu {
                    menuItems
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(Color.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .accessibilityLabel("「\(recipe.displayTitle)」の操作")
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button("削除", systemImage: "trash", role: .destructive, action: actions.delete)
            Button("編集", systemImage: "pencil", action: actions.edit)
                .tint(.blue)
        }
        .contextMenu { menuItems }
        .accessibilityElement(children: .contain)
        .accessibilityActions {
            if let moveUp = actions.moveUp { Button("上へ移動", action: moveUp) }
            if let moveDown = actions.moveDown { Button("下へ移動", action: moveDown) }
        }
    }

    @ViewBuilder
    private var menuItems: some View {
        Button("編集", systemImage: "pencil", action: actions.edit)
        Button("URLをコピー", systemImage: "doc.on.doc", action: actions.copyURL)
        Button("削除", systemImage: "trash", role: .destructive, action: actions.delete)
    }

    private var siteLine: some View {
        HStack(spacing: 6) {
            if let label = recipe.siteLabel {
                Text(label)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if recipe.titleFetchState == .fetching {
                ProgressView()
                    .controlSize(.mini)
                Text("タイトルを取得中")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private var tagList: some View {
        let hiddenCount = max(0, recipe.tags.count - Self.collapsedTagCount)
        let visible = tagsExpanded ? recipe.tags : Array(recipe.tags.prefix(Self.collapsedTagCount))
        return FlowLayout {
            ForEach(visible, id: \.self) { tag in
                Button {
                    actions.searchTag(tag)
                } label: {
                    TagChip(tag)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("タグ \(tag)")
                .accessibilityHint("このタグで絞り込みます")
            }
            if hiddenCount > 0 {
                Button(tagsExpanded ? "閉じる" : "ほか\(hiddenCount)件", action: actions.toggleTags)
                    .font(.subheadline)
                    .buttonStyle(.borderless)
                    .padding(.vertical, 5)
                    .accessibilityLabel(tagsExpanded ? "タグを折りたたむ" : "残りのタグ\(hiddenCount)件を表示")
            }
        }
    }
}
