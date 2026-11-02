import Foundation
import Observation
import RecipeCore

/// 登録・編集画面の入力を検証した結果
public struct RecipeFormOutput: Equatable, Sendable {
    public let url: String
    public let title: TitleInput
    public let tags: [String]
}

/// 登録・編集画面の入力。本体の画面と共有拡張で使う
@MainActor
@Observable
public final class RecipeFormModel {
    /// 登録か、どの記録の編集か。本体は、開く画面をシートで出すときにも使う
    public enum Mode: Equatable, Identifiable {
        case add
        case edit(Recipe)

        public var id: String {
            switch self {
            case .add: "add"
            case .edit(let recipe): recipe.id.uuidString
            }
        }
    }

    public let mode: Mode
    /// 共有で複数のURLを受け取ったときに選ぶ候補
    public let urlChoices: [String]
    public var url: String {
        didSet { if url != oldValue { urlDidChange() } }
    }
    /// 画面での入力。URLの変更でタイトルを消すときは入力とみなさない
    public var title: String {
        didSet {
            guard !isReplacingTitle, title != oldValue else { return }
            titleEdited = true
            receivedTitleCleared = false
            titleError = TitleRules.clean(title).count > RecipeLimits.titleLength ? TitleError.tooLong.message : nil
        }
    }
    public private(set) var tags: [String]
    public var tagInput = "" {
        didSet { if tagInput != oldValue { tagError = nil } }
    }

    public private(set) var urlError: String?
    public private(set) var titleError: String?
    public private(set) var tagError: String?
    /// URLを変えたため、共有元・自動取得のタイトルを消したこと
    public private(set) var receivedTitleCleared = false

    private let candidates: [String]
    private let initialURL: String
    private let initialTitle: String
    private let initialTags: [String]
    /// 画面を開いたときのタイトルの出どころ
    private let initialTitleSource: TitleSource
    private var titleEdited = false
    private var isReplacingTitle = false

    public init(urlChoices: [String], sharedTitle: String?, savedTags: [String]) {
        let url = urlChoices.first ?? ""
        let title = sharedTitle ?? ""
        mode = .add
        self.urlChoices = urlChoices
        self.url = url
        self.title = title
        tags = []
        candidates = TagRules.candidates(savedTags: savedTags)
        initialURL = url
        initialTitle = title
        initialTags = []
        initialTitleSource = sharedTitle == nil ? .none : .shared
    }

    public init(editing recipe: Recipe, savedTags: [String]) {
        mode = .edit(recipe)
        urlChoices = []
        url = recipe.url
        title = recipe.title ?? ""
        tags = recipe.tags
        candidates = TagRules.candidates(savedTags: savedTags)
        initialURL = recipe.url
        initialTitle = recipe.title ?? ""
        initialTags = recipe.tags
        initialTitleSource = recipe.titleSource
    }

    public var isEditing: Bool { mode != .add }

    /// 保存のボタンを押せる。URLが空白だけのときは押せない
    public var canSave: Bool { !trimmedURL.isEmpty }

    public var hasChanges: Bool {
        trimmedURL != initialURL.trimmingCharacters(in: .whitespacesAndNewlines)
            || title != initialTitle
            || tags != initialTags
            || !tagInput.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 保存後に本体がサイトからタイトルを取得する場合、そのサイト。今の入力を保存したときの記録から決め、保存の規則と食い違わないようにする
    public var siteForTitleFetch: SupportedSite? {
        guard let saved = savedRecipe(), saved.titleSource == .none,
              saved.titleFetchState == .notFetched || saved.titleFetchState == .fetching
        else { return nil }
        return SupportedSite.fetchableSite(for: saved.url)
    }

    /// タイトルが空のときの扱いの案内
    public var emptyTitleNote: String? {
        if let site = siteForTitleFetch {
            return "保存後に\(site.name)のページからタイトルを取得します"
        }
        guard TitleRules.clean(title).isEmpty else { return nil }
        return "未入力のときは「\(Recipe.untitledLabel)」と表示します"
    }

    /// 貼り付けた文字列からURLを取り出して入れる
    public func paste(_ text: String) {
        url = SharedContent.webURLs(in: text).first ?? text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func suggestions(limit: Int = 40) -> [String] {
        Array(TagRules.filter(candidates, matching: tagInput, excluding: tags).prefix(limit))
    }

    public func addTag(_ text: String) {
        switch TagRules.adding(text, to: tags, knownTags: candidates) {
        case .success(let updated):
            tags = updated
            tagInput = ""
            tagError = nil
        case .failure(let error):
            tagError = error.message
        }
    }

    public func commitTagInput() {
        guard !tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        addTag(tagInput)
    }

    public func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        tagError = nil
    }

    /// 入力を検証する。問題があれば項目ごとの案内を出して nil を返し、入力は残す
    public func makeOutput() -> RecipeFormOutput? {
        let validatedURL: String?
        switch RecipeURL.validate(url) {
        case .success(let value):
            validatedURL = value
            urlError = nil
        case .failure(let error):
            validatedURL = nil
            urlError = error.message
        }

        var titleInput = TitleInput.unchanged
        switch TitleRules.validateManual(title) {
        case .success(let value):
            titleInput = makeTitleInput(value)
            titleError = nil
        case .failure(let error):
            titleError = error.message
        }

        // 入力途中のタグも、保存時に1つのタグとして確定する
        commitTagInput()

        guard let validatedURL, titleError == nil, tagError == nil else { return nil }
        return RecipeFormOutput(url: validatedURL, title: titleInput, tags: tags)
    }

    private var trimmedURL: String {
        url.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeTitleInput(_ value: String?) -> TitleInput {
        switch mode {
        case .add:
            if !titleEdited {
                return initialTitleSource == .shared ? .shared(initialTitle) : .none
            }
            if let value { return .manual(value) }
            // 共有元のタイトルを本人が消した場合は、その指定を守る
            return initialTitleSource == .shared ? .manual(nil) : .none
        case .edit(let recipe):
            // 元のタイトルと同じ文字でも、URLを変えたために消えるタイトルを入れ直したときは、本人の入力として残す
            guard titleEdited, value != recipe.title || value != keptTitle(of: recipe) else { return .unchanged }
            return .manual(value)
        }
    }

    /// 今の入力を保存したときの記録。タイトルが上限を超えるなど、保存できない入力では nil
    private func savedRecipe() -> Recipe? {
        guard case .success(let value) = TitleRules.validateManual(title) else { return nil }
        let titleInput = makeTitleInput(value)
        switch mode {
        case .add:
            return RecipeEditing.newRecipe(url: trimmedURL, title: titleInput, tags: tags, sortKey: 0, now: .now)
        case .edit(let recipe):
            return RecipeEditing.updated(recipe, url: trimmedURL, title: titleInput, tags: tags, now: .now)
        }
    }

    /// 編集で、タイトルに触れずに今のURLで保存したときに残るタイトル。URLを変えると、共有元・自動取得のタイトルは消える
    private func keptTitle(of recipe: Recipe) -> String? {
        RecipeEditing.updated(recipe, url: trimmedURL, title: .unchanged, tags: recipe.tags, now: recipe.updatedAt).title
    }

    /// 編集でタイトルに触れていなければ、今のURLで保存したときに残るタイトルを表示する
    private func urlDidChange() {
        urlError = nil
        guard case .edit(let recipe) = mode, !titleEdited else { return }
        let kept = keptTitle(of: recipe)
        isReplacingTitle = true
        title = kept ?? ""
        isReplacingTitle = false
        receivedTitleCleared = recipe.title != nil && kept == nil
    }
}
