import Testing
import RecipeCore

@Suite("タグ")
struct TagRulesTests {
    @Test("前後の空白を除き、空のタグは登録しない。改行は空白にし、空白では分割しない", arguments: [
        ("  主菜 ", "主菜" as String?),
        ("　", nil),
        ("\n", nil),
        ("鶏\nむね", "鶏 むね"),
        ("鶏、むね", "鶏、むね"),
    ])
    func clean(input: String, expected: String?) {
        #expect(TagRules.clean(input) == expected)
    }

    @Test("全角・半角、英字の大小文字が違うだけなら既存の表記を使う")
    func usesExistingNotation() {
        #expect(TagRules.adding("ｐａｓｔａ", to: [], knownTags: ["Pasta"]) == .success(["Pasta"]))
        #expect(TagRules.adding("ﾒﾝ", to: ["主菜"], knownTags: ["メン"]) == .success(["主菜", "メン"]))
    }

    @Test("同じ記録内の重複は除く")
    func removesDuplicates() {
        #expect(TagRules.adding("PASTA", to: ["Pasta"], knownTags: []) == .success(["Pasta"]))
        #expect(TagRules.adding(" 主菜 ", to: ["主菜"], knownTags: []) == .success(["主菜"]))
    }

    @Test("ひらがな・カタカナや意味が近い語は別のタグとして扱う")
    func noSemanticMerge() {
        #expect(TagRules.adding("かれー", to: ["カレー"], knownTags: []) == .success(["カレー", "かれー"]))
        #expect(TagRules.adding("玉子", to: ["卵"], knownTags: []) == .success(["卵", "玉子"]))
    }

    @Test("1個30文字・1記録20個まで")
    func limits() {
        let thirty = String(repeating: "あ", count: 30)
        #expect(TagRules.adding(thirty, to: [], knownTags: []) == .success([thirty]))
        #expect(TagRules.adding(thirty + "あ", to: [], knownTags: []) == .failure(.tooLong))

        let twenty = (1...20).map { "タグ\($0)" }
        #expect(TagRules.adding("タグ21", to: Array(twenty.prefix(19)), knownTags: []) == .success(Array(twenty.prefix(19)) + ["タグ21"]))
        #expect(TagRules.adding("タグ21", to: twenty, knownTags: []) == .failure(.tooMany))
    }

    @Test("候補はアプリが用意するタグと保存済みのタグを、重複をまとめて並べる")
    func candidates() {
        #expect(TagRules.candidates(savedTags: []) == TagRules.presets)

        let candidates = TagRules.candidates(savedTags: ["時短", "Pasta", "pasta", "鶏肉"])
        #expect(Array(candidates.prefix(TagRules.presets.count)) == TagRules.presets)
        #expect(candidates.count == TagRules.presets.count + 2)
        #expect(candidates.contains("鶏肉"))
        #expect(candidates.filter { $0.lowercased() == "pasta" }.count == 1)
    }

    @Test("候補は部分一致で探せ、付いているタグは候補から除く")
    func filter() {
        let candidates = ["主菜", "副菜", "Pasta", "汁物"]
        #expect(TagRules.filter(candidates, matching: "菜", excluding: []) == ["主菜", "副菜"])
        #expect(TagRules.filter(candidates, matching: "ＰＡＳ", excluding: []) == ["Pasta"])
        #expect(TagRules.filter(candidates, matching: "", excluding: ["副菜", "pasta"]) == ["主菜", "汁物"])
    }
}

@Suite("タイトル")
struct TitleRulesTests {
    @Test("手入力は改行を空白にし、前後の空白を除く。空欄はタイトルなし")
    func manual() {
        #expect(TitleRules.validateManual("  肉じゃが  ") == .success("肉じゃが"))
        #expect(TitleRules.validateManual("肉じゃが\n簡単") == .success("肉じゃが 簡単"))
        #expect(TitleRules.validateManual("   ") == .success(nil))
    }

    @Test("500文字を超える手入力は修正を案内し、受け取った値は採用しない")
    func lengthLimit() {
        let fiveHundred = String(repeating: "あ", count: 500)
        #expect(TitleRules.validateManual(fiveHundred) == .success(fiveHundred))
        #expect(TitleRules.validateManual(fiveHundred + "あ") == .failure(.tooLong))
        #expect(TitleRules.acceptReceived(fiveHundred) == fiveHundred)
        #expect(TitleRules.acceptReceived(fiveHundred + "あ") == nil)
        #expect(TitleRules.acceptReceived(" \n ") == nil)
    }

    @Test("未設定なら「タイトル未設定（ホスト名）」と表示する")
    func displayTitle() {
        #expect(TitleRules.displayTitle(nil, host: "www.example.com") == "タイトル未設定（www.example.com）")
        #expect(TitleRules.displayTitle("肉じゃが", host: "www.example.com") == "肉じゃが")
    }
}
