import SwiftUI

struct AppsView: View {
    @Environment(RemoteViewModel.self) private var model
    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !model.inputs.isEmpty {
                        Text("입력 전환").font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(model.inputs) { input in
                                    Button { model.switchInput(input) } label: {
                                        Label(input.label, systemImage: input.connected ? "cable.connector" : "cable.connector.slash")
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    Text("앱").font(.headline)
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(model.apps) { app in
                            Button { model.launch(app) } label: { AppTile(app: app) }
                                .buttonStyle(.plain)
                        }
                    }
                    if model.apps.isEmpty {
                        Text(model.isConnected ? "앱 목록을 불러오는 중…" : "TV에 연결되면 앱 목록이 표시됩니다.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("앱·입력")
            .toolbar {
                Button { Task { await model.loadAppsAndInputs() } } label: { Image(systemName: "arrow.clockwise") }
            }
            .refreshable { await model.loadAppsAndInputs() }
            .task(id: model.isConnected) {
                if model.isConnected && model.apps.isEmpty { await model.loadAppsAndInputs() }
            }
        }
    }
}

private struct AppTile: View {
    let app: TVApp

    var body: some View {
        VStack(spacing: 6) {
            TVIconImage(url: app.iconURL)
                .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            Text(app.title).font(.caption).lineLimit(2).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TVIconImage: View {
    let url: URL?
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                image.resizable().scaledToFit()
            } else {
                Image(systemName: "app.dashed").font(.largeTitle).foregroundStyle(.secondary)
            }
        }
        .task(id: url) { image = await Self.load(url) }
    }

    private static func load(_ url: URL?) async -> Image? {
        guard let url, let (data, _) = try? await LocalTVSession.shared.data(from: url) else { return nil }
        #if canImport(UIKit)
        return UIImage(data: data).map(Image.init(uiImage:))
        #else
        return NSImage(data: data).map(Image.init(nsImage:))
        #endif
    }
}
