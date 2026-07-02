import UIKit
import GoogleMobileAds
import UserMessagingPlatform
import AppTrackingTransparency

/// Bootstraps ads with consent. Call once, early in app launch.
///
/// Flow: request UMP consent info → present the consent form if the user's region
/// requires it (GDPR etc.) → request App Tracking Transparency → start the Ads SDK.
/// Every step is best-effort: a failure at any stage still falls through to
/// starting the SDK, which then serves non-personalized ads.
public enum MobileAdsInitializer {
    public static func start() {
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false

        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { _ in
            DispatchQueue.main.async {
                ConsentForm.loadAndPresentIfRequired(from: rootViewController()) { _ in
                    requestTrackingThenStart()
                }
            }
        }
    }

    /// ATT must be requested while the app is active; by the time the async
    /// consent flow completes the app is foregrounded, so this is safe here.
    private static func requestTrackingThenStart() {
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async { startAds() }
        }
    }

    private static func startAds() {
        MobileAds.shared.start(completionHandler: nil)
    }

    private static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
