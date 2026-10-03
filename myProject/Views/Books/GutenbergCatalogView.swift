import SwiftUI
import SwiftData

/// Каталог Project Gutenberg: самые популярные книги или поиск; книга скачивается в библиотеку одной кнопкой
struct GutenbergCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [Book]

    @State private var query = ""
    @State private var entries: [GutenbergCatalog.Entry] = []
    @State private var isLoading = false
    @State private var downloading: Set<Int> = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if isLoading && entries.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                ForEach(entries) { entry in
                    row(entry)
                }
                if !isLoading && entries.isEmpty {
                    Text(query.isEmpty ? "Каталог недоступен — проверьте интернет." : "Ничего не нашлось. Попробуйте название или автора на английском.")
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            }
            .brandListBackground()
            .navigationTitle(query.isEmpty ? "Популярные книги" : "Поиск")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Название или автор (англ.)")
            .onSubmit(of: .search) { Task { await load() } }
            .onChange(of: query) { _, newValue in
                if newValue.isEmpty { Task { await load() } }
            }
            .task { await load() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("Project Gutenberg — бесплатные книги, ставшие общественным достоянием.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
            .alert("Не получилось", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func row(_ entry: GutenbergCatalog.Entry) -> some View {
        let isInLibrary = books.contains { $0.gutenbergID == entry.id }
        return HStack(spacing: 12) {
            AsyncImage(url: entry.coverURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.brown.opacity(0.25)
            }
            .frame(width: 46, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .lineLimit(2)
                Text(entry.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if isInLibrary {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .accessibilityLabel("В библиотеке")
            } else if downloading.contains(entry.id) {
                ProgressView()
            } else {
                Button { Task { await download(entry) } } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundColor(.brown)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Скачать")
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        entries = (try? await GutenbergCatalog.search(query)) ?? []
    }

    private func download(_ entry: GutenbergCatalog.Entry) async {
        downloading.insert(entry.id)
        defer { downloading.remove(entry.id) }
        do {
            let parsed = try await GutenbergCatalog.downloadBook(entry)
            modelContext.insert(Book(parsed, gutenbergID: entry.id))
            try? modelContext.save()
        } catch {
            errorMessage = "Не удалось скачать «\(entry.title)». Проверьте интернет и попробуйте ещё раз."
        }
    }
}
