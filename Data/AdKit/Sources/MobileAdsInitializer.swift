import GoogleMobileAds

/// Starts the Google Mobile Ads SDK. Call once, early in app launch.
public enum MobileAdsInitializer {
    /// Initializes the SDK. Safe to call more than once; the SDK ignores
    /// repeat calls. Runs asynchronously and does not block launch.
    public static func start() {
        MobileAds.shared.start(completionHandler: nil)
    }
}
