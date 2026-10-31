import Testing
@testable import RecipeCore

@Suite("URLの受け付け")
struct RecipeURLValidationTests {
    @Test("HTTP・HTTPSの絶対URLは、前後の空白を除いてそのまま受け付ける", arguments: [
        ("https://www.kewpie.co.jp/recipes/recipe/QP10220/", "https://www.kewpie.co.jp/recipes/recipe/QP10220/"),
        ("  http://example.com/a?b=1#c \n", "http://example.com/a?b=1#c"),
        ("HTTPS://Example.COM:8443/Path", "HTTPS://Example.COM:8443/Path"),
        ("https://例え.jp/カレー", "https://例え.jp/カレー"),
    ])
    func accepts(input: String, expected: String) {
        #expect(RecipeURL.validate(input) == .success(expected))
    }

    @Test("4,096文字までは受け付け、超えると拒否する")
    func lengthBoundary() {
        let prefix = "https://example.com/"
        let atLimit = prefix + String(repeating: "a", count: 4_096 - prefix.count)
        #expect(RecipeURL.validate(atLimit) == .success(atLimit))
        #expect(RecipeURL.validate(atLimit + "a") == .failure(.tooLong))
    }

    @Test("登録できないURLは理由ごとに拒否する", arguments: [
        ("", RecipeURLError.empty),
        (" \n ", .empty),
        ("example.com/recipe", .invalidFormat),
        ("https://exa mple.com/", .invalidFormat),
        ("https://example.com:99999/", .invalidFormat),
        ("https:///path", .invalidFormat),
        ("ftp://example.com/file", .unsupportedScheme),
        ("mailto:someone@example.com", .unsupportedScheme),
        ("https://user:pass@example.com/", .containsCredentials),
        ("https://user@example.com/", .containsCredentials),
        ("http://localhost:8080/", .internalHost),
        ("https://app.localhost/", .internalHost),
        ("https://printer.local/", .internalHost),
        ("https://intranet/", .internalHost),
        ("https://wiki.corp/", .internalHost),
        ("https://192.168.0.1/", .ipAddress),
        ("https://8.8.8.8/", .ipAddress),
        ("https://[::1]/", .ipAddress),
        ("https://0x7f.0.0.1/", .ipAddress),
        ("https://2130706433/", .ipAddress),
    ])
    func rejects(input: String, expected: RecipeURLError) {
        #expect(RecipeURL.validate(input) == .failure(expected))
    }
}

@Suite("URLの重複判定")
struct RecipeURLDuplicateTests {
    @Test("前後の空白、スキーム・ホストの大小文字、既定ポートは同じURLとみなす", arguments: [
        ("  HTTPS://Example.COM:443/Path?Q=1#F ", "https://example.com/Path?Q=1#F"),
        ("http://example.com:80/a", "http://example.com/a"),
        ("https://WWW.Sirogohan.com/recipe/x/", "https://www.sirogohan.com/recipe/x/"),
    ])
    func sameURL(lhs: String, rhs: String) {
        #expect(RecipeURL.duplicateKey(for: lhs) == RecipeURL.duplicateKey(for: rhs))
    }

    @Test("パス・クエリ・フラグメント・既定以外のポートが違えば別のURLとみなす", arguments: [
        ("https://example.com/path", "https://example.com/Path"),
        ("https://example.com/watch?v=1", "https://example.com/watch?v=1&t=30"),
        ("https://example.com/a#step1", "https://example.com/a#step2"),
        ("https://example.com:8443/a", "https://example.com/a"),
        ("https://example.com", "https://example.com/"),
        ("http://example.com/a", "https://example.com/a"),
        ("https://youtu.be/abc", "https://www.youtube.com/watch?v=abc"),
    ])
    func differentURL(lhs: String, rhs: String) {
        #expect(RecipeURL.duplicateKey(for: lhs) != RecipeURL.duplicateKey(for: rhs))
    }

    @Test("ホスト名は小文字にそろえて返す")
    func host() {
        #expect(RecipeURL.host(of: "https://WWW.Example.com:8080/a") == "www.example.com")
        #expect(RecipeURL.host(of: "not a url") == nil)
    }
}
