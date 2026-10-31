import Foundation
import Testing
@testable import RecipeCore

@Suite("HTMLからのタイトルの取り出し")
struct HTMLTitleExtractorTests {
    private func title(_ html: String, contentType: String? = "text/html; charset=utf-8") -> String? {
        HTMLTitleExtractor.title(from: Data(html.utf8), contentType: contentType)
    }

    @Test("og:title を優先し、なければ title 要素を使う")
    func prefersOGTitle() {
        #expect(title(#"<head><title>白ごはん.com</title><meta property="og:title" content="肉じゃがのレシピ"></head>"#) == "肉じゃがのレシピ")
        #expect(title(#"<head><meta content='肉じゃが' property='og:title'/></head>"#) == "肉じゃが")
        #expect(title(#"<HEAD><META PROPERTY="og:title" CONTENT="肉じゃが"></HEAD>"#) == "肉じゃが")
        #expect(title("<head><title>肉じゃが</title></head>") == "肉じゃが")
        #expect(title(#"<head><meta property="og:title" content=" "><title>肉じゃが</title></head>"#) == "肉じゃが")
    }

    @Test("前後の空白を除き、改行と空白の連続を1つの空白にする")
    func whitespace() {
        #expect(title("<title>\n    肉じゃが\n    | 白ごはん.com\n</title>") == "肉じゃが | 白ごはん.com")
    }

    @Test("文字参照を戻し、引用符の中の > で属性を切らない")
    func entitiesAndQuotes() {
        #expect(title(#"<meta property="og:title" content="A &amp; B &#12354;&#x3044; &quot;C&quot;">"#) == "A & B あい \"C\"")
        #expect(title(#"<meta property="og:title" content="作り方 > 下ごしらえ">"#) == "作り方 > 下ごしらえ")
    }

    @Test("Content-Type や meta で指定された文字コードで読む")
    func encodings() throws {
        let html = #"<html><head><meta charset="Shift_JIS"><title>肉じゃが</title></head>"#
        let shiftJIS = try #require(html.data(using: .shiftJIS))
        #expect(HTMLTitleExtractor.title(from: shiftJIS, contentType: "text/html") == "肉じゃが")
        let eucJP = try #require("<title>肉じゃが</title>".data(using: .japaneseEUC))
        #expect(HTMLTitleExtractor.title(from: eucJP, contentType: "text/html; charset=EUC-JP") == "肉じゃが")
    }

    @Test("途中で読み込みを止めて末尾の文字が欠けていても読める")
    func truncatedData() {
        let data = Data("<head><title>肉じゃが</title>あ".utf8).dropLast(1)
        #expect(HTMLTitleExtractor.title(from: data, contentType: "text/html; charset=utf-8") == "肉じゃが")
    }

    @Test("タイトルがない、または500文字を超える場合は採用しない")
    func noTitle() {
        #expect(title("<head></head><body>本文</body>") == nil)
        #expect(title("<title>\(String(repeating: "あ", count: 501))</title>") == nil)
    }
}

@Suite("接続先のIPアドレス")
struct PublicAddressTests {
    @Test("公開IPアドレスへの接続を許可する", arguments: [
        "8.8.8.8", "172.15.255.255", "172.32.0.0", "100.63.255.255", "100.128.0.0",
        "2001:4860:4860::8888", "::ffff:8.8.8.8", "64:ff9b::808:808", "[2001:4860:4860::8888]",
    ])
    func publicAddresses(address: String) {
        #expect(PublicAddress.isPublic(address))
    }

    @Test("社内・端末内・特殊用途のアドレスへの接続を拒否する", arguments: [
        "10.0.0.1", "172.16.0.1", "172.31.255.255", "192.168.1.1", "127.0.0.1", "169.254.1.1",
        "100.64.0.1", "0.0.0.0", "224.0.0.1", "255.255.255.255", "192.0.2.1",
        "::1", "::", "fe80::1", "fe80::1%en0", "fc00::1", "fd12:3456::1", "ff02::1", "::ffff:192.168.0.1",
        "64:ff9b::a00:1", "2001:db8::1", "not an address",
    ])
    func privateAddresses(address: String) {
        #expect(!PublicAddress.isPublic(address))
    }
}

