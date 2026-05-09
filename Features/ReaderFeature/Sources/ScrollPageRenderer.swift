import SwiftUI
import UIKit
import Domain
import SharedUI

public struct ScrollPageRenderer: View, PageRenderer {
    let totalPages: Int
    @Binding var current: Int
    let pageImage: (Int) async -> UIImage?
    let onPrefetchHint: (Int) -> Void
    let direction: ScrollDirection

    @State private var images: [Int: UIImage] = [:]

    public init(
        totalPages: Int,
        current: Binding<Int>,
        pageImage: @escaping (Int) async -> UIImage?,
        onPrefetchHint: @escaping (Int) -> Void,
        progressionDirection: PageProgressionDirection = .leftToRight,
        tapZonesEnabled: Bool = true,
        swipeEnabled: Bool = true
    ) {
        self.totalPages = totalPages
        self._current = current
        self.pageImage = pageImage
        self.onPrefetchHint = onPrefetchHint
        // Scroll renderer ignores tap zones / swipe; keep its existing TTB default.
        self.direction = .ttb
        _ = progressionDirection
        _ = tapZonesEnabled
        _ = swipeEnabled
    }

    public init(
        totalPages: Int,
        current: Binding<Int>,
        pageImage: @escaping (Int) async -> UIImage?,
        onPrefetchHint: @escaping (Int) -> Void,
        direction: ScrollDirection
    ) {
        self.totalPages = totalPages
        self._current = current
        self.pageImage = pageImage
        self.onPrefetchHint = onPrefetchHint
        self.direction = direction
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(scrollAxis) { content(proxy: proxy) }
                .environment(\.layoutDirection, layoutDirection)
        }
    }

    private var scrollAxis: Axis.Set {
        switch direction {
        case .ttb: return .vertical
        case .ltr, .rtl: return .horizontal
        }
    }

    private var layoutDirection: LayoutDirection {
        direction == .rtl ? .rightToLeft : .leftToRight
    }

    @ViewBuilder
    private func content(proxy: ScrollViewProxy) -> some View {
        if direction == .ttb {
            LazyVStack(spacing: 0) { pages }.onAppear { proxy.scrollTo(current, anchor: .top) }
        } else {
            LazyHStack(spacing: 0) { pages }.onAppear { proxy.scrollTo(current, anchor: .leading) }
        }
    }

    @ViewBuilder
    private var pages: some View {
        ForEach(0..<totalPages, id: \.self) { index in
            page(at: index).id(index).onAppear { current = index; onPrefetchHint(index) }
        }
    }

    @ViewBuilder
    private func page(at index: Int) -> some View {
        if let img = images[index] {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fit)
        } else {
            Color.black
                .frame(minWidth: 320, minHeight: 480)
                .overlay(ProgressView().tint(.white))
                .task(id: index) {
                    if let img = await pageImage(index) { images[index] = img }
                }
        }
    }
}
