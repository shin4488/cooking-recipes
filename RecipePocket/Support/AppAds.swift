import Foundation
import GoogleMobileAds
import UserMessagingPlatform

/// AdMob の広告と、UMP（Google User Messaging Platform）による同意の管理。
/// 同意の確認が済み、広告を求められる（canRequestAds）ときだけ SDK を開始する
@MainActor
@Observable
final class AppAds {
    static let shared = AppAds()

    /// 広告を読み込める。同意の確認が済み、SDK を開始した後に true になる
    private(set) var canLoadAds = false
    /// 同意の選択を変える入口を UMP が求めている。設定に「広告の同意の設定」を表示する
    private(set) var requiresPrivacyOptions = false

    @ObservationIgnored private var hasRequestedConsent = false
    @ObservationIgnored private var hasStartedSDK = false

    /// 起動時に呼ぶ。同意の情報を更新し、同意が必要な地域では同意の画面を出す。広告の ID がないビルドでは何もしない
    func gatherConsent() {
        guard AppInfo.adMobAppID != nil, AppInfo.adMobBannerUnitID != nil, !hasRequestedConsent else { return }
        #if DEBUG
        // App Store 用のスクリーンショットにテスト用の広告を写さない
        if ProcessInfo.processInfo.arguments.contains("-SeedScreenshotRecipes") { return }
        #endif
        hasRequestedConsent = true
        // UMP の説明には完了の処理を呼ぶスレッドが書かれていないため、メインアクターに移してから状態を変える
        ConsentInformation.shared.requestConsentInfoUpdate(with: Self.requestParameters()) { @Sendable error in
            Task { @MainActor in AppAds.shared.consentInfoUpdated(error: error) }
        }
        // 前回までの起動で同意を得ていれば、更新を待たずに広告を出し始める
        applyConsent()
    }

    /// 設定から、同意の選択を変える画面を出す
    func presentPrivacyOptions() {
        ConsentForm.presentPrivacyOptionsForm(from: nil) { @Sendable _ in
            Task { @MainActor in AppAds.shared.applyConsent() }
        }
    }

    private func consentInfoUpdated(error: (any Error)?) {
        guard error == nil else {
            // 更新できなかったときは、前回までの同意で判断する
            applyConsent()
            return
        }
        // 同意が要らない地域や同意済みのときは、画面を出さずに終わる
        ConsentForm.loadAndPresentIfRequired(from: nil) { @Sendable _ in
            Task { @MainActor in AppAds.shared.applyConsent() }
        }
    }

    private func applyConsent() {
        let consent = ConsentInformation.shared
        requiresPrivacyOptions = consent.privacyOptionsRequirementStatus == .required
        guard consent.canRequestAds else {
            canLoadAds = false
            return
        }
        if !hasStartedSDK {
            hasStartedSDK = true
            // 他社のアプリやサイトでの行動に基づく広告を出さないよう、パーソナライズしない広告を求める
            MobileAds.shared.requestConfiguration.publisherPrivacyPersonalizationState = .disabled
            // App Store の年齢制限（4+）に合う、一般向けの広告だけを求める
            MobileAds.shared.requestConfiguration.maxAdContentRating = .general
            MobileAds.shared.start()
        }
        canLoadAds = true
    }

    private static func requestParameters() -> RequestParameters {
        let parameters = RequestParameters()
        #if DEBUG
        // 欧州向けの同意の画面をシミュレータで確かめるとき（-UMPDebugGeographyEEA）だけ、欧州にいるものとして扱う
        if ProcessInfo.processInfo.arguments.contains("-UMPDebugGeographyEEA") {
            let debugSettings = DebugSettings()
            debugSettings.geography = .EEA
            parameters.debugSettings = debugSettings
        }
        #endif
        return parameters
    }
}
