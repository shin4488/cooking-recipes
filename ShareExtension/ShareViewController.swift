import RecipeCore
import RecipeData
import RecipeUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 共有シートから開く画面。通信を待たず、本体を起動せずに、この画面の中で保存を終える
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        Task {
            let content = await loadSharedContent()
            show(makeRootView(content))
        }
    }

    private func makeRootView(_ content: SharedContent) -> AnyView {
        guard !content.urls.isEmpty else {
            return AnyView(ShareMessageView(message: "共有された内容にURLが見つかりませんでした。", onClose: cancel))
        }
        guard let container = try? RecipeContainer.shared() else {
            return AnyView(ShareMessageView(message: "保存データを開けませんでした。もう一度お試しください。", onClose: cancel))
        }
        let repository = RecipeRepository(container: container)
        let model = RecipeFormModel(urlChoices: content.urls, sharedTitle: content.title, savedTags: (try? repository.savedTags()) ?? [])
        return AnyView(ShareRecipeView(model: model, repository: repository, onFinish: finish, onCancel: cancel))
    }

    private func show(_ root: AnyView) {
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// 取消時は保存しない
    private func cancel() {
        extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
    }

    private func loadSharedContent() async -> SharedContent {
        var urls: [URL] = []
        var texts: [String] = []
        var titles: [String] = []
        for item in extensionContext?.inputItems.compactMap({ $0 as? NSExtensionItem }) ?? [] {
            if let title = item.attributedTitle?.string { titles.append(title) }
            if let text = item.attributedContentText?.string { titles.append(text) }
            for provider in item.attachments ?? [] {
                if provider.canLoadObject(ofClass: URL.self), let url = await load(URL.self, from: provider) {
                    urls.append(url)
                } else if provider.canLoadObject(ofClass: String.self), let text = await load(String.self, from: provider) {
                    texts.append(text)
                }
            }
        }
        return SharedContent.make(urls: urls, texts: texts, titles: titles)
    }

    private func load<T: _ObjectiveCBridgeable & Sendable>(_ type: T.Type, from provider: NSItemProvider) async -> T? where T._ObjectiveCType: NSItemProviderReading {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: type) { value, _ in
                continuation.resume(returning: value)
            }
        }
    }
}
