import Foundation

// アプリと同じ文面（PolicyText）から、公開する Web ページを作る。
// 運営者名と問い合わせ先は git で管理しない Config/Local.xcconfig から読み、出力先も git で管理しない

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("使い方: generate <Config/Local.xcconfig> <出力先>\n".utf8))
    exit(2)
}
let configPath = arguments[1]
let outputURL = URL(fileURLWithPath: arguments[2], isDirectory: true)

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

/// xcconfig の `KEY = value` を読む。`//` 以降はコメントとして扱う
func readConfig(_ path: String) -> [String: String] {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        fail("\(path) がありません。docs/release-checklist.md の手順で作ってください")
    }
    var values: [String: String] = [:]
    for line in text.split(whereSeparator: \.isNewline) {
        let content = line.components(separatedBy: "//")[0]
        let pair = content.split(separator: "=", maxSplits: 1)
        guard pair.count == 2 else { continue }
        values[pair[0].trimmingCharacters(in: .whitespaces)] = pair[1].trimmingCharacters(in: .whitespaces)
    }
    return values
}

let config = readConfig(configPath)
let missing = ["OPERATOR_NAME", "CONTACT_EMAIL"].filter { (config[$0] ?? "").isEmpty }
guard missing.isEmpty else {
    fail("\(configPath) に \(missing.joined(separator: "・")) がありません")
}
let owner = PolicyText.Operator(name: config["OPERATOR_NAME"]!, contactEmail: config["CONTACT_EMAIL"]!)

func escape(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

func paragraphs(_ texts: [String]) -> String {
    texts.map { "<p>\(escape($0))</p>" }.joined(separator: "\n")
}

func render(_ section: PolicyText.Section) -> String {
    var html = section.title.map { "<h2>\(escape($0))</h2>\n" } ?? ""
    html += paragraphs(section.paragraphs)
    for destination in section.destinations {
        html += "\n<h3>\(escape(destination.name))</h3>\n"
        html += paragraphs(["送る情報：\(destination.information)", "目的：\(destination.purpose)"])
        if !destination.links.isEmpty {
            let items = destination.links.map { "<li><a href=\"\(escape($0.url.absoluteString))\">\(escape($0.title))</a></li>" }
            html += "\n<ul>\n\(items.joined(separator: "\n"))\n</ul>"
        }
    }
    return "<section>\n\(html)\n</section>"
}

let mailLink = "<a href=\"mailto:\(escape(owner.contactEmail))\">\(escape(owner.contactEmail))</a>"
let operatorSection = "<section>\n<h2>運営者</h2>\n\(paragraphs(["運営者：\(owner.name)"]))\n<p>問い合わせ先：\(mailLink)</p>\n</section>"

func page(title: String, body: String) -> String {
    let heading = title == PolicyText.appName ? PolicyText.appName : "\(title)｜\(PolicyText.appName)"
    return """
    <!doctype html>
    <html lang="ja">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>\(escape(heading))</title>
    <style>
    :root { color-scheme: light dark; --accent: #A05350; --text: #1d1d1f; --sub: #6e6e73; --bg: #ffffff; }
    @media (prefers-color-scheme: dark) { :root { --accent: #CC7A72; --text: #f5f5f7; --sub: #a1a1a6; --bg: #000000; } }
    body { margin: 0; background: var(--bg); color: var(--text); font-family: -apple-system, "Hiragino Sans", sans-serif; line-height: 1.7; }
    header, main, footer { max-width: 720px; margin: 0 auto; padding: 0 16px; }
    header { padding-top: 24px; }
    header a.home { color: var(--text); font-weight: bold; text-decoration: none; }
    nav { display: flex; flex-wrap: wrap; gap: 4px 16px; margin-top: 8px; font-size: 0.9em; }
    a { color: var(--accent); }
    h1 { font-size: 1.5em; margin: 24px 0 8px; }
    h2 { font-size: 1.15em; margin: 28px 0 4px; }
    h3 { font-size: 1em; margin: 18px 0 0; }
    p { margin: 6px 0; }
    footer { margin-top: 40px; padding-bottom: 32px; color: var(--sub); font-size: 0.85em; }
    </style>
    </head>
    <body>
    <header>
    <a class="home" href="/">\(escape(PolicyText.appName))</a>
    <nav><a href="/terms">\(escape(PolicyText.termsTitle))</a><a href="/privacy">\(escape(PolicyText.privacyTitle))</a><a href="/support">問い合わせ</a></nav>
    </header>
    <main>
    <h1>\(escape(title))</h1>
    \(body)
    </main>
    <footer>\(escape(PolicyText.appName))</footer>
    </body>
    </html>

    """
}

let pages: [String: String] = [
    "index.html": page(title: PolicyText.appName, body: paragraphs([PolicyText.summary])),
    "terms.html": page(title: PolicyText.termsTitle, body: PolicyText.terms(operator: owner).map(render).joined(separator: "\n")),
    "privacy.html": page(
        title: PolicyText.privacyTitle,
        body: (PolicyText.privacy.map(render) + [operatorSection]).joined(separator: "\n")
    ),
    "support.html": page(
        title: "問い合わせ",
        body: """
        <p>\(escape(PolicyText.appName))についての相談や不具合の連絡は、次のアドレスへメールでお送りください。アプリの「設定」の「問い合わせ（メール）」からも送れます。</p>
        <p>\(mailLink)</p>
        <p>問い合わせで受け取った情報の扱いは、<a href="/privacy">\(escape(PolicyText.privacyTitle))</a>に記載しています。</p>
        """
    ),
]

do {
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
    for (name, html) in pages {
        try Data(html.utf8).write(to: outputURL.appending(path: name))
    }
} catch {
    fail("Web ページを書き出せませんでした: \(error.localizedDescription)")
}
print("\(outputURL.path(percentEncoded: false)) に \(pages.count) ページを作りました")
