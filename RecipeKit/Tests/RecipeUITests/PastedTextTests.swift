import Foundation
import Testing
@testable import RecipeUI

@Suite("ペーストの中身")
struct PastedTextTests {
    private func load(_ provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            PastedText.load(from: provider) { continuation.resume(returning: $0) }
        }
    }

    @Test("リンクを URL の種類だけでコピーしたものから、URL を文字で取り出す")
    func urlOnly() async {
        let provider = NSItemProvider(object: URL(string: "https://www.sirogohan.com/recipe/nikujyaga/")! as NSURL)
        #expect(await load(provider) == "https://www.sirogohan.com/recipe/nikujyaga/")
    }

    @Test("文字だけなら、その文字をそのまま取り出す")
    func textOnly() async {
        let provider = NSItemProvider(object: "肉じゃが https://example.com/recipes/nikujaga" as NSString)
        #expect(await load(provider) == "肉じゃが https://example.com/recipes/nikujaga")
    }

    @Test("URL と文字の両方があれば、URL を使う")
    func urlAndText() async {
        let provider = NSItemProvider(object: URL(string: "https://example.com/recipes/nikujaga")! as NSURL)
        provider.registerObject("基本の肉じゃが" as NSString, visibility: .all)
        #expect(await load(provider) == "https://example.com/recipes/nikujaga")
    }

    @Test("URL も文字もなければ、何も取り出さない")
    func nothing() async {
        #expect(await load(NSItemProvider()) == nil)
    }
}
