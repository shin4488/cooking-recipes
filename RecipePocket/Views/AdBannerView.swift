import GoogleMobileAds
import SwiftUI

/// 一覧の下に置くバナー広告。読み込めたときだけ場所を取り、読み込めない・同意がないときは何も表示しない
struct AdBannerView: View {
    /// 入力中や、ほかの画面を重ねている間は表示しない
    var isHidden: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var banner: BannerAd?

    var body: some View {
        ZStack {
            if let banner, banner.isLoaded, !isHidden {
                BannerViewContainer(bannerView: banner.view)
                    .frame(width: banner.size.width, height: banner.size.height)
                    .id(ObjectIdentifier(banner))
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
        // 広告の幅で一覧の幅が広がらないよう、幅は一覧から渡された幅に合わせる
        .frame(minWidth: 0, maxWidth: .infinity)
        .task(id: AppAds.shared.canLoadAds) {
            prepareBanner()
        }
        .onChange(of: scenePhase) { _, phase in
            // 通信できずに読み込めなかったときは、アプリに戻ったときに読み込み直す
            if phase == .active { banner?.reloadIfFailed() }
        }
    }

    private func prepareBanner() {
        guard AppAds.shared.canLoadAds, let unitID = AppInfo.adMobBannerUnitID else {
            // 同意を変えて広告を求められなくなったときは、読み込んだ広告も捨てる
            banner = nil
            return
        }
        if banner == nil { banner = BannerAd(unitID: unitID) }
    }
}

/// 一覧の下に出すバナー広告
@MainActor
@Observable
private final class BannerAd: NSObject, BannerViewDelegate {
    private(set) var isLoaded = false
    @ObservationIgnored let view: BannerView
    @ObservationIgnored private var hasFailed = false

    init(unitID: String) {
        // 一覧を広く見せるため、画面の幅に合わせて高くなるサイズではなく、高さが50ポイントで変わらない固定のサイズを使う
        view = BannerView(adSize: AdSizeBanner)
        super.init()
        view.adUnitID = unitID
        view.delegate = self
        load()
    }

    var size: CGSize { view.adSize.size }

    func reloadIfFailed() {
        if hasFailed, !isLoaded { load() }
    }

    private func load() {
        hasFailed = false
        // 保存したレシピの情報（URL・タイトル・タグ・検索語・記録のID）は、keywords・contentURL などとして渡さない
        view.load(Request())
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        isLoaded = true
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: any Error) {
        // 一度も読み込めていなければ場所を取らないまま。更新に失敗したときは、表示中の広告をそのまま残す
        hasFailed = true
    }
}

private struct BannerViewContainer: UIViewRepresentable {
    let bannerView: BannerView

    func makeUIView(context: Context) -> BannerView { bannerView }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