/// 固定の応答を返す通信の差し替え。URLごとに応答を登録する
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response: Sendable {
        var status = 200
        var headers = ["Content-Type": "text/html; charset=utf-8"]
        var body = Data()
        var redirect: String?
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var responses: [String: Response] = [:]
    nonisolated(unsafe) private static var requested: [String] = []

    static func register(_ url: String, _ response: Response) {
        lock.withLock { responses[url] = response }
    }

    static func wasRequested(_ url: String) -> Bool {
        lock.withLock { requested.contains(url) }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url?.absoluteString ?? ""
        let response = Self.lock.withLock {
            Self.requested.append(url)
            return Self.responses[url]
        }
        guard let response, let requestURL = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        var headers = response.headers
        if let redirect = response.redirect { headers["Location"] = redirect }
        let http = HTTPURLResponse(url: requestURL, statusCode: response.status, httpVersion: "HTTP/1.1", headerFields: headers)!
        if let redirect = response.redirect, let target = URL(string: redirect) {
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: http)
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

struct FixedResolver: HostResolving {
    var addresses: [String: [String]] = [:]

    func addresses(for host: String) async -> [String] {
        addresses[host] ?? ["93.184.215.14"]
    }
}

@Suite("対応サイトからのタイトル取得", .serialized)
struct TitleFetcherTests {
    private let fetcher = TitleFetcher(resolver: FixedResolver(), protocolClasses: [StubURLProtocol.self])

    @Test("ページのタイトルを取得する")
    func fetchesTitle() async {
        let url = "https://www.sirogohan.com/recipe/test-fetch/"
        StubURLProtocol.register(url, .init(body: Data(#"<head><meta property="og:title" content="肉じゃがのレシピ"></head>"#.utf8)))
        #expect(await fetcher.fetchTitle(for: url) == .fetched("肉じゃがのレシピ"))
    }

    @Test("取得したタイトルから、末尾のサイト名を除く")
    func removesSiteName() async {
        let url = "https://www.sirogohan.com/recipe/test-site-name/"
        StubURLProtocol.register(url, .init(body: Data("<head><title>肉じゃがの作り方：白ごはん.com</title></head>".utf8)))
        #expect(await fetcher.fetchTitle(for: url) == .fetched("肉じゃがの作り方"))
    }

    @Test("対応サイト以外には通信しない")
    func unsupportedSite() async {
        let url = "https://www.kurashiru.com/recipes/test"
        #expect(await fetcher.fetchTitle(for: url) == .unsupported)
        #expect(!StubURLProtocol.wasRequested(url))
    }

    @Test("宛先が公開IPアドレスでなければ通信しない")
    func privateAddress() async {
        let url = "https://www.kewpie.co.jp/recipes/test-private/"
        let fetcher = TitleFetcher(resolver: FixedResolver(addresses: ["www.kewpie.co.jp": ["10.0.0.5"]]), protocolClasses: [StubURLProtocol.self])
        #expect(await fetcher.fetchTitle(for: url) == .failed)
        #expect(!StubURLProtocol.wasRequested(url))
    }

    @Test("401・403・429などの応答では取得を止める", arguments: [401, 403, 429])
    func refusal(status: Int) async {
        let url = "https://www.mizkan.co.jp/ouchirecipe/recipe/?menu_id=\(status)"
        StubURLProtocol.register(url, .init(status: status, headers: ["Retry-After": "120"]))
        #expect(await fetcher.fetchTitle(for: url) == .refused(statusCode: status, retryAfter: 120))
    }

    @Test("HTML以外やエラーの応答は取得失敗にする")
    func failures() async {
        let json = "https://www.sirogohan.com/recipe/test-json/"
        StubURLProtocol.register(json, .init(headers: ["Content-Type": "application/json"], body: Data("{}".utf8)))
        #expect(await fetcher.fetchTitle(for: json) == .failed)

        let notFound = "https://www.sirogohan.com/recipe/test-404/"
        StubURLProtocol.register(notFound, .init(status: 404, body: Data("<title>見つかりません</title>".utf8)))
        #expect(await fetcher.fetchTitle(for: notFound) == .failed)
    }

    @Test("同じ対応サイト内への転送は3回まで追う")
    func redirects() async {
        let start = "https://www.sirogohan.com/recipe/test-redirect-0/"
        for index in 0..<3 {
            StubURLProtocol.register("https://www.sirogohan.com/recipe/test-redirect-\(index)/", .init(status: 301, redirect: "https://www.sirogohan.com/recipe/test-redirect-\(index + 1)/"))
        }
        StubURLProtocol.register("https://www.sirogohan.com/recipe/test-redirect-3/", .init(body: Data("<title>転送先</title>".utf8)))
        #expect(await fetcher.fetchTitle(for: start) == .fetched("転送先"))

        let tooMany = "https://www.sirogohan.com/recipe/test-loop-0/"
        for index in 0..<4 {
            StubURLProtocol.register("https://www.sirogohan.com/recipe/test-loop-\(index)/", .init(status: 301, redirect: "https://www.sirogohan.com/recipe/test-loop-\(index + 1)/"))
        }
        StubURLProtocol.register("https://www.sirogohan.com/recipe/test-loop-4/", .init(body: Data("<title>転送先</title>".utf8)))
        #expect(await fetcher.fetchTitle(for: tooMany) == .failed)
    }

    @Test("対象外の宛先への転送は追わない")
    func redirectOutside() async {
        let url = "https://www.kewpie.co.jp/recipes/test-outside/"
        StubURLProtocol.register(url, .init(status: 302, redirect: "https://www.example.com/recipes/"))
        StubURLProtocol.register("https://www.example.com/recipes/", .init(body: Data("<title>外部</title>".utf8)))
        #expect(await fetcher.fetchTitle(for: url) == .failed)
        #expect(!StubURLProtocol.wasRequested("https://www.example.com/recipes/"))
    }

    @Test("本文は展開後1 MiBまでしか読まない")
    func sizeLimit() async {
        let url = "https://www.sirogohan.com/recipe/test-large/"
        let padding = String(repeating: "a", count: TitleFetcher.maximumBytes)
        StubURLProtocol.register(url, .init(body: Data("<head><!--\(padding)--><title>遠すぎるタイトル</title></head>".utf8)))
        #expect(await fetcher.fetchTitle(for: url) == .notFound)
    }
}
