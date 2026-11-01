import Foundation
import CoreGraphics
import Domain

/// Groups per-line OCR boxes that belong to the same speech bubble into one unit, so a bubble split
/// into several columns/lines becomes a single plate with its text in manga reading order (instead
/// of overlapping plates with mixed vertical/horizontal fragments). Ported from the Android
/// `clusterBubbles`/`assembleReadingOrder` logic.
///
/// Input boxes are Vision-normalized (0...1, bottom-left origin). Boxes are clustered when their
/// rects, expanded by ~one glyph, intersect (iterated until stable). Each cluster's members are
/// ordered for reading: if they spread out more horizontally they're columns → right-to-left;
/// otherwise rows → top-to-bottom. In Vision's bottom-left space, "top" is the larger Y.
public enum BubbleClusterer {
    public static func cluster(_ boxes: [TextLineBox]) -> [TextLineBox] {
        guard boxes.count > 1 else { return boxes }

        var clusters: [[TextLineBox]] = boxes.map { [$0] }

        func unionRect(_ members: [TextLineBox]) -> CGRect {
            let l = members.map { $0.boundingBox.minX }.min() ?? 0
            let b = members.map { $0.boundingBox.minY }.min() ?? 0
            let r = members.map { $0.boundingBox.maxX }.max() ?? 0
            let t = members.map { $0.boundingBox.maxY }.max() ?? 0
            return CGRect(x: l, y: b, width: r - l, height: t - b)
        }

        // Glyph size proxy: the smaller side of a line box (a column's width, a row's height).
        func glyph(_ box: TextLineBox) -> CGFloat { min(box.boundingBox.width, box.boundingBox.height) }

        var changed = true
        while changed {
            changed = false
            outer: for i in clusters.indices {
                for j in (i + 1)..<clusters.count {
                    let a = unionRect(clusters[i])
                    let b = unionRect(clusters[j])
                    let margin = max(
                        clusters[i].map(glyph).max() ?? 0,
                        clusters[j].map(glyph).max() ?? 0
                    ) * 1.2
                    let intersects =
                        a.minX - margin <= b.maxX && b.minX - margin <= a.maxX &&
                        a.minY - margin <= b.maxY && b.minY - margin <= a.maxY
                    if intersects {
                        clusters[i].append(contentsOf: clusters[j])
                        clusters.remove(at: j)
                        changed = true
                        break outer
                    }
                }
            }
        }

        return clusters.map { members in
            if members.count == 1 { return members[0] }
            let xs = members.map { $0.boundingBox.midX }
            let ys = members.map { $0.boundingBox.midY }
            let xSpread = (xs.max() ?? 0) - (xs.min() ?? 0)
            let ySpread = (ys.max() ?? 0) - (ys.min() ?? 0)
            let columns = xSpread > ySpread
            let ordered: [TextLineBox]
            if columns {
                // right → left columns
                ordered = members.sorted {
                    $0.boundingBox.midX != $1.boundingBox.midX
                        ? $0.boundingBox.midX > $1.boundingBox.midX
                        : $0.boundingBox.midY > $1.boundingBox.midY
                }
            } else {
                // top → bottom rows (larger Y first in bottom-left space)
                ordered = members.sorted {
                    $0.boundingBox.midY != $1.boundingBox.midY
                        ? $0.boundingBox.midY > $1.boundingBox.midY
                        : $0.boundingBox.midX < $1.boundingBox.midX
                }
            }
            let union = unionRect(members)
            let text = ordered.map { $0.text.replacingOccurrences(of: "\n", with: "") }.joined()
            return TextLineBox(
                id: UUID(),
                text: text,
                boundingBox: union,
                confidence: members.map { $0.confidence }.min() ?? 0,
                isVertical: columns
            )
        }
    }
}
