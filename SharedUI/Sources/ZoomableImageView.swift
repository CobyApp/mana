import SwiftUI
import UIKit

// MARK: - ZoomableScrollView

/// UIScrollView subclass that keeps `contentView` sized to the aspect-fit rect
/// of the image and centred in the scrollview's bounds on every layout pass.
public final class ZoomableScrollView: UIScrollView {
    public let contentView = UIView()
    public var imageSize: CGSize = .zero

    override public func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size.width > 0, bounds.size.height > 0,
              imageSize.width > 0, imageSize.height > 0 else { return }

        let fitSize = aspectFitSize(imageSize, in: bounds.size)
        // Only update if size has meaningfully changed to avoid layout cycles.
        if abs(contentView.bounds.width - fitSize.width) > 0.5 ||
            abs(contentView.bounds.height - fitSize.height) > 0.5 {
            contentView.frame = CGRect(origin: .zero, size: fitSize)
            contentSize = fitSize
        }

        // Re-centre the content view when it's smaller than the scroll view.
        let offsetX = max((bounds.width - contentSize.width) / 2, 0)
        let offsetY = max((bounds.height - contentSize.height) / 2, 0)
        contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }
}

// MARK: - Helpers

private func aspectFitSize(_ imageSize: CGSize, in containerSize: CGSize) -> CGSize {
    guard imageSize.width > 0, imageSize.height > 0 else { return containerSize }
    let scale = min(containerSize.width / imageSize.width,
                    containerSize.height / imageSize.height)
    return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
}

// MARK: - ZoomableImageView

public struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    let maxZoom: CGFloat
    let onLeftTap: (() -> Void)?
    let onCenterTap: (() -> Void)?
    let onRightTap: (() -> Void)?
    let leftZoneRatio: CGFloat
    let rightZoneRatio: CGFloat
    let overlayContent: AnyView?

    public init(
        image: UIImage,
        maxZoom: CGFloat = 4.0,
        onLeftTap: (() -> Void)? = nil,
        onCenterTap: (() -> Void)? = nil,
        onRightTap: (() -> Void)? = nil,
        leftZoneRatio: CGFloat = 0.25,
        rightZoneRatio: CGFloat = 0.25,
        overlayContent: AnyView? = nil
    ) {
        self.image = image
        self.maxZoom = maxZoom
        self.onLeftTap = onLeftTap
        self.onCenterTap = onCenterTap
        self.onRightTap = onRightTap
        self.leftZoneRatio = leftZoneRatio
        self.rightZoneRatio = rightZoneRatio
        self.overlayContent = overlayContent
    }

    public func makeUIView(context: Context) -> ZoomableScrollView {
        let scrollView = ZoomableScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = maxZoom
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = context.coordinator

        // Store image size so layoutSubviews can compute the aspect-fit rect.
        scrollView.imageSize = image.size

        // contentView is the zoom target; it fills the aspect-fit rect exactly.
        let contentView = scrollView.contentView
        contentView.clipsToBounds = true
        scrollView.addSubview(contentView)

        // imageView fills contentView with .scaleToFill — contentView already has
        // the correct aspect ratio so the image won't be distorted.
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleToFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tag = 1
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        // Host the SwiftUI overlay as a sibling of imageView inside contentView.
        if let overlayContent {
            let hosting = UIHostingController(rootView: overlayContent)
            hosting.view.backgroundColor = .clear
            hosting.view.isUserInteractionEnabled = false
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            hosting.view.tag = 2
            // Keep a strong reference to the hosting controller via the coordinator
            // so it is not deallocated while the scroll view is alive.
            context.coordinator.hostingController = hosting
            contentView.addSubview(hosting.view)
            NSLayoutConstraint.activate([
                hosting.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hosting.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ])
        }

        let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        scrollView.addGestureRecognizer(singleTap)

        context.coordinator.parent = self
        return scrollView
    }

    public func updateUIView(_ scrollView: ZoomableScrollView, context: Context) {
        context.coordinator.parent = self
        scrollView.imageSize = image.size

        if let imageView = scrollView.contentView.viewWithTag(1) as? UIImageView {
            imageView.image = image
        }

        // Update the SwiftUI overlay content if it exists.
        if let overlayContent,
           let hosting = context.coordinator.hostingController {
            hosting.rootView = overlayContent
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableImageView?
        // Retained here so the UIHostingController is not released while the
        // scroll view is alive (contentView holds only a weak subview reference).
        var hostingController: UIHostingController<AnyView>?

        public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            // Zoom the entire contentView so the overlay scales with the image.
            (scrollView as? ZoomableScrollView)?.contentView
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
