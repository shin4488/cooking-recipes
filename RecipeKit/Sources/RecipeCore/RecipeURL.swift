import Foundation

public enum RecipeURLError: Error, Equatable, Sendable {
    case empty
    case tooLong
    case invalidFormat
    case unsupportedScheme
    case containsCredentials
    case internalHost
    case ipAddress

    public var message: String {
        switch self {
        case .empty: "URLを入力してください"
        case .tooLong: "URLは\(RecipeLimits.urlLength)文字以内にしてください"
        case .invalidFormat: "URLの形式が正しくありません"
        case .unsupportedScheme: "https:// または http:// から始まるURLを入力してください"
        case .containsCredentials: "ユーザー名やパスワードを含むURLは登録できません"
        case .internalHost: "localhostや社内向けのURLは登録できません"
        case .ipAddress: "IPアドレスで書かれたURLは登録できません"
        }
    }
}

/// レシピのURLの検証と、重複判定に使う比較用の文字列
public enum RecipeURL {
    struct Parts: Equatable {
        var scheme: String
        var host: String
        var port: String?
        /// パス・クエリ・フラグメント
        var rest: String

        var path: String {
            let end = rest.firstIndex(where: { $0 == "?" || $0 == "#" }) ?? rest.endIndex
            return String(rest[..<end])
        }
    }

    private static let internalSuffixes = [
        "localhost", "localdomain", "local", "internal", "intranet", "lan", "home", "corp", "private", "home.arpa",
    ]

    /// 前後の空白を除いたURLを返す。登録できないURLならエラーを返す
    public static func validate(_ input: String) -> Result<String, RecipeURLError> {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .failure(.empty) }
        guard text.count <= RecipeLimits.urlLength else { return .failure(.tooLong) }
        guard !text.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0) }) else {
            return .failure(.invalidFormat)
        }
        guard let separator = text.range(of: "://") else {
            return .failure(hasScheme(text) ? .unsupportedScheme : .invalidFormat)
        }
        let scheme = text[..<separator.lowerBound].lowercased()
        guard isValidScheme(scheme) else { return .failure(.invalidFormat) }
        guard scheme == "http" || scheme == "https" else { return .failure(.unsupportedScheme) }

        let authority = authority(of: text[separator.upperBound...])
        guard !authority.contains("@") else { return .failure(.containsCredentials) }
        guard !authority.hasPrefix("[") else { return .failure(.ipAddress) }
        guard let parts = parse(text) else { return .failure(.invalidFormat) }
        if let port = parts.port {
            guard let number = Int(port), (1...65_535).contains(number) else { return .failure(.invalidFormat) }
        }

        let host = hostForChecks(parts.host)
        guard isValidHostCharacters(host) else { return .failure(.invalidFormat) }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.contains(where: \.isEmpty) else { return .failure(.invalidFormat) }
        if labels.allSatisfy(isNumericLabel) { return .failure(.ipAddress) }
        if let last = labels.last, isNumericLabel(last) { return .failure(.invalidFormat) }
        if labels.count < 2 || internalSuffixes.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
            return .failure(.internalHost)
        }
        guard URL(string: text) != nil else { return .failure(.invalidFormat) }
        return .success(text)
    }

    /// 重複判定用の文字列。前後の空白、スキーム・ホストの大小文字、既定ポートだけをそろえる
    public static func duplicateKey(for url: String) -> String {
        let text = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parts = parse(text) else { return text }
        let scheme = parts.scheme.lowercased()
        var port = parts.port
        if (scheme == "http" && port == "80") || (scheme == "https" && port == "443") {
            port = nil
        }
        return scheme + "://" + parts.host.lowercased() + (port.map { ":" + $0 } ?? "") + parts.rest
    }

    /// 小文字にそろえたホスト名。末尾のドットは除く
    public static func host(of url: String) -> String? {
        guard let parts = parse(url.trimmingCharacters(in: .whitespacesAndNewlines)), !parts.host.isEmpty else { return nil }
        return hostForChecks(parts.host)
    }

    static func parse(_ text: String) -> Parts? {
        guard let separator = text.range(of: "://") else { return nil }
        let scheme = String(text[..<separator.lowerBound])
        guard isValidScheme(scheme.lowercased()) else { return nil }
        let afterScheme = text[separator.upperBound...]
        let authority = authority(of: afterScheme)
        guard !authority.contains("@"), !authority.hasPrefix("[") else { return nil }
        let rest = String(afterScheme.dropFirst(authority.count))

        var host = authority
        var port: String?
        if let colon = authority.lastIndex(of: ":") {
            host = String(authority[..<colon])
            let value = String(authority[authority.index(after: colon)...])
            guard value.allSatisfy(\.isASCIIDigit) else { return nil }
            port = value.isEmpty ? nil : value
        }
        guard !host.isEmpty else { return nil }
        return Parts(scheme: scheme, host: host, port: port, rest: rest)
    }

    private static func authority(of text: Substring) -> String {
        let end = text.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) ?? text.endIndex
        return String(text[..<end])
    }

    private static func hostForChecks(_ host: String) -> String {
        let lowered = host.lowercased()
        return lowered.hasSuffix(".") ? String(lowered.dropLast()) : lowered
    }

    private static func hasScheme(_ text: String) -> Bool {
        guard let colon = text.firstIndex(of: ":") else { return false }
        return isValidScheme(text[..<colon].lowercased())
    }

    private static func isValidScheme(_ scheme: String) -> Bool {
        guard let first = scheme.first, first.isASCIILetter else { return false }
        return scheme.allSatisfy { $0.isASCIILetter || $0.isASCIIDigit || $0 == "+" || $0 == "-" || $0 == "." }
    }

    private static func isValidHostCharacters(_ host: String) -> Bool {
        host.allSatisfy { !$0.isASCII || $0.isASCIILetter || $0.isASCIIDigit || $0 == "-" || $0 == "." || $0 == "_" }
    }

    /// 10進・16進の数値だけのラベル。すべてのラベルがこれならIPアドレスとみなす
    private static func isNumericLabel(_ label: Substring) -> Bool {
        if label.allSatisfy(\.isASCIIDigit) { return true }
        let lowered = label.lowercased()
        return lowered.hasPrefix("0x") && lowered.dropFirst(2).allSatisfy(\.isHexDigit)
    }
}

extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
    var isASCIILetter: Bool { isASCII && isLetter }
}
