import Foundation

/// 表記ゆれをそろえた比較用の文字列
public enum TextNormalization {
    /// 全角・半角と英字の大小文字をそろえる。タグの同一判定に使う
    public static func tagKey(_ text: String) -> String {
        text.precomposedStringWithCompatibilityMapping.lowercased()
    }

    /// タグの比較に加えて、ひらがなをカタカナにそろえる。検索に使う
    public static func searchKey(_ text: String) -> String {
        let key = tagKey(text)
        return key.applyingTransform(.hiraganaToKatakana, reverse: false) ?? key
    }
}
