import SwiftUI
import UIKit
import Domain

/// Continuous vertical-scroll (webtoon) renderer: pages stack top-to-bottom and scroll as one
/// strip. The most-centered page drives `current`; an external `current` change (progress bar
/// drag, resume, next-chapter) scrolls that page into view. A center tap toggles the controls.
public struct WebtoonRenderer: View {
    let totalPages: Int
    @Binding var current: Int
    let pageImage: (Int) async -> UIImage?
    let onPrefetchHint: (Int) -> Void
    let onCenterTap: () -> Void
    let pageOverlay: ((Int) -> AnyView)?
    /// Optional full-height item after the last page (e.g. the "next chapter" card). It has no
    /// page index, so scrolling onto it never moves `current` past the last real page.
    let endPage: AnyView?

    /// The index last reported from scrolling, used to tell internal scroll updates apart from
    /// external `current` changes so we don't fight the user's scroll with programmatic jumps.
    @State private var reportedIndex: Int = 0

    public init(
        totalPages: Int,
        current: Binding<Int>,
        pageImage: @escaping (Int) async -> UIImage?,
        onPrefetchHint: @escaping (Int) -> Void,
        onCenterTap: @escaping () -> Void = {},
        pageOverlay: ((Int) -> AnyView)? = nil,
        endPage: AnyView? = nil
    ) {
        self.totalPages = totalPages
        self._current = current
        self.pageImage = pageImage
        self.onPrefetchHint = onPrefetchHint
        self.onCenterTap = onCenterTap
        self.pageOverlay = pageOverlay
        self.endPage = endPage
    }

    public var body: some View {
        GeometryReader { outer in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(0..<totalPages, id: \.self) { idx in
                            WebtoonPage(
                                index: idx,
                                provider: pageImage,
                                onPrefetchHint: onPrefetchHint,
                                onCenterTap: onCenterTap,
                                overlay: pageOverlay
                            )
                            .id(idx)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: WebtoonFramesKey.self,
                                        value: [idx: geo.frame(in: .named("webtoon"))]
                                    )
                                }
                            )
                        }
                        if let endPage {
                            endPage
                                .frame(width: outer.size.width, height: outer.size.height)
                                .id("webtoon.end")
                        }
                    }
                }
                .coordinateSpace(name: "webtoon")
                .onPreferenceChange(WebtoonFramesKey.self) { frames in
                    let center = outer.size.height / 2
                    // The visible page is the one whose frame straddles the viewport centerline.
                    if let hit = frames.first(where: { $0.value.minY <= center && $0.value.maxY >= center })?.key,
                       hit != reportedIndex {
                        reportedIndex = hit
                        if hit != current { current = hit }
                    }
                }
                .onChange(of: current) { _, newValue in
                    // Only react to external jumps (progress bar, resume); our own scroll-driven
                    // updates already match `reportedIndex`.
                    if newValue != reportedIndex {
                        reportedIndex = newValue
                        withAnimation(.none) { proxy.scrollTo(newValue, anchor: .top) }
                    }
                }
                .onAppear {
                    reportedIndex = current
                    if current > 0 { proxy.scrollTo(current, anchor: .top) }
                }
            }
        }
    }
}

/// One page in the webtoon strip: loads its image lazily, sizes to the container width at the
/// image's aspect ratio, and applies an optional per-page overlay.
private struct WebtoonPage: View {
    let index: Int
    let provider: (Int) async -> UIImage?
    let onPrefetchHint: (Int) -> Void
    let onCenterTap: () -> Void
    let overlay: ((Int) -> AnyView)?

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let aspect = image.map { $0.size.height / max(1, $0.size.width) } ?? (4.0 / 3.0)
            let height = width * aspect
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: width, height: height)
                        .overlay { overlay.map { $0(index) } }
                } else {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: width, height: height)
                        .overlay { ProgressView().tint(.gray) }
                }
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .onTapGesture { onCenterTap() }
        }
        // Reserve height so the lazy stack lays out before the image resolves.
        .aspectRatio(image.map { $0.size.width / max(1, $0.size.height) } ?? 0.75, contentMode: .fit)
        .task(id: index) { await load() }
    }

    private func load() async {
        onPrefetchHint(index)
        for _ in 0..<60 {
            if let img = await provider(index) {
                image = img
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}

private struct WebtoonFramesKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
