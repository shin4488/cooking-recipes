import Foundation

/// HTMLから `og:title`、なければ `title` 要素を取り出す。本文・画像などは読み取らない
public enum HTMLTitleExtractor {
    public static func title(from data: Data, contentType: String?) -> String? {
        guard let html = decode(data, contentType: contentType) else { return nil }
        return [ogTitle(in: html), titleElement(in: html)].lazy
            .compactMap { $0 }
            .compactMap { TitleRules.acceptReceived(collapseWhitespace(decodeEntities($0))) }
            .first
    }

    // MARK: - 文字コード

    static func decode(_ data: Data, contentType: String?) -> String? {
        let declared = contentType.flatMap(charset(inContentType:)) ?? charset(inMeta: data)
        if let declared, let encoding = encoding(named: declared) {
            return string(from: data, encoding: encoding)
        }
        for encoding in [String.Encoding.utf8, .shiftJIS, .japaneseEUC] {
            if let text = string(from: data, encoding: encoding) { return text }
        }
        return nil
    }

    /// 読み込みを途中で止めた場合に備え、末尾の欠けた文字を除いて変換する
    private static func string(from data: Data, encoding: String.Encoding) -> String? {
        for trim in 0...3 where data.count >= trim {
            if let text = String(data: data.dropLast(trim), encoding: encoding) { return text }
        }
        return nil
    }

    static func charset(inContentType contentType: String) -> String? {
        for parameter in contentType.split(separator: ";").dropFirst() {
            let pair = parameter.split(separator: "=", maxSplits: 1)
            guard pair.count == 2, pair[0].trimmingCharacters(in: .whitespaces).lowercased() == "charset" else { continue }
            return pair[1].trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
        }
        return nil
    }

    /// 先頭部分の `<meta charset>` と `<meta http-equiv="Content-Type">` を読む
    static func charset(inMeta data: Data) -> String? {
        let head = String(decoding: data.prefix(4_096), as: UTF8.self)
        for tag in tags(named: "meta", in: head) {
            let attributes = self.attributes(of: tag)
            if let charset = attributes["charset"] { return charset }
            if attributes["http-equiv"]?.lowercased() == "content-type", let content = attributes["content"] {
                return charset(inContentType: content)
            }
        }
        return nil
    }

    private static func encoding(named name: String) -> String.Encoding? {
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
        guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
    }

    // MARK: - タイトル

    static func ogTitle(in html: String) -> String? {
        for tag in tags(named: "meta", in: html) {
            let attributes = self.attributes(of: tag)
            let property = (attributes["property"] ?? attributes["name"])?.lowercased()
            if property == "og:title", let content = attributes["content"] { return content }
        }
        return nil
    }

    static func titleElement(in html: String) -> String? {
        guard let open = html.range(of: "<title", options: .caseInsensitive),
              let openEnd = html.range(of: ">", range: open.upperBound..<html.endIndex),
              let close = html.range(of: "</title", options: .caseInsensitive, range: openEnd.upperBound..<html.endIndex)
        else { return nil }
        return String(html[openEnd.upperBound..<close.lowerBound])
    }

    /// `<name ...>` の開始タグの属性部分を順に返す
    static func tags(named name: String, in html: String) -> [Substring] {
        var result: [Substring] = []
        var searchStart = html.startIndex
        while let open = html.range(of: "<" + name, options: .caseInsensitive, range: searchStart..<html.endIndex) {
            guard let close = tagEnd(in: html, from: open.upperBound) else { break }
            let next = html[open.upperBound...].first
            if next.map({ $0.isWhitespace || $0 == "/" || $0 == ">" }) == true {
                result.append(html[open.upperBound..<close])
            }
            searchStart = html.index(after: close)
        }
        return result
    }

    /// 引用符の中の `>` を飛ばして、タグを閉じる `>` の位置を返す
    private static func tagEnd(in html: String, from start: String.Index) -> String.Index? {
        var quote: Character?
        var index = start
        while index < html.endIndex {
            let character = html[index]
            if let open = quote {
                if character == open { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == ">" {
                return index
            }
            index = html.index(after: index)
        }
        return nil
    }

    /// 属性名を小文字にした辞書。値の引用符は外す
    static func attributes(of tag: Substring) -> [String: String] {
        var result: [String: String] = [:]
        var index = tag.startIndex
        func skipWhitespace() {
            while index < tag.endIndex, tag[index].isWhitespace || tag[index] == "/" { index = tag.index(after: index) }
        }
        while true {
            skipWhitespace()
            guard index < tag.endIndex else { break }
            let nameStart = index
            while index < tag.endIndex, !tag[index].isWhitespace, tag[index] != "=", tag[index] != "/" {
                index = tag.index(after: index)
            }
            let name = tag[nameStart..<index].lowercased()
            while index < tag.endIndex, tag[index].isWhitespace { index = tag.index(after: index) }
            guard index < tag.endIndex, tag[index] == "=" else {
                if !name.isEmpty { result[name] = result[name] ?? "" }
                continue
            }
            index = tag.index(after: index)
            while index < tag.endIndex, tag[index].isWhitespace { index = tag.index(after: index) }
            guard index < tag.endIndex else { break }
            let value: Substring
            if tag[index] == "\"" || tag[index] == "'" {
                let quote = tag[index]
                let valueStart = tag.index(after: index)
                let valueEnd = tag[valueStart...].firstIndex(of: quote) ?? tag.endIndex
                value = tag[valueStart..<valueEnd]
                index = valueEnd < tag.endIndex ? tag.index(after: valueEnd) : valueEnd
            } else {
                let valueStart = index
                while index < tag.endIndex, !tag[index].isWhitespace { index = tag.index(after: index) }
                value = tag[valueStart..<index]
            }
            if !name.isEmpty, result[name] == nil { result[name] = String(value) }
        }
        return result
    }

    /// ブラウザがタイトルを表示するときと同じく、ASCIIの空白の連続を1つにまとめる
    static func collapseWhitespace(_ text: String) -> String {
        let asciiWhitespace: Set<Character> = [" ", "\t", "\n", "\r", "\r\n", "\u{0C}"]
        return text.split(whereSeparator: asciiWhitespace.contains).joined(separator: " ")
    }

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        let named = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " "]
        var result = ""
        var index = text.startIndex
        while index < text.endIndex {
            guard text[index] == "&",
                  let semicolon = text[index...].prefix(12).firstIndex(of: ";")
            else {
                result.append(text[index])
                index = text.index(after: index)
                continue
            }
            let entity = text[text.index(after: index)..<semicolon]
            if let decoded = decodeEntity(entity, named: named) {
                result.append(decoded)
                index = text.index(after: semicolon)
            } else {
                result.append(text[index])
                index = text.index(after: index)
            }
        }
        return result
    }

    private static func decodeEntity(_ entity: Substring, named: [String: String]) -> String? {
        if entity.hasPrefix("#") {
            let digits = entity.dropFirst()
            let value: UInt32? = digits.first == "x" || digits.first == "X"
                ? UInt32(digits.dropFirst(), radix: 16)
                : UInt32(digits, radix: 10)
            return value.flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        return named[String(entity)]
    }
}
