import Foundation
import Testing
import RecipeCore

@Suite("対応サイト")
struct SupportedSiteTests {
    @Test("対応サイトの公開レシピのHTTPS URLだけタイトルを取得する", arguments: [
        ("https://www.kewpie.co.jp/recipes/recipe/QP10220/", "kewpie"),
        ("https://www.mizkan.co.jp/ouchirecipe/recipe/?menu_id=12345", "mizkan"),
        ("https://www.sirogohan.com/recipe/nikujyaga/", "sirogohan"),
        ("https://www.sirogohan.com/sp/recipe/nikujyaga/", "sirogohan"),
        ("https://WWW.SIROGOHAN.COM:443/recipe/nikujyaga/", "sirogohan"),
    ])
    func fetchable(url: String, siteID: String) {
        #expect(SupportedSite.fetchableSite(for: url)?.id == siteID)
    }

    @Test("対象外のURLにはタイトル取得の通信を行わない", arguments: [
        "http://www.kewpie.co.jp/recipes/recipe/QP10220/",
        "https://www.kewpie.co.jp/company/",
        "https://kewpie.co.jp/recipes/recipe/QP10220/",
        "https://www.kewpie.co.jp:8443/recipes/recipe/QP10220/",
        "https://www.sirogohan.com/recipe",
        "https://www.kurashiru.com/recipes/abc",
        "https://delishkitchen.tv/recipes/123",
        "https://oceans-nadia.com/user/1/recipe/2",
        "https://www.youtube.com/watch?v=abc",
    ])
    func notFetchable(url: String) {
        #expect(SupportedSite.fetchableSite(for: url) == nil)
    }

    @Test("一覧ではキユーピーなど対応サイトの名前を併記し、他はホスト名を示す")
    func siteLabel() {
        let kewpie = Recipe(url: "https://www.kewpie.co.jp/recipes/recipe/QP10220/", title: "ポテトサラダ", titleSource: .fetched, titleFetchState: .fetched, tags: [], sortKey: 0, createdAt: .now, updatedAt: .now)
        #expect(kewpie.siteLabel == "キユーピー")
        var other = kewpie
        other.url = "https://cooking.example.com/a"
        #expect(other.siteLabel == "cooking.example.com")
    }

    @Test("タイトルの末尾にあるサイト名を、区切りごと除く", arguments: [
        ("kewpie", "鶏むね肉のてりマヨ焼きのレシピ・作り方 | とっておきレシピ | キユーピー", "鶏むね肉のてりマヨ焼きのレシピ・作り方"),
        ("mizkan", "納豆豚汁のレシピ・作り方 ｜ おうちレシピ | ミツカングループ", "納豆豚汁のレシピ・作り方"),
        ("sirogohan", "新じゃがいもの煮物（甘辛煮）のレシピ/作り方：白ごはん.com", "新じゃがいもの煮物（甘辛煮）のレシピ/作り方"),
    ])
    func removesSiteName(siteID: String, title: String, expected: String) throws {
        let site = try #require(SupportedSite.all.first { $0.id == siteID })
        #expect(site.removingSiteName(from: title) == expected)
    }

    @Test("区切りのないサイト名、サイト名だけのタイトル、別のサイトの名前は残す")
    func keepsOtherText() throws {
        let kewpie = try #require(SupportedSite.all.first { $0.id == "kewpie" })
        #expect(kewpie.removingSiteName(from: "キユーピー") == "キユーピー")
        #expect(kewpie.removingSiteName(from: "とっておきレシピ | キユーピー") == "とっておきレシピ")
        #expect(kewpie.removingSiteName(from: "ポテトサラダ キユーピー") == "ポテトサラダ キユーピー")
        #expect(kewpie.removingSiteName(from: "ポテトサラダ：白ごはん.com") == "ポテトサラダ：白ごはん.com")
    }
}

@Suite("共有で受け取る内容")
struct SharedContentTests {
    @Test("URLの項目と文中のURLを順に集め、同じURLは1つにまとめる")
    func collectsURLs() throws {
        let content = SharedContent.make(
            urls: [try #require(URL(string: "https://Example.com/a")), try #require(URL(string: "file:///tmp/x"))],
            texts: ["これ作りたい https://example.com/a と https://example.com/b"],
            titles: []
        )
        #expect(content.urls == ["https://Example.com/a", "https://example.com/b"])
    }

    @Test("URLと一緒に受け取ったタイトルを使い、URLや改行を含む共有文はタイトルにしない")
    func titleCandidate() throws {
        let url = try #require(URL(string: "https://www.sirogohan.com/recipe/nikujyaga/"))
        #expect(SharedContent.make(urls: [url], texts: [], titles: ["  肉じゃがのレシピ "]).title == "肉じゃがのレシピ")
        #expect(SharedContent.make(urls: [url], texts: ["肉じゃがのレシピ https://www.sirogohan.com/recipe/nikujyaga/"], titles: []).title == nil)
        #expect(SharedContent.make(urls: [url], texts: ["1行目\n2行目"], titles: []).title == nil)
        #expect(SharedContent.make(urls: [url], texts: [], titles: []).title == nil)
    }

    @Test("対応サイトのページから受け取ったタイトルは、末尾のサイト名を除く")
    func removesSiteNameFromSharedTitle() throws {
        let kewpie = try #require(URL(string: "https://www.kewpie.co.jp/recipes/recipe/QP10001985/"))
        let other = try #require(URL(string: "https://cooking.example.com/a"))
        let title = "鶏むね肉のみそマヨ焼きのレシピ・作り方 | とっておきレシピ | キユーピー"
        #expect(SharedContent.make(urls: [kewpie], texts: [], titles: [title]).title == "鶏むね肉のみそマヨ焼きのレシピ・作り方")
        #expect(SharedContent.make(urls: [other], texts: [], titles: [title]).title == title)
    }
}
