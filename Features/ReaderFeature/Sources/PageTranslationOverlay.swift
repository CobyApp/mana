// Features/ReaderFeature/Sources/PageTranslationOverlay.swift
import SwiftUI
import Domain
import DesignSystem

struct PageTranslationOverlay: View {
    let page: TranslatedPage?
    let isHidden: Bool

    var body: some View {
        if !isHidden, let page, !page.lines.isEmpty {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    ForEach(page.lines, id: \.original.id) { line in
                        let bb = line.original.boundingBox
                        let w = max(8, proxy.size.width * bb.width)
                        let h = max(8, proxy.size.height * bb.height)
                        let cx = proxy.size.width * bb.midX
                        let cy = proxy.size.height * (1 - bb.midY)  // Vision Y → SwiftUI Y

                        Group {
                            if line.original.isVertical {
                                VStack(spacing: 0) {
                                    ForEach(Array(line.translated.enumerated()), id: \.offset) { _, ch in
                                        Text(String(ch))
                                            .font(Tokens.Typography.subtitle)
                                            .foregroundStyle(Tokens.Colors.ink)
                                            .lineLimit(1)
                                    }
                                }
                                .minimumScaleFactor(0.4)
                            } else {
                                Text(line.translated)
                                    .font(Tokens.Typography.subtitle)
                                    .foregroundStyle(Tokens.Colors.ink)
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.4)
                                    .lineLimit(nil)
                            }
                        }
                        .padding(2)
                        .frame(width: w, height: h)
                        .background(Color(argb: line.backgroundColorARGB))
                        .position(x: cx, y: cy)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}
