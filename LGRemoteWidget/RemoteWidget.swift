import AppIntents
import SwiftUI
import WidgetKit

@main
struct LGRemoteWidgetBundle: WidgetBundle {
    var body: some Widget {
        RemoteWidget()
    }
}

struct RemoteEntry: TimelineEntry {
    let date: Date
    let tvName: String?
}

struct RemoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> RemoteEntry {
        RemoteEntry(date: .now, tvName: "LG TV")
    }

    func getSnapshot(in context: Context, completion: @escaping (RemoteEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RemoteEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> RemoteEntry {
        RemoteEntry(date: .now, tvName: TVStore.load()?.name)
    }
}

struct RemoteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RemoteWidget", provider: RemoteProvider()) { entry in
            RemoteWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(red: 0.65, green: 0, blue: 0.2), Color(red: 0.25, green: 0, blue: 0.08)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
        }
        .configurationDisplayName("TV 리모컨")
        .description("TV 전원과 음량을 홈 화면에서 바로 조절합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct RemoteWidgetView: View {
    let entry: RemoteEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.tvName ?? "앱에서 TV를 연결하세요")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
            if family == .systemMedium {
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        key(.power, "power", tint: .red)
                        key(.volumeUp, "speaker.plus")
                        key(.home, "house")
                    }
                    GridRow {
                        key(.mute, "speaker.slash")
                        key(.volumeDown, "speaker.minus")
                        key(.back, "arrow.uturn.backward")
                    }
                }
            } else {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        key(.power, "power", tint: .red)
                        key(.volumeUp, "speaker.plus")
                    }
                    GridRow {
                        key(.mute, "speaker.slash")
                        key(.volumeDown, "speaker.minus")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func key(_ command: TVCommand, _ systemImage: String, tint: Color = .white) -> some View {
        Button(intent: TVCommandIntent(command)) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(TVCommand.caseDisplayRepresentations[command]?.title ?? "TV"))
    }
}
