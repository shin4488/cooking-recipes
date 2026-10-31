import Foundation

public enum TitleFetchOutcome: Equatable, Sendable {
    case fetched(String)
    /// ページは取得できたが、使えるタイトルがなかった
    case notFound
    case unsupported
    /// サイトが取得を拒否した（401・403・429など）。このサイトからの取得を止める
    case refused(statusCode: Int, retryAfter: TimeInterval?)
    case failed
}

public protocol HostResolving: Sendable {
    func addresses(for host: String) async -> [String]
}

public struct SystemHostResolver: HostResolving {
    public init() {}

    public func addresses(for host: String) async -> [String] {
        await Task.detached {
            var hints = addrinfo()
            hints.ai_family = AF_UNSPEC
            hints.ai_socktype = SOCK_STREAM
            var list: UnsafeMutablePointer<addrinfo>?
            guard getaddrinfo(host, nil, &hints, &list) == 0, let first = list else { return [] }
            defer { freeaddrinfo(first) }
            var result: [String] = []
            for info in sequence(first: first, next: { $0.pointee.ai_next }) {
                var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                switch info.pointee.ai_family {
                case AF_INET:
                    var address = info.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
                    inet_ntop(AF_INET, &address, &buffer, socklen_t(buffer.count))
                case AF_INET6:
                    var address = info.pointee.ai_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee.sin6_addr }
                    inet_ntop(AF_INET6, &address, &buffer, socklen_t(buffer.count))
                default:
                    continue
                }
                result.append(buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) })
            }
            return result
        }.value
    }
}

/// 対応サイトのページを1件取得し、タイトルを取り出す。
/// 許可したHTTPSの宛先だけに接続し、Cookie・キャッシュ・JavaScriptは使わない
public struct TitleFetcher: Sendable {
    public static let timeout: TimeInterval = 20
    public static let maximumBytes = 1_048_576
    public static let maximumRedirects = 3
    /// 取得を止める応答
    static let refusalStatusCodes: Set<Int> = [401, 403, 429, 451]

    private let resolver: any HostResolving
    private let protocolClasses: [AnyClass]?

    public init(resolver: any HostResolving = SystemHostResolver()) {
        self.init(resolver: resolver, protocolClasses: nil)
    }

    /// テストで通信を差し替えるための初期化
    init(resolver: any HostResolving, protocolClasses: [AnyClass]?) {
        self.resolver = resolver
        self.protocolClasses = protocolClasses
    }

    public func fetchTitle(for url: String) async -> TitleFetchOutcome {
        guard let site = SupportedSite.fetchableSite(for: url), let requestURL = URL(string: url) else { return .unsupported }
        guard await isPublicHost(requestURL.host()) else { return .failed }

        let loader = PageLoader(site: site, resolver: resolver, protocolClasses: protocolClasses)
        let page = await loader.load(requestURL)
        if let status = page.statusCode, Self.refusalStatusCodes.contains(status) {
            return .refused(statusCode: status, retryAfter: page.retryAfter)
        }
        guard page.isComplete,
              let status = page.statusCode, (200..<300).contains(status),
              page.isHTML,
              page.remoteAddresses.allSatisfy(PublicAddress.isPublic)
        else { return .failed }
        return HTMLTitleExtractor.title(from: page.data, contentType: page.contentType)
            .map { .fetched(site.removingSiteName(from: $0)) } ?? .notFound
    }

    func isPublicHost(_ host: String?) async -> Bool {
        guard let host else { return false }
        let addresses = await resolver.addresses(for: host)
        return !addresses.isEmpty && addresses.allSatisfy(PublicAddress.isPublic)
    }
}

struct LoadedPage: Sendable {
    var statusCode: Int?
    var contentType: String?
    var retryAfter: TimeInterval?
    var data = Data()
    var remoteAddresses: [String] = []
    /// 通信エラーで中断していない。head を読み終えて止めた場合も含む
    var isComplete = false

    var isHTML: Bool {
        guard let type = contentType?.split(separator: ";").first?.trimmingCharacters(in: .whitespaces).lowercased() else { return false }
        return type == "text/html" || type == "application/xhtml+xml"
    }
}

/// URLSession の通知を受けて、上限までの本文と接続先を集める。通知は直列のキューで受ける
private final class PageLoader: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let site: SupportedSite
    private let resolver: any HostResolving
    private let protocolClasses: [AnyClass]?
    private var page = LoadedPage()
    private var redirectCount = 0
    private var stoppedEarly = false
    private var continuation: CheckedContinuation<LoadedPage, Never>?

    init(site: SupportedSite, resolver: any HostResolving, protocolClasses: [AnyClass]?) {
        self.site = site
        self.resolver = resolver
        self.protocolClasses = protocolClasses
    }

    func load(_ url: URL) async -> LoadedPage {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = TitleFetcher.timeout
        configuration.timeoutIntervalForResource = TitleFetcher.timeout
        configuration.waitsForConnectivity = false
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        if let protocolClasses { configuration.protocolClasses = protocolClasses }

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
        let request = {
            var request = URLRequest(url: url)
            request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
            request.setValue("ja", forHTTPHeaderField: "Accept-Language")
            return request
        }()

        let result = await withCheckedContinuation { continuation in
            queue.addOperation {
                self.continuation = continuation
                session.dataTask(with: request).resume()
            }
        }
        session.finishTasksAndInvalidate()
        return result
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        // 転送を断ると転送元の応答（3xx）で終わり、取得失敗になる
        redirectCount += 1
        guard redirectCount <= TitleFetcher.maximumRedirects,
              let url = request.url,
              SupportedSite.fetchableSite(for: url.absoluteString) == site
        else {
            completionHandler(nil)
            return
        }
        let resolver = resolver
        Task {
            let addresses = await resolver.addresses(for: url.host() ?? "")
            let allowed = !addresses.isEmpty && addresses.allSatisfy(PublicAddress.isPublic)
            completionHandler(allowed ? request : nil)
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        let http = response as? HTTPURLResponse
        page.statusCode = http?.statusCode
        page.contentType = http?.value(forHTTPHeaderField: "Content-Type")
        page.retryAfter = http?.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
        let accepted = page.statusCode.map { (200..<300).contains($0) } == true && page.isHTML
        completionHandler(accepted ? .allow : .cancel)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let searchStart = max(0, page.data.count - 7)
        page.data.append(data.prefix(TitleFetcher.maximumBytes - page.data.count))
        let tail = page.data[(page.data.startIndex + searchStart)...]
        // タイトルは head の中にあるため、head を読み終えたら止める
        if page.data.count >= TitleFetcher.maximumBytes
            || tail.range(of: Data("</head>".utf8)) != nil
            || tail.range(of: Data("</HEAD>".utf8)) != nil {
            stoppedEarly = true
            dataTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        page.remoteAddresses = metrics.transactionMetrics
            .filter { $0.resourceFetchType == .networkLoad }
            .compactMap(\.remoteAddress)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let cancelledByLoader = (error as? URLError)?.code == .cancelled && stoppedEarly
        page.isComplete = error == nil || cancelledByLoader
        continuation?.resume(returning: page)
        continuation = nil
    }
}
