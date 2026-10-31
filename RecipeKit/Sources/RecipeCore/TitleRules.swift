import Foundation

public enum TitleError: Error, Equatable, Sendable {
    case tooLong

    public var message: String {
        "タイトルは\(RecipeLimits.titleLength)文字以内にしてください"
    }
}

public enum TitleRules {
    /// 改行を空白にし、前後の空白を除く
    public static func clean(_ text: String) -> String {
        String(text.map { $0.isNewline ? " " : $0 }).trimmingCharacters(in: .whitespaces)
    }

    /// 手入力のタイトル。空なら nil、上限を超えたらエラー
    public static func validateManual(_ text: String) -> Result<String?, TitleError> {
        let title = clean(text)
        guard title.count <= RecipeLimits.titleLength else { return .failure(.tooLong) }
        return .success(title.isEmpty ? nil : title)
    }

    /// 共有元やサイトから受け取ったタイトル。空や上限を超える値は採用しない
    public static func acceptReceived(_ text: String) -> String? {
        let title = clean(text)
        guard !title.isEmpty, title.count <= RecipeLimits.titleLength else { return nil }
        return title
    }

    public static func displayTitle(_ title: String?, host: String?) -> String {
        if let title, !title.isEmpty { return title }
        guard let host else { return "タイトル未設定" }
        return "タイトル未設定（\(host)）"
    }
}
