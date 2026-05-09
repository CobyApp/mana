import SwiftUI

public extension Tokens {
    enum Colors {
        public static var backgroundPrimary: Color { Color("BackgroundPrimary", bundle: .module) }
        public static var backgroundSecondary: Color { Color("BackgroundSecondary", bundle: .module) }
        public static var accent: Color { Color("Accent", bundle: .module) }
        public static var onGlassPrimary: Color { Color("OnGlassPrimary", bundle: .module) }
        public static var onGlassSecondary: Color { Color("OnGlassSecondary", bundle: .module) }
    }
}
