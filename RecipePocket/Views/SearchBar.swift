import RecipeCore
import RecipeUI
import SwiftUI
import UIKit

/// 検索ボックス。空白で区切った語を×付きのチップにする
struct SearchBar: View {
    @Environment(RecipeStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                ComposingAwareTextField(
                    text: $store.search.input,
                    placeholder: store.search.isFull ? "条件は\(RecipeLimits.searchConditions)個までです" : "タイトル・タグ・サイトで検索",
                    isEnabled: !store.search.isFull,
                    onChange: { store.searchInputChanged(isComposing: $0) },
                    onReturn: { store.commitSearchInput() }
                )
                if !store.search.isEmpty {
                    Button("すべてクリア") {
                        store.clearSearch()
                    }
                    .font(.subheadline)
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.fill.tertiary, in: .rect(cornerRadius: 10))

            if !store.search.chips.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(Array(store.search.chips.enumerated()), id: \.offset) { index, chip in
                            RemovableChip(chip, removalLabel: "タップすると検索条件から外します") {
                                store.removeSearchChip(at: index)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

/// 日本語の変換中かを伝える入力欄。SwiftUI の TextField では変換中の文字を区別できないため UITextField を使う
struct ComposingAwareTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isEnabled: Bool
    /// 文字が変わったときに、変換中かを渡す
    var onChange: (_ isComposing: Bool) -> Void
    var onReturn: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.returnKeyType = .search
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.clearButtonMode = .never
        field.accessibilityLabel = "検索"
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        return field
    }

    /// 幅は空いている分を使い、高さは文字サイズに合わせた1行分にする
    func sizeThatFits(_ proposal: ProposedViewSize, uiView field: UITextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? field.intrinsicContentSize.width, height: field.intrinsicContentSize.height)
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        // 変換中の文字も text に送るため、食い違うのは「すべてクリア」などアプリ側で書き換えたときだけ。
        // 変換中の文字が入力欄に残らないよう、変換を確定させてから書き換える
        if field.text != text {
            context.coordinator.isApplyingText = true
            field.unmarkText()
            field.text = text
            context.coordinator.isApplyingText = false
        }
        field.placeholder = placeholder
        field.isEnabled = isEnabled
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ComposingAwareTextField
        /// 入力欄を書き換えている間に届く変更を、入力として扱わない
        var isApplyingText = false

        init(parent: ComposingAwareTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            guard !isApplyingText else { return }
            parent.text = field.text ?? ""
            parent.onChange(field.markedTextRange != nil)
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            guard field.markedTextRange == nil else { return true }
            parent.onReturn()
            field.resignFirstResponder()
            return false
        }
    }
}
