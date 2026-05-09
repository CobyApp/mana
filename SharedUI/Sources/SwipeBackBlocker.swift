import SwiftUI
import UIKit

/// Inserts a placeholder UIViewController whose only job is to disable the parent
/// navigation controller's interactivePopGestureRecognizer for the lifetime of this
/// view's appearance. Restored on disappear.
public struct SwipeBackBlocker: UIViewControllerRepresentable {
    public init() {}

    public func makeUIViewController(context: Context) -> Holder { Holder() }
    public func updateUIViewController(_: Holder, context: Context) {}

    public final class Holder: UIViewController {
        private var previousState: Bool?

        public override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            if let recognizer = navigationController?.interactivePopGestureRecognizer {
                previousState = recognizer.isEnabled
                recognizer.isEnabled = false
            }
        }

        public override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if let recognizer = navigationController?.interactivePopGestureRecognizer {
                recognizer.isEnabled = previousState ?? true
            }
        }
    }
}
