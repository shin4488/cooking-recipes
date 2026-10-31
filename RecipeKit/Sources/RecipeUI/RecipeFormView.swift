import RecipeCore
import SwiftUI

/// URL・タイトル・タグを同じ画面で確認して保存するフォーム。保存・取消のボタンは呼び出し側が置く
public struct RecipeFormView: View {
    @Bindable private var model: RecipeFormModel
    private let showsPasteButton: Bool
    @FocusState private var focusedField: Field?

    private enum Field {
        case url
        case title
    }

    public init(model: RecipeFormModel, showsPasteButton: Bool) {
        self.model = model
        self.showsPasteButton = showsPasteButton
    }

    public var body: some View {
        Form {
            // 選んだURLは下の入力欄で直せる。入力欄が選択肢の1つに見えないよう、別の欄に分ける
            if model.urlChoices.count > 1 {
                Section("共有されたURL（1つ選ぶ）") {
                    Picker("保存するURL", selection: $model.url) {
                        ForEach(model.urlChoices, id: \.self) { choice in
                            Text(choice)
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .tag(choice)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }

            Section {
                TextField("https://", text: $model.url, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focusedField, equals: .url)
                    .onChange(of: model.url) { _, newValue in
                        if let text = removingNewlines(newValue, replacement: "") { model.url = text }
                    }
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                    .accessibilityLabel("URL")
                if showsPasteButton {
                    PasteButton(payloadType: String.self) { strings in
                        guard let text = strings.first else { return }
                        Task { @MainActor in model.paste(text) }
                    }
                    .labelStyle(.titleAndIcon)
                }
            } header: {
                FieldLabel(model.urlChoices.count > 1 ? "保存するURL" : "URL", isRequired: true)
            } footer: {
                if let error = model.urlError {
                    ErrorText(error)
                }
            }

            Section {
                TextField("タイトルを入力", text: $model.title, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focusedField, equals: .title)
                    .onChange(of: model.title) { _, newValue in
                        if let text = removingNewlines(newValue, replacement: " ") { model.title = text }
                    }
                    .accessibilityLabel("タイトル")
            } header: {
                FieldLabel("タイトル", isRequired: false)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if let error = model.titleError {
                        ErrorText(error)
                    }
                    if model.receivedTitleCleared {
                        Text("URLを変えたため、共有元・自動取得のタイトルを消しました")
                    }
                    if let note = model.emptyTitleNote {
                        Text(note)
                    }
                }
            }

            Section {
                TagEditorView(model: model)
            } header: {
                FieldLabel("タグ", isRequired: false)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if let error = model.tagError {
                        ErrorText(error)
                    }
                    Text("1件に\(RecipeLimits.tagsPerRecipe)個・1個\(RecipeLimits.tagLength)文字まで。入力途中の文字も保存時に1つのタグになります")
                }
            }
        }
        .onAppear {
            if model.url.isEmpty { focusedField = .url }
        }
    }

    /// 折り返して表示するが改行は入れない。末尾の改行（改行キー）は入力の終了として扱う
    private func removingNewlines(_ text: String, replacement: String) -> String? {
        guard text.contains(where: \.isNewline) else { return nil }
        if text.last?.isNewline == true { focusedField = nil }
        var trimmed = text
        while trimmed.last?.isNewline == true { trimmed.removeLast() }
        return trimmed.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).joined(separator: replacement)
    }
}

/// 欄の見出し。必須か任意かを、文字ではなく印で示す
struct FieldLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    private let title: String
    private let isRequired: Bool

    init(_ title: String, isRequired: Bool) {
        self.title = title
        self.isRequired = isRequired
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            // 印の色は明るい表示で濃く、暗い表示で淡い。文字の色を反対にして、コントラスト比 4.5:1 以上を保つ
            Text(isRequired ? "必須" : "任意")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(markColor, in: .rect(cornerRadius: 4))
        }
        .accessibilityElement(children: .combine)
    }

    /// 必須はアクセントカラー、任意は灰色
    private var markColor: AnyShapeStyle {
        if isRequired { return AnyShapeStyle(.tint) }
        return AnyShapeStyle(Color(white: colorScheme == .dark ? 0.62 : 0.45))
    }
}

struct ErrorText: View {
    private let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        Label(message, systemImage: "exclamationmark.circle")
            .foregroundStyle(.red)
    }
}

/// 付けたタグの一覧、入力欄、候補
struct TagEditorView: View {
    @Bindable var model: RecipeFormModel
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !model.tags.isEmpty {
                FlowLayout {
                    ForEach(model.tags, id: \.self) { tag in
                        RemovableChip(tag, removalLabel: "タップすると外します") {
                            model.removeTag(tag)
                        }
                    }
                }
            }
            HStack {
                TextField("タグを入力", text: $model.tagInput)
                    .focused($inputFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        model.commitTagInput()
                        inputFocused = true
                    }
                    .accessibilityLabel("追加するタグ")
                Button("追加") {
                    model.commitTagInput()
                }
                .buttonStyle(.borderless)
                .disabled(model.tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            let suggestions = model.suggestions()
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.tagInput.isEmpty ? "候補" : "一致する候補")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlowLayout {
                        ForEach(suggestions, id: \.self) { tag in
                            Button {
                                model.addTag(tag)
                            } label: {
                                TagChip(tag, systemImage: "plus")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tag)
                            .accessibilityHint("タップするとこのタグを付けます")
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
