import GoogleMobileAds
import SwiftUI

/// 一覧の下に置くバナー広告。読み込めたときだけ場所を取り、読み込めない・同意がないときは何も表示しない
struct AdBannerView: View {
    /// 入力中や、ほかの画面を重ねている間は表示しない
    var isHidden: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var banner: BannerAd?
    @State private var width: CGFloat = 0

    private struct LoadCondition: Equatable {
        var width: CGFloat
        var canLoadAds: Bool
    }

    var body: some View {
        ZStack {
            // 画面の回転などで幅が変わったら、新しい幅の広告を読み込むまで前の広告は出さない
            if let banner, banner.isLoaded, banner.width == width, !isHidden {
                BannerViewContainer(bannerView: banner.view)
                    .frame(width: banner.size.width, height: banner.size.height)
                    .id(ObjectIdentifier(banner))
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
        // 広告の幅で一覧の幅が広がらないよう、幅は一覧から渡された幅に合わせる
        .frame(minWidth: 0, maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .task(id: LoadCondition(width: width, canLoadAds: AppAds.shared.canLoadAds)) {
            await prepareBanner()
        }
        .onChange(of: scenePhase) { _, phase in
            // 通信できずに読み込めなかったときは、アプリに戻ったときに読み込み直す
            if phase == .active { banner?.reloadIfFailed() }
        }
    }

    private func prepareBanner() async {
        guard AppAds.shared.canLoadAds, width > 0, let unitID = AppInfo.adMobBannerUnitID else {
            // 同意を変えて広告を求められなくなったときは、読み込んだ広告も捨てる
            banner = nil
            return
        }
        guard banner?.width != width else { return }
        // 起動の直後や画面の回転で幅が続けて変わる間は待ち、決まった幅で1回だけ読み込む
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        banner = BannerAd(unitID: unitID, width: width)
    }
}

/// 1つの幅に合わせて読み込むバナー広告
@MainActor
@Observable
private final class BannerAd: NSObject, BannerViewDelegate, AdSizeDelegate {
    private(set) var isLoaded = false
    /// 表示する大きさ。読み込んだ広告が上限より低いときは、その広告の高さになる
    private(set) var size: CGSize
    let width: CGFloat
    @ObservationIgnored let view: BannerView
    @ObservationIgnored private var hasFailed = false

    init(unitID: String, width: CGFloat) {
        self.width = width
        let adSize = Self.adSize(width: width)
        size = adSize.size
        view = BannerView(adSize: adSize)
        super.init()
        view.adUnitID = unitID
        view.delegate = self
        view.adSizeDelegate = self
        load()
    }

    /// 一覧を広く見せるため、Google が画面の幅と向きから決める高さ（largeAnchoredAdaptiveBanner）の4分の3を、高さの上限にする。
    /// 高さの上限を指定できるのは inlineAdaptiveBanner だけで、幅は画面の幅のまま、上限までの高さの広告が返る
    private static func adSize(width: CGFloat) -> AdSize {
        let standardHeight = largeAnchoredAdaptiveBanner(width: width).size.height
        // 上限は50ポイント以上にすることを SDK が勧めている
        let maxHeight = max(50, (standardHeight * 0.75).rounded())
        return inlineAdaptiveBanner(width: width, maxHeight: maxHeight)
    }

    func reloadIfFailed() {
        if hasFailed, !isLoaded { load() }
    }

    private func load() {
        hasFailed = false
        // 保存したレシピの情報（URL・タイトル・タグ・検索語・記録のID）は、keywords・contentURL などとして渡さない
        view.load(Request())
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        size = bannerView.adSize.size
        isLoaded = true
    }

    func adView(_ bannerView: BannerView, willChangeAdSizeTo size: AdSize) {
        self.size = size.size
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
