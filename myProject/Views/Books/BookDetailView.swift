import SwiftUI

/// Страница книги: обложка, название, автор, сколько прочитано, «Читать» и «Слушать».
/// Открывается нажатием на книгу в библиотеке; читалка — следующим шагом
struct BookDetailView: View {
    @Bindable var book: Book

    @AppStorage(AppMode.storageKey) private var mode = AppMode.learning
    @State private var details: Details?
    @State private var isReading = false
    @State private var listensOnOpen = false
    @State private var isShowingDictionary = false

    /// Что нужно разобрать из текста книги: делается один раз, в фоне
    private struct Details {
        let chapters: Int
        let words: Int
        let wordsRead: Int
        let language: String
    }

    /// Средняя скорость чтения про себя, слов в минуту
    private static let wordsPerMinute = 220.0

    private var coverWidth: CGFloat { PadLayout.isPad ? 200 : 150 }

    private var isStarted: Bool { book.position > 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                top
                VStack(spacing: 20) {
                    titleBlock
                    chips
                    actions
                    aboutCard
                    if mode == .learning { dictionaryButton }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
                .frame(maxWidth: PadLayout.columnWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        // Читалка в дневной теме делает светлым весь стек; страница книги держит тему приложения сама
        .appThemedColorScheme()
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isReading) {
            BookReaderView(book: book, listensOnOpen: listensOnOpen)
                .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $isShowingDictionary) {
            BookDictionaryView(book: book)
                .appThemedColorScheme()
        }
        .task { await loadDetails() }
    }

    // MARK: - Обложка

    /// Обложка по центру на размытом фоне из неё же; по бокам — главы и прочитанное
    private var top: some View {
        ZStack {
            Group {
                if let data = book.coverData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 28)
                        .opacity(0.55)
                } else {
                    Color.brown.opacity(0.35)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: coverWidth * 1.5 * 0.62 + 40, alignment: .center)
            .clipped()
            .frame(maxHeight: .infinity, alignment: .top)
            .mask(
                LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom)
            )
            .ignoresSafeArea(edges: .top)

            HStack(alignment: .bottom, spacing: 0) {
                stat(title: "Глав", value: details.map { "\($0.chapters)" } ?? "—")
                Color.clear
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .frame(width: coverWidth)
                    .overlay { BookCover(data: book.coverData, title: book.title) }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
                stat(title: "Прочитано", value: "\(Int((book.progress * 100).rounded()))%")
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private func stat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .scaledFont(size: 12)
                .foregroundColor(.gray)
            Text(value)
                .scaledFont(size: 20, weight: .bold)
                .foregroundColor(.brandDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
    }

    // MARK: - Название и кнопки

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text(book.title)
                .scaledFont(size: 24, weight: .bold, design: .serif)
                .foregroundColor(.brandDark)
                .multilineTextAlignment(.center)
            if !book.author.isEmpty {
                Text(book.author)
                    .scaledFont(size: 16, weight: .medium)
                    .foregroundColor(.gray)
            }
            ProgressView(value: book.progress)
                .tint(.brown)
                .padding(.top, 8)
                .padding(.horizontal, 30)
        }
    }

    /// Язык и сколько читать осталось
    private var chips: some View {
        HStack(spacing: 10) {
            if let details {
                chip(Self.languageName(details.language))
                chip(remainingText(details))
            }
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .scaledFont(size: 14, weight: .medium)
            .foregroundColor(.brandDark)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.brandFill))
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                listensOnOpen = false
                isReading = true
            } label: {
                Text(isStarted ? "Продолжить" : "Читать")
                    .scaledFont(size: 17, weight: .semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.brandTint))
            }
            Button {
                listensOnOpen = true
                isReading = true
            } label: {
                Label("Слушать", systemImage: "headphones")
                    .scaledFont(size: 17, weight: .semibold)
                    .foregroundColor(.brandTint)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.brandTint, lineWidth: 1.5))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - О книге

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("О книге")
                .scaledFont(size: 17, weight: .semibold)
                .foregroundColor(.brandDark)
            if let details {
                row("Язык", Self.languageName(details.language))
                row("Глав", "\(details.chapters)")
                row("Слов", details.words.formatted(.number.locale(Locale(identifier: "ru_RU"))))
                row("Всего читать", duration(minutes: Double(details.words) / Self.wordsPerMinute))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.cardBackground))
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundColor(.gray)
            Spacer()
            Text(value).foregroundColor(.brandDark)
        }
        .scaledFont(size: 15)
    }

    private var dictionaryButton: some View {
        Button { isShowingDictionary = true } label: {
            Label("Слова из книги", systemImage: "text.book.closed")
                .scaledFont(size: 16, weight: .semibold)
                .foregroundColor(.brandTint)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.cardBackground))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Данные

    private func loadDetails() async {
        guard details == nil else { return }
        let data = book.chaptersData, position = book.position
        details = await Task.detached(priority: .userInitiated) {
            let chapters = (try? JSONDecoder().decode([BookChapter].self, from: data)) ?? []
            var words = 0, wordsRead = 0, index = 0
            for chapter in chapters {
                for paragraph in chapter.paragraphs {
                    let count = paragraph.split(whereSeparator: \.isWhitespace).count
                    words += count
                    if index < position { wordsRead += count }
                    index += 1
                }
            }
            return Details(chapters: chapters.count, words: words, wordsRead: wordsRead, language: BookLanguage.detect(chapters))
        }.value
    }

    private func remainingText(_ details: Details) -> String {
        let left = Double(max(details.words - details.wordsRead, 0)) / Self.wordsPerMinute
        return left < 1 ? "Дочитана" : "Осталось ≈ \(duration(minutes: left))"
    }

    private func duration(minutes: Double) -> String {
        let total = Int(minutes.rounded())
        let hours = total / 60, rest = total % 60
        if hours == 0 { return "\(max(rest, 1)) мин" }
        return rest == 0 ? "\(hours) ч" : "\(hours) ч \(rest) мин"
    }

    private static func languageName(_ code: String) -> String {
        Locale(identifier: "ru_RU").localizedString(forLanguageCode: code)?.capitalized ?? code
    }
}
