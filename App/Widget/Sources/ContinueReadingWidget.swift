import WidgetKit
import SwiftUI
import UIKit

/// Snapshot of the most recently read comic, written by the app into the shared App Group
/// container (see `ContinueReadingWidgetBridge` in the app target — keep the two in sync).
struct ContinueReadingSnapshot: Codable {
    let comicId: String
    let title: String
    let page: Int
    let total: Int
    let updatedAt: Date
}

enum WidgetShared {
    static let appGroup = "group.com.coby.mana"
    static let snapshotFile = "continue-reading.json"
    static let coverFile = "continue-reading-cover.dat"

    static var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    static func load() -> (ContinueReadingSnapshot?, UIImage?) {
        guard let dir = container,
              let data = try? Data(contentsOf: dir.appending(path: snapshotFile)),
              let snap = try? JSONDecoder().decode(ContinueReadingSnapshot.self, from: data) else { return (nil, nil) }
        let cover = (try? Data(contentsOf: dir.appending(path: coverFile))).flatMap(UIImage.init(data:))
        return (snap, cover)
    }
}

struct ContinueReadingEntry: TimelineEntry {
    let date: Date
    let snapshot: ContinueReadingSnapshot?
    let cover: UIImage?
}

struct ContinueReadingProvider: TimelineProvider {
    func placeholder(in context: Context) -> ContinueReadingEntry {
        ContinueReadingEntry(date: .now, snapshot: nil, cover: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ContinueReadingEntry) -> Void) {
        let (snap, cover) = WidgetShared.load()
        completion(ContinueReadingEntry(date: .now, snapshot: snap, cover: cover))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ContinueReadingEntry>) -> Void) {
        // The app reloads timelines whenever progress changes, so no periodic refresh is needed.
        let (snap, cover) = WidgetShared.load()
        completion(Timeline(entries: [ContinueReadingEntry(date: .now, snapshot: snap, cover: cover)], policy: .never))
    }
}

private enum Palette {
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.91)
    static let ink = Color(red: 0.08, green: 0.08, blue: 0.09)
    static let accent = Color(red: 0.93, green: 0.18, blue: 0.24)
}

struct ContinueReadingWidgetView: View {
    let entry: ContinueReadingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let snap = entry.snapshot {
                content(snap)
                    .widgetURL(URL(string: "noiz://comic/\(snap.comicId)"))
            } else {
                empty.widgetURL(URL(string: "noiz://library"))
            }
        }
        .containerBackground(for: .widget) { Palette.paper }
    }

    @ViewBuilder
    private func content(_ snap: ContinueReadingSnapshot) -> some View {
        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 6) {
                cover.frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(snap.title).font(.system(size: 12, weight: .heavy, design: .rounded)).lineLimit(1)
                pageLabel(snap)
            }
            .foregroundStyle(Palette.ink)
        } else {
            HStack(spacing: 12) {
                cover.frame(width: 78)
                VStack(alignment: .leading, spacing: 6) {
                    Text("widget.continue")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Palette.accent)
                        .textCase(.uppercase)
                    Text(snap.title)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    pageLabel(snap)
                    progressBar(snap)
                }
                .foregroundStyle(Palette.ink)
            }
        }
    }

    private var cover: some View {
        Group {
            if let img = entry.cover {
                Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Palette.paper
                    Image(systemName: "book.closed.fill").font(.system(size: 28, weight: .black)).foregroundStyle(Palette.ink)
                }
            }
        }
        .clipped()
        .overlay(Rectangle().strokeBorder(Palette.ink, lineWidth: 2))
    }

    private func pageLabel(_ snap: ContinueReadingSnapshot) -> some View {
        Text(verbatim: "\(snap.page + 1) / \(snap.total)")
            .font(.system(size: 12, weight: .heavy, design: .monospaced))
            .foregroundStyle(Palette.accent)
    }

    private func progressBar(_ snap: ContinueReadingSnapshot) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Palette.ink.opacity(0.15))
                Rectangle().fill(Palette.accent)
                    .frame(width: geo.size.width * CGFloat(snap.page + 1) / CGFloat(max(1, snap.total)))
            }
        }
        .frame(height: 6)
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Text(verbatim: "NOIZ")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(Palette.accent)
            Text("widget.empty")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
}

struct ContinueReadingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ContinueReading", provider: ContinueReadingProvider()) { entry in
            ContinueReadingWidgetView(entry: entry)
        }
        .configurationDisplayName(Text("widget.name"))
        .description(Text("widget.description"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ManaWidgetBundle: WidgetBundle {
    var body: some Widget {
        ContinueReadingWidget()
    }
}
