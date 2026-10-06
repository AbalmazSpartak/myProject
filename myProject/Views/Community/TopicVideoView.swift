import SwiftUI
import WebKit

/// Ссылка на ролик YouTube: номер видео и с какой секунды начать
struct YouTubeLink: Equatable {
    let id: String
    let start: Int

    /// youtu.be/ID, youtube.com/watch?v=ID, /shorts/ID, /embed/ID, /live/ID; время — t= или start= (90, 90s, 1m30s)
    init?(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: text.contains("://") ? text : "https://" + text),
              let host = components.host?.lowercased() else { return nil }
        let path = components.path.split(separator: "/").map(String.init)
        let query = components.queryItems ?? []

        var id: String?
        if host.hasSuffix("youtu.be") {
            id = path.first
        } else if host.hasSuffix("youtube.com") || host.hasSuffix("youtube-nocookie.com") {
            if path.first == "watch" {
                id = query.first { $0.name == "v" }?.value
            } else if path.count >= 2, ["shorts", "embed", "live", "v"].contains(path[0]) {
                id = path[1]
            }
        }
        guard let id, id.count == 11,
              id.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else { return nil }
        self.id = id
        let time = query.first { $0.name == "t" || $0.name == "start" }?.value ?? ""
        start = Self.seconds(time)
    }

    private static func seconds(_ text: String) -> Int {
        if let plain = Int(text) { return plain }
        var total = 0, number = 0
        for character in text {
            if let digit = character.wholeNumberValue {
                number = number * 10 + digit
            } else {
                total += number * (character == "h" ? 3600 : character == "m" ? 60 : 1)
                number = 0
            }
        }
        return total + number
    }

    var watchURL: URL {
        URL(string: "https://www.youtube.com/watch?v=\(id)" + (start > 0 ? "&t=\(start)s" : ""))!
    }
}

/// Блок «Видео» в теме: YouTube — плеер прямо в теме, другие ссылки — кнопкой в браузер
struct TopicVideoView: View {
    let block: TopicBlock
    @Environment(\.openURL) private var openURL

    private var raw: String { (block.videoURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let link = YouTubeLink(raw) {
                YouTubePlayer(link: link)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                HStack(alignment: .firstTextBaseline) {
                    if !block.text.isEmpty {
                        Text(block.text)
                            .scaledFont(size: 15, weight: .semibold)
                            .foregroundColor(.brandDark)
                    }
                    Spacer()
                    // Автор ролика мог запретить показ на других сайтах — тогда смотрим в YouTube
                    Button { openURL(link.watchURL) } label: {
                        Label("Открыть в YouTube", systemImage: "arrow.up.right.square")
                            .scaledFont(size: 14, weight: .semibold)
                    }
                    .foregroundColor(.brandTint)
                }
            } else if let url = URL(string: raw), url.scheme?.hasPrefix("http") == true {
                Button { openURL(url) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "play.rectangle.fill")
                            .scaledFont(size: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(block.text.isEmpty ? "Открыть видео" : block.text)
                                .scaledFont(size: 16, weight: .semibold)
                            Text(url.host ?? raw)
                                .scaledFont(size: 13)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .foregroundColor(.brandDark)
                    .padding(16)
                    .background(Color.cardBackground)
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Встроенный плеер YouTube. Страница с плеером грузится с адресом приложения как источником:
/// без него YouTube отказывается показывать ролик в чужом окне (ошибка 152/153)
private struct YouTubePlayer: UIViewRepresentable {
    let link: YouTubeLink

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        load(into: webView)
        context.coordinator.loaded = link
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loaded != link else { return }
        context.coordinator.loaded = link
        load(into: webView)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loaded: YouTubeLink?
    }

    private func load(into webView: WKWebView) {
        let source = "https://www.youtube-nocookie.com/embed/\(link.id)?playsinline=1&rel=0" + (link.start > 0 ? "&start=\(link.start)" : "")
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0;height:100%;background:#000}iframe{position:absolute;inset:0;width:100%;height:100%;border:0}</style>
        </head><body><iframe src="\(source)" referrerpolicy="strict-origin-when-cross-origin"
        allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen></iframe></body></html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://\(Bundle.main.bundleIdentifier ?? "app").local"))
    }
}

/// Редактор блока «Видео»: ссылка и подпись
struct TopicVideoEditor: View {
    @Binding var block: TopicBlock

    private var url: Binding<String> {
        Binding(get: { block.videoURL ?? "" }, set: { block.videoURL = $0 })
    }

    var body: some View {
        TextField("Ссылка на YouTube или другое видео", text: url)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        TextField("Подпись (необязательно)", text: $block.text)
        let raw = (block.videoURL ?? "").trimmingCharacters(in: .whitespaces)
        if !raw.isEmpty {
            Label(YouTubeLink(raw) != nil ? "YouTube — плеер прямо в теме" : "Не YouTube — откроется в браузере",
                  systemImage: YouTubeLink(raw) != nil ? "checkmark.circle" : "safari")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
