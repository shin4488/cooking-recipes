import Foundation

public enum TagError: Error, Equatable, Sendable {
    case tooLong
    case tooMany

    public var message: String {
        switch self {
        case .tooLong: "タグは1個\(RecipeLimits.tagLength)文字以内にしてください"
        case .tooMany: "タグは1件に\(RecipeLimits.tagsPerRecipe)個までです"
        }
    }
}

public enum TagRules {
    /// アプリが用意するタグ。使われていなくても候補に残す。食材、食べる時間帯、用途の順に並べる
    public static let presets = ["牛肉", "豚肉", "鶏肉", "魚介", "野菜", "朝ごはん", "昼ごはん", "夜ごはん", "お弁当", "時短"]

    /// 前後の空白を除き、改行を空白にする。空なら nil
    public static func clean(_ text: String) -> String? {
        let cleaned = String(text.map { $0.isNewline ? " " : $0 }).trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? nil : cleaned
    }

    /// 入力したタグを記録のタグに加える。同じタグ（全角・半角、英字の大小文字を区別しない）は既存の表記を使い、記録内では重複させない
    /// - Parameter knownTags: 保存済みのタグなど、表記をそろえる先の候補
    public static func adding(_ text: String, to tags: [String], knownTags: [String]) -> Result<[String], TagError> {
        guard let tag = clean(text) else { return .success(tags) }
        let key = TextNormalization.tagKey(tag)
        if tags.contains(where: { TextNormalization.tagKey($0) == key }) { return .success(tags) }
        guard tag.count <= RecipeLimits.tagLength else { return .failure(.tooLong) }
        guard tags.count < RecipeLimits.tagsPerRecipe else { return .failure(.tooMany) }
        let notation = knownTags.first { TextNormalization.tagKey($0) == key } ?? tag
        return .success(tags + [notation])
    }

    /// タグの候補。用意したタグと保存済みのタグを、表記ゆれをまとめて並べる
    public static func candidates(savedTags: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        let saved = savedTags.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        for tag in presets + saved where seen.insert(TextNormalization.tagKey(tag)).inserted {
            result.append(tag)
        }
        return result
    }

    /// 候補を部分一致で絞り込む。記録に付いているタグは除く
    public static func filter(_ candidates: [String], matching query: String, excluding tags: [String]) -> [String] {
        let attached = Set(tags.map(TextNormalization.tagKey))
        let keyword = TextNormalization.searchKey(query.trimmingCharacters(in: .whitespaces))
        return candidates.filter { candidate in
            !attached.contains(TextNormalization.tagKey(candidate))
                && (keyword.isEmpty || TextNormalization.searchKey(candidate).contains(keyword))
        }
    }
}
