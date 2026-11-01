import Testing
import RecipeCore

@Suite("検索の一致条件")
struct SearchMatchingTests {
    private func matches(title: String?, tags: [String] = [], host: String? = "www.example.com", _ conditions: String...) -> Bool {
        SearchTarget(title: title, tags: tags, host: host).matches(conditions.map(SearchKeyword.init))
    }

    @Test("全角・半角、英字の大小文字、ひらがな・カタカナを区別しない")
    func ignoresNotationDifferences() {
        #expect(matches(title: "ＡＢＣカレー", "abc"))
        #expect(matches(title: "ｶﾚｰうどん", "カレー"))
        #expect(matches(title: "カレーうどん", "かれー"))
        #expect(matches(title: "かれーうどん", "カレー"))
        #expect(matches(title: "Curry Rice", "CURRY"))
        #expect(matches(title: "鶏むね肉", "鶏ムネ"))
    }

    @Test("記号はそのまま照合し、意味による言い換えはしない")
    func noGuessing() {
        #expect(matches(title: "【簡単】肉じゃが", "【簡単】"))
        #expect(!matches(title: "簡単肉じゃが", "【簡単】"))
        #expect(!matches(title: "玉子焼き", "卵"))
    }

    @Test("各語がタイトル・タグ・ホスト名のいずれかに部分一致し、すべての語を満たす記録だけを表示する")
    func allConditionsAcrossFields() {
        #expect(matches(title: "鶏の照り焼き", tags: ["時短"], "鶏", "時短"))
        #expect(matches(title: "肉じゃが", host: "www.sirogohan.com", "sirogohan", "じゃが"))
        #expect(!matches(title: "鶏の照り焼き", tags: ["主菜"], "鶏", "時短"))
    }

    @Test("項目をまたいだ文字列には一致しない")
    func doesNotMatchAcrossFields() {
        #expect(!matches(title: "カレ", tags: ["ー"], "カレー"))
    }

    @Test("条件なしは全件に一致する")
    func emptyConditions() {
        #expect(SearchTarget(title: nil, tags: [], host: nil).matches([]))
    }
}

@Suite("検索ボックスの入力")
struct SearchStateTests {
    @Test("半角・全角の空白で区切った語をチップにし、最後の語は入力中のまま検索に使う")
    func commitWords() {
        var state = SearchState(input: "鶏肉 玉ねぎ　カレ")
        state.commitCompletedWords()
        #expect(state.chips == ["鶏肉", "玉ねぎ"])
        #expect(state.input == "カレ")
        #expect(state.conditions == ["鶏肉", "玉ねぎ", "カレ"])
    }

    @Test("空白で終わると最後の語もチップになり、入力欄は空になる")
    func commitTrailingSpace() {
        var state = SearchState(input: "  鶏肉 ")
        state.commitCompletedWords()
        #expect(state.chips == ["鶏肉"])
        #expect(state.input.isEmpty)
    }

    @Test("検索時の表記ルールで同じ条件は追加しない")
    func ignoresDuplicates() {
        var state = SearchState(chips: ["カレー"], input: "かれー ")
        state.commitCompletedWords()
        #expect(state.chips == ["カレー"])

        var tagged = SearchState(input: "主菜")
        #expect(tagged.addChip("主菜") == .duplicate)
        #expect(tagged.addChip("ＣＵＲＲＹ") == .added)
        #expect(tagged.addChip("curry") == .duplicate)
    }

    @Test("一度に確定する語のうち、同じ条件は1つにまとめる")
    func commitSkipsDuplicateWords() {
        var state = SearchState(input: "カレー かれー 鶏 ")
        #expect(state.commitCompletedWords() == .added)
        #expect(state.chips == ["カレー", "鶏"])
        #expect(state.input.isEmpty)
    }

    @Test("入力中の語は、チップになるまで同じ条件かを確かめない")
    func remainderIsNotDeduplicated() {
        var state = SearchState(chips: ["鶏"], input: "とり 鶏")
        state.commitCompletedWords()
        #expect(state.chips == ["鶏", "とり"])
        #expect(state.input == "鶏")
    }

    @Test("空白だけのタグは加えない")
    func addChipIgnoresBlank() {
        var state = SearchState()
        #expect(state.addChip("  ") == .duplicate)
        #expect(state.chips.isEmpty)
    }

    @Test("タグは空白を含んでも1つのチップとして追加する")
    func tagChipKeepsSpaces() {
        var state = SearchState()
        #expect(state.addChip("鶏 むね") == .added)
        #expect(state.chips == ["鶏 むね"])
    }

    @Test("条件は20個まで")
    func conditionLimit() {
        var state = SearchState()
        for index in 1...20 { #expect(state.addChip("語\(index)") == .added) }
        #expect(state.isFull)
        #expect(state.addChip("語21") == .limitReached)

        var typing = SearchState(input: String((1...21).map { "語\($0) " }.joined()))
        #expect(typing.commitCompletedWords() == .limitReached)
        #expect(typing.chips.count == 20)
        #expect(typing.input.isEmpty)
    }

    @Test("確定の途中で条件が20個に達したら、残りの語と入力中の文字を消す")
    func commitStopsAtConditionLimit() {
        var state = SearchState(chips: (1...19).map { "語\($0)" }, input: "a b c")
        #expect(state.commitCompletedWords() == .limitReached)
        #expect(state.chips.count == 20)
        #expect(state.chips.last == "a")
        #expect(state.input.isEmpty)
    }

    @Test("条件が20個のときは、入力中の文字を残さない")
    func fullStateClearsInput() {
        var state = SearchState(chips: (1...20).map { "語\($0)" }, input: "カレー")
        #expect(state.commitCompletedWords() == .limitReached)
        #expect(state.input.isEmpty)
    }

    @Test("入力中の語も条件の数に含める")
    func inputCountsAsCondition() {
        var state = SearchState(input: "入力中")
        for index in 1...19 { #expect(state.addChip("語\(index)") == .added) }
        #expect(state.addChip("語20") == .limitReached)
    }

    @Test("合計200文字まで")
    func lengthLimit() {
        var state = SearchState()
        #expect(state.addChip(String(repeating: "あ", count: 195)) == .added)
        #expect(state.addChip("いいいいいい") == .limitReached)
        #expect(state.addChip("いいいいい") == .added)

        var typing = SearchState(chips: [String(repeating: "あ", count: 198)], input: "いいう")
        typing.commitCompletedWords()
        #expect(typing.input == "いい")
    }

    @Test("確定の途中で合計が200文字を超える語があれば、その語から先と入力中の文字を消す")
    func commitStopsAtLengthLimit() {
        var state = SearchState(chips: [String(repeating: "あ", count: 195)], input: "いいいい ううう え お")
        #expect(state.commitCompletedWords() == .limitReached)
        #expect(state.chips == [String(repeating: "あ", count: 195), "いいいい"])
        #expect(state.input.isEmpty)
    }

    @Test("タグを加えるときは、入力中の文字も合計の文字数に含める")
    func addChipCountsInputLength() {
        var state = SearchState(chips: [String(repeating: "あ", count: 190)], input: "いいいいい")
        #expect(state.addChip("うううう") == .added)
        #expect(state.addChip("ええ") == .limitReached)
    }

    @Test("個別に削除でき、すべてクリアでチップと入力中の文字を消す")
    func removal() {
        var state = SearchState(chips: ["鶏", "時短"], input: "カレー")
        state.removeChip(at: 0)
        #expect(state.chips == ["時短"])
        state.removeAll()
        #expect(state.chips.isEmpty)
        #expect(state.input.isEmpty)
        #expect(state.isEmpty)
    }
}
