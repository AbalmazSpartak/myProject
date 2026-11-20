import SwiftUI
import SwiftData

/// «Папки» (дизайн «Словарь»): основные списки, свои папки и словари с переименованием и удалением,
/// уровни и темы встроенной базы. Выбор строки открывает этот раздел в Словаре
struct FoldersView: View {
    @Binding var filter: DictionaryFilter

    private enum Route: Hashable { case topics }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \WordList.createdAt, order: .reverse) private var lists: [WordList]
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()

    @State private var path: [Route]
    @State private var generalCount = 0
    @State private var mistakeCount = 0
    @State private var isAddingFolder = false
    @State private var newFolderName = ""
    @State private var listToRename: WordList?
    @State private var folderToRename: Category?
    @State private var renameText = ""
    @State private var listMerge: ListMerge?
    @State private var listToDelete: WordList?
    @State private var folderToDelete: Category?
    /// Идёт удаление словаря — в словаре из книги тысячи слов, это заметное время
    @State private var isDeletingList = false
    @State private var notice: String?

    /// Переименование своего словаря в название другого своего словаря
    private struct ListMerge {
        let source: WordList
        let target: WordList
    }

    init(filter: Binding<DictionaryFilter>, startsOnTopics: Bool = false) {
        _filter = filter
        _path = State(initialValue: startsOnTopics ? [.topics] : [])
    }

    private var builtInTopics: [Category] {
        let names = DataPreloader.bundledTopicNames
        return categories.filter { names.contains($0.name) }
    }

    private var userFolders: [Category] {
        let names = DataPreloader.bundledTopicNames
        return categories.filter { !names.contains($0.name) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Мои списки")
                        .scaledFont(size: 32, weight: .medium, design: .serif)
                        .foregroundStyle(Color.brandDark)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                    sectionLabel("Основные")
                    LXGroup {
                        mainRow("Общий", icon: "book.closed", count: generalCount, item: .general)
                        mainRow("Слова с ошибками", icon: "flag", count: mistakeCount, item: .mistakes)
                    }
                    .padding(.horizontal, 16)

                    sectionLabel("Папки и словари")
                    LXGroup {
                        ForEach(lists) { list in listRow(list) }
                        ForEach(userFolders) { folder in folderRow(folder) }
                        newFolderRow
                    }
                    .padding(.horizontal, 16)

                    sectionLabel("Уровни A1–C2 · встроенная база")
                    levelCards

                    LXGroup {
                        builtInRow("Oxford 5000", icon: "books.vertical", item: .oxford(level: nil))
                        builtInRow("Дополнения", icon: "books.vertical", item: .extra)
                        Button { path.append(.topics) } label: {
                            rowContent(icon: "square.grid.2x2", title: "Темы", subtitle: nil,
                                       trailing: "\(builtInTopics.count)", showsChevron: true)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
            .background(Color.brandBackground.ignoresSafeArea())
            .navigationTitle("Папки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.brandBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    LXTextButton(title: "Готово") { dismiss() }
                }
            }
            .navigationDestination(for: Route.self) { _ in
                TopicsView(categories: builtInTopics) { select(.category($0)) }
            }
        }
        .onAppear(perform: reloadCounts)
        .overlay {
            if isDeletingList {
                ProgressView("Удаляю словарь…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert("Новая папка", isPresented: $isAddingFolder) {
            TextField("Название папки", text: $newFolderName)
            Button("Отмена", role: .cancel) { newFolderName = "" }
            Button("Создать", action: createFolder)
        }
        .alert("Переименовать словарь", isPresented: isPresented($listToRename)) {
            TextField("Название", text: $renameText)
            Button("Отмена", role: .cancel) {}
            Button("Сохранить", action: renameList)
        }
        .alert("Переименовать папку", isPresented: isPresented($folderToRename)) {
            TextField("Название", text: $renameText)
            Button("Отмена", role: .cancel) {}
            Button("Сохранить", action: renameFolder)
        }
        .alert("Словарь «\(listMerge?.target.name ?? "")» уже есть", isPresented: isPresented($listMerge)) {
            Button("Отмена", role: .cancel) {}
            Button("Объединить") {
                if let pair = listMerge { merge(pair.source, into: pair.target) }
            }
        } message: {
            Text("Слова из «\(listMerge?.source.name ?? "")» перейдут в него, без повторов, а «\(listMerge?.source.name ?? "")» удалится.")
        }
        .alert("Удалить словарь «\(listToDelete?.name ?? "")»?", isPresented: isPresented($listToDelete)) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                if let list = listToDelete { delete(list) }
            }
        } message: {
            Text("Новые слова, добавленные только в этот словарь, тоже удалятся. Слова из основной базы останутся в своих темах.")
        }
        .alert("Удалить папку «\(folderToDelete?.name ?? "")»?", isPresented: isPresented($folderToDelete)) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                if let folder = folderToDelete { deleteFolder(folder) }
            }
        } message: {
            let count = folderToDelete.map { DictionaryCounts.category($0, in: modelContext) } ?? 0
            Text(count == 0 ? "Папка пуста." : "Слова папки (\(DictionaryCounts.words(count))) тоже удалятся вместе с прогрессом.")
        }
        .alert(notice ?? "", isPresented: noticeBinding) {
            Button("Понятно", role: .cancel) {}
        }
    }

    // MARK: - Разделы

    private func sectionLabel(_ text: String) -> some View {
        LXSectionLabel(text: text)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 8)
    }

    private func mainRow(_ title: String, icon: String, count: Int, item: DictionaryFilter) -> some View {
        Button { select(item) } label: {
            rowContent(icon: icon, title: title, subtitle: nil, trailing: count.formatted(),
                       showsChevron: true, isSelected: filter == item)
        }
        .buttonStyle(.plain)
    }

    private func builtInRow(_ title: String, icon: String, item: DictionaryFilter) -> some View {
        Button { select(item) } label: {
            rowContent(icon: icon, title: title, subtitle: nil,
                       trailing: DictionaryCounts.builtIn(item, in: modelContext).formatted(),
                       showsChevron: true, isSelected: filter == item)
        }
        .buttonStyle(.plain)
    }

    /// Шесть карточек уровней встроенной базы
    private var levelCards: some View {
        HStack(spacing: 6) {
            ForEach(CEFRLevel.allCases, id: \.rawValue) { level in
                let item = DictionaryFilter.oxford(level: level.rawValue)
                let count = DictionaryCounts.builtIn(item, in: modelContext)
                Button { select(item) } label: {
                    VStack(spacing: 2) {
                        Text(level.rawValue).scaledFont(size: 15, weight: .semibold).foregroundStyle(Color.brandDark)
                        Text(count.formatted()).scaledFont(size: 12).foregroundStyle(Color.brandMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(filter == item ? Color.brandAccent : Color.cardBackground,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.brandBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(count == 0)
                .opacity(count == 0 ? 0.45 : 1)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Строки

    /// Общий вид строки: значок-плашка, название, подпись, справа число и стрелка
    private func rowContent(icon: String, title: String, subtitle: String?, trailing: String?,
                            showsChevron: Bool, isSelected: Bool = false) -> some View {
        HStack(spacing: 12) {
            LXSquareIcon(systemImage: icon)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .scaledFont(size: 16, weight: .semibold)
                    .foregroundStyle(isSelected ? Color.brandTint : Color.brandDark)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle).scaledFont(size: 13).foregroundStyle(Color.brandMuted).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if isSelected {
                Image(systemName: "checkmark").scaledFont(size: 13, weight: .bold).foregroundStyle(Color.brandTint)
            }
            if let trailing {
                Text(trailing).scaledFont(size: 14).foregroundStyle(Color.brandMuted)
            }
            if showsChevron {
                Image(systemName: "chevron.right").scaledFont(size: 13, weight: .semibold).foregroundStyle(Color.brandMuted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }

    private func listRow(_ list: WordList) -> some View {
        HStack(spacing: 0) {
            Button { select(.list(list)) } label: {
                rowContent(icon: list.photosData == nil ? "text.book.closed" : "photo",
                           title: list.name,
                           subtitle: "\(DictionaryCounts.words(list.words.count)) · свой словарь",
                           trailing: nil, showsChevron: false, isSelected: filter == .list(list))
            }
            .buttonStyle(.plain)
            Button {
                renameText = list.name
                listToRename = list
            } label: { LXIconLabel(systemImage: "pencil", label: "Переименовать") }
                .buttonStyle(.plain)
            Button { listToDelete = list } label: { LXIconLabel(systemImage: "trash", label: "Удалить словарь") }
                .buttonStyle(.plain)
                .padding(.trailing, 6)
        }
    }

    private func folderRow(_ folder: Category) -> some View {
        HStack(spacing: 0) {
            Button { select(.category(folder)) } label: {
                rowContent(icon: "folder", title: folder.name,
                           subtitle: DictionaryCounts.words(DictionaryCounts.category(folder, in: modelContext)),
                           trailing: nil, showsChevron: false, isSelected: filter == .category(folder))
            }
            .buttonStyle(.plain)
            Button {
                renameText = folder.name
                folderToRename = folder
            } label: { LXIconLabel(systemImage: "pencil", label: "Переименовать") }
                .buttonStyle(.plain)
            Button { folderToDelete = folder } label: { LXIconLabel(systemImage: "trash", label: "Удалить папку") }
                .buttonStyle(.plain)
                .padding(.trailing, 6)
        }
    }

    private var newFolderRow: some View {
        Button { isAddingFolder = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .scaledFont(size: 19)
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.brandTint, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                Text("Новая папка").scaledFont(size: 16, weight: .semibold)
                Spacer()
            }
            .foregroundStyle(Color.brandTint)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Действия

    private func select(_ item: DictionaryFilter) {
        Haptics.tap()
        filter = item
        dismiss()
    }

    private func reloadCounts() {
        generalCount = DictionaryCounts.general(in: modelContext)
        mistakeCount = DictionaryCounts.mistakes(in: modelContext)
    }

    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        newFolderName = ""
        guard !name.isEmpty else { return }
        if let existing = categories.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            select(.category(existing))
            return
        }
        let folder = Category(name: name)
        modelContext.insert(folder)
        modelContext.saveReporting()
        select(.category(folder))
    }

    private func renameList() {
        let name = renameText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let list = listToRename else { return }
        // Такое название уже у другого своего словаря — предлагаем объединить, а не заводить второй
        if let existing = lists.first(where: {
            $0.id != list.id && $0.name.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(name) == .orderedSame
        }) {
            listMerge = ListMerge(source: list, target: existing)
        } else {
            list.name = name
            modelContext.saveReporting()
        }
    }

    private func renameFolder() {
        let name = renameText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let folder = folderToRename else { return }
        if categories.contains(where: { $0.id != folder.id && $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            notice = "Папка «\(name)» уже есть. Выберите другое название."
        } else {
            folder.name = name
            modelContext.saveReporting()
        }
    }

    /// Удаляет папку вместе со словами: связь «папка — слова» каскадная
    private func deleteFolder(_ folder: Category) {
        if filter == .category(folder) { filter = .general }
        modelContext.delete(folder)
        modelContext.saveReporting()
        reloadCounts()
    }

    /// Удаляет словарь и свои слова, которые были только в нём; встроенные слова остаются в своих темах
    private func delete(_ list: WordList) {
        isDeletingList = true
        Task {
            // Сначала кадр с «Удаляю словарь…», потом работа на главном потоке
            try? await Task.sleep(for: .milliseconds(50))
            let onlyHere = list.words.filter { $0.isCustom && $0.category == nil && $0.lists.count == 1 }
            // Отвязываем все слова разом: при удалении по одному каждое перестраивало список слов словаря,
            // и словарь из книги (тысячи слов) вешал приложение
            list.words = []
            for word in onlyHere { modelContext.delete(word) }
            studyScope.enabledLists.remove(list.id)
            if filter == .list(list) { filter = .general }
            modelContext.delete(list)
            modelContext.saveReporting()
            isDeletingList = false
            reloadCounts()
        }
    }

    /// Переносит слова в другой свой словарь (без повторов) и удаляет исходный; сами слова не удаляются
    private func merge(_ source: WordList, into target: WordList) {
        for word in Array(source.words) where !word.lists.contains(where: { $0.id == target.id }) {
            word.lists.append(target)
        }
        for photo in source.photos { target.addPhoto(photo) }
        // Был включён в изучение — включаем словарь, в который перешли слова
        if studyScope.enabledLists.remove(source.id) != nil {
            studyScope.enabledLists.insert(target.id)
        }
        if filter == .list(source) { filter = .list(target) }
        modelContext.delete(source)
        modelContext.saveReporting()
    }

    // MARK: - Привязки окон подтверждений

    private func isPresented<Item>(_ item: Binding<Item?>) -> Binding<Bool> {
        Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
    }

    private var noticeBinding: Binding<Bool> {
        Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })
    }
}
