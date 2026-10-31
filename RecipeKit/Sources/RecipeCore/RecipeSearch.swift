import Foundation

/// 検索の対象（タイトル・タグ・ホスト名）を、表記ゆれをそろえて1つにまとめたもの
public struct SearchTarget: Sendable {
    private let bytes: [UInt8]

    public init(title: String?, tags: [String], host: String?) {
        let fields = [title ?? ""] + tags + [host ?? ""]
        // 項目をまたいで一致しないよう、入力できない文字で区切る
        bytes = Array(fields.map(TextNormalization.searchKey).joined(separator: "\u{0}").utf8)
    }

    /// すべての条件が、いずれかの項目に部分一致するか
    public func matches(_ conditions: [SearchKeyword]) -> Bool {
        conditions.allSatisfy(contains)
    }

    private func contains(_ keyword: SearchKeyword) -> Bool {
        guard !keyword.bytes.isEmpty else { return true }
        guard bytes.count >= keyword.bytes.count else { return false }
        return bytes.withUnsafeBytes { haystack in
            keyword.bytes.withUnsafeBytes { needle in
                memmem(haystack.baseAddress, haystack.count, needle.baseAddress, needle.count) != nil
            }
        }
    }
}

/// 表記ゆれをそろえた検索条件
public struct SearchKeyword: Sendable {
    fileprivate let bytes: [UInt8]

    public init(_ condition: String) {
        bytes = Array(TextNormalization.searchKey(condition).utf8)
    }
}
