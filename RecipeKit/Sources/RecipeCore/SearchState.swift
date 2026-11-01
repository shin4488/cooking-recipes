import Foundation

/// 検索ボックスの状態。チップにした語と、入力中の文字を持つ
public struct SearchState: Equatable, Codable, Sendable {
    public enum AddResult: Equatable, Sendable {
        case added
        case duplicate
        case limitReached
    }

    public private(set) var chips: [String]
    public var input: String

    public init(chips: [String] = [], input: String = "") {
        self.chips = chips
        self.input = input
    }

    /// 検索に使う条件。チップになる前の最後の語も含める
    public var conditions: [String] {
        let word = trimmedInput
        return word.isEmpty ? chips : chips + [word]
    }

    public var isEmpty: Bool { conditions.isEmpty }

    /// チップが上限に達し、これ以上入力できない
    public var isFull: Bool { chips.count >= RecipeLimits.searchConditions }

    /// 入力欄の空白より前の語をチップにする。日本語の変換中は呼ばない
    @discardableResult
    public mutating func commitCompletedWords() -> AddResult {
        var words = input.split(omittingEmptySubsequences: false, whereSeparator: Self.isSeparator).map(String.init)
        var result = AddResult.added
        if words.count > 1 {
            let remainder = words.removeLast()
            // 確定する語は、入力中の文字を空にしてから、チップと比べる
            input = ""
            for word in words where !word.isEmpty {
                if append(word) == .limitReached {
                    result = .limitReached
                    break
                }
            }
            input = result == .limitReached ? "" : remainder
        }
        if truncateInput() { result = .limitReached }
        return result
    }

    /// 一覧のタグなど、1つの語を空白で分けずにチップとして加える
    @discardableResult
    public mutating func addChip(_ text: String) -> AddResult {
        let word = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return .duplicate }
        return append(word)
    }

    public mutating func removeChip(at index: Int) {
        guard chips.indices.contains(index) else { return }
        chips.remove(at: index)
    }

    public mutating func removeAll() {
        chips = []
        input = ""
    }

    private var trimmedInput: String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 語をチップに加える。入力中の語も含めた条件に検索時の表記ルールで同じものがあれば加えず、条件の数と合計の文字数の上限を守る
    private mutating func append(_ word: String) -> AddResult {
        let key = TextNormalization.searchKey(word)
        if conditions.contains(where: { TextNormalization.searchKey($0) == key }) { return .duplicate }
        guard conditions.count < RecipeLimits.searchConditions,
              Self.length(of: conditions) + word.count <= RecipeLimits.searchTotalLength
        else { return .limitReached }
        chips.append(word)
        return .added
    }

    /// 合計の文字数と条件数が上限を超えないように、入力中の文字を切り詰める
    private mutating func truncateInput() -> Bool {
        let available = isFull ? 0 : max(0, RecipeLimits.searchTotalLength - Self.length(of: chips))
        guard input.count > available else { return false }
        input = String(input.prefix(available))
        return true
    }

    private static func length(of words: [String]) -> Int {
        words.reduce(0) { $0 + $1.count }
    }

    private static func isSeparator(_ character: Character) -> Bool {
        character.isWhitespace
    }
}
