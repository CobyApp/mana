import Foundation

/// Central place for AdMob identifiers.
///
/// The values below are Google's **official test** identifiers. They always
/// return test ads and are safe to use during development — never tap or
/// interact with live ads while a real unit ID is configured, as that can get
/// the AdMob account suspended.
///
/// Before shipping to the App Store:
///   1. Create the app and a banner ad unit in the AdMob console.
///   2. Replace `bannerUnitID` (release branch) with the real unit ID.
///   3. Replace `GADApplicationIdentifier` in `App/Resources/Info.plist` with
///      the matching real app ID.
public enum AdConfig {
    /// Google's public test app ID. Kept here for reference; the value that
    /// actually takes effect lives in `Info.plist` under `GADApplicationIdentifier`.
    public static let testApplicationID = "ca-app-pub-3940256099942544~1458002511"

    /// Banner ad unit ID.
    ///
    /// DEBUG uses Google's test unit (safe to interact with). RELEASE uses the
    /// real unit — never tap real ads yourself, it can get the account banned.
    public static var bannerUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2435281174" // Google test banner
        #else
        return "ca-app-pub-1120202923997022/7946599319" // real banner unit
        #endif
    }
}
