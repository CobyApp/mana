import SwiftUI
import UIKit

public struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    let maxZoom: CGFloat
    let onLeftTap: (() -> Void)?
    let onCenterTap: (() -> Void)?
    let onRightTap: (() -> Void)?
    let leftZoneRatio: CGFloat
    let rightZoneRatio: CGFloat

    public init(
        image: UIImage,
        maxZoom: CGFloat = 4.0,
        onLeftTap: (() -> Void)? = nil,
        onCenterTap: (() -> Void)? = nil,
        onRightTap: (() -> Void)? = nil,
        leftZoneRatio: CGFloat = 0.25,
        rightZoneRatio: CGFloat = 0.25
    ) {
        self.image = image
        self.maxZoom = maxZoom
        self.onLeftTap = onLeftTap
        self.onCenterTap = onCenterTap
        self.onRightTap = onRightTap
        self.leftZoneRatio = leftZoneRatio
        self.rightZoneRatio = rightZoneRatio
    }

    public func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = maxZoom
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = context.coordinator

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tag = 1
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        scrollView.addGestureRecognizer(singleTap)

        context.coordinator.parent = self
        return scrollView
    }

    public func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.parent = self
        if let imageView = scrollView.viewWithTag(1) as? UIImageView {
            imageView.image = image
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableImageView?

        public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            scrollView.viewWithTag(1)
        }

        @objc func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView = recognizer.view as? UIScrollView,
                  let parent else { return }
            let width = scrollView.bounds.width
            guard width > 0 else { return }
            let zoomed = scrollView.zoomScale > scrollView.minimumZoomScale + 0.001
            let x = recognizer.location(in: scrollView).x
            let leftMax = width * parent.leftZoneRatio
            let rightMin = width * (1 - parent.rightZoneRatio)
            // While zoomed in, treat every tap as a center tap so navigation
            // doesn't fight panning.
            if zoomed {
                parent.onCenterTap?()
            } else if x < leftMax {
                parent.onLeftTap?()
            } else if x > rightMin {
                parent.onRightTap?()
            } else {
                parent.onCenterTap?()
            }
        }
    }
}
