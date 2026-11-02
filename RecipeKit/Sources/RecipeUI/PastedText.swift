import Foundation
import UniformTypeIdentifiers

/// 登録・編集画面のペーストのボタンが受け取る、クリップボードの中身
enum PastedText {
    /// 文字のほか、リンクを文字ではなく URL の種類だけでコピーしたものも受け取る。URL がないとボタンを押せないアプリがあるため
    static let contentTypes: [UTType] = [.url, .plainText]

    /// URL があれば URL を、なければ文字を取り出す。どちらも取り出せなければ nil を渡す
    static func load(from provider: NSItemProvider, completion: @escaping @Sendable (String?) -> Void) {
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                completion(url?.absoluteString)
            }
        } else if provider.canLoadObject(ofClass: String.self) {
            _ = provider.loadObject(ofClass: String.self) { text, _ in
                completion(text)
            }
        } else {
            completion(nil)
        }
    }
}
