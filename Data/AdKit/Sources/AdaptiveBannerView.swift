import SwiftUI
import GoogleMobileAds

/// A bottom-anchored adaptive AdMob banner, ready to drop into any SwiftUI
/// layout. It sizes itself to the current width and reserves the matching
/// adaptive height so the surrounding layout doesn't jump when the ad loads.
///
/// ```swift
/// .safeAreaInset(edge: .bottom) { AdaptiveBannerView() }
/// ```
public struct AdaptiveBannerView: View {
    private let unitID: String

    public init(unitID: String = AdConfig.bannerUnitID) {
        self.unitID = unitID
    }

    public var body: some View {
        GeometryReader { proxy in
            let adSize = currentOrientationAnchoredAdaptiveBanner(width: proxy.size.width)
            BannerRepresentable(unitID: unitID, adSize: adSize)
                .frame(width: adSize.size.width, height: adSize.size.height)
        }
        .frame(height: bannerHeight)
    }

    /// Adaptive banner height for the current screen width. Anchored adaptive
    /// banners cap the height (~50–90pt), so this is stable enough to reserve.
    private var bannerHeight: CGFloat {
        let width = UIScreen.main.bounds.width
        return currentOrientationAnchoredAdaptiveBanner(width: width).size.height
    }
}

private struct BannerRepresentable: UIViewRepresentable {
    let unitID: String
    let adSize: AdSize

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = unitID
        banner.rootViewController = Self.keyRootViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        uiView.adSize = adSize
    }

    private static func keyRootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
