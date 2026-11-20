import SwiftUI
import SwiftData
import PhotosUI

/// «Изменить слово» по дизайну LexiStream: слово и транскрипция, часть речи, перевод, пример, уровень, тема, картинка.
/// «Отмена» возвращает значения, с которыми окно открыли
struct EditWordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var word: Word
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var isConfirmingDelete = false
    /// Удаляем после закрытия окна, чтобы форма не обращалась к уже удалённому слову
    @State private var deleteOnClose = false
    @State private var isReporting = false
    /// Слово из базы до правки — что поменяли, уходит сигналом для улучшения словаря
    @State private var original: [String: String]?
    /// Значения при открытии — для «Отмены»
    @State private var snapshot: Snapshot?
    @State private var pickedPhoto: PhotosPickerItem?

    private struct Snapshot {
        let english: String
        let transcription: String
        let russian: String
        let partOfSpeech: String
        let example: String
        let cefrLevel: String
        let category: Category?
    }

    private var canSave: Bool {
        !word.english.trimmingCharacters(in: .whitespaces).isEmpty && !word.russian.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            LXNavBar(title: "Изменить слово") {
                LXTextButton(title: "Отмена", isMuted: true, action: cancel)
            } trailing: {
                LXTextButton(title: "Готово", isEnabled: canSave, action: save)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        LXField(label: "Слово") {
                            TextField("Английское слово", text: $word.english)
                                .scaledFont(size: 20, design: .serif)
                                .foregroundStyle(Color.brandDark)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        LXField(label: "Транскрипция") {
                            TextField("Транскрипция", text: $word.transcription)
                                .scaledFont(size: 16)
                                .foregroundStyle(Color.brandDark)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }
                    PartOfSpeechChips(code: $word.partOfSpeech)
                        .padding(.top, 4)
                    LXField(label: "Перевод", hint: "Варианты через запятую") {
                        TextField("Перевод на русский", text: $word.russian)
                            .scaledFont(size: 17)
                            .foregroundStyle(Color.brandDark)
                            .autocorrectionDisabled()
                    }
                    LXField(label: "Пример", hint: "Изучаемое слово в примере отмечается так: <b>слово</b>") {
                        TextField("Предложение со словом", text: $word.example, axis: .vertical)
                            .scaledFont(size: 16, design: .serif)
                            .foregroundStyle(Color.brandDark)
                            .lineLimit(1...5)
                    }
                    levelPicker
                        .padding(.top, 4)
                    LXField(label: "Тема или папка") {
                        Menu {
                            Button("Без темы") { word.category = nil }
                            ForEach(categories) { category in
                                Button(category.name) { word.category = category }
                            }
                        } label: {
                            HStack {
                                Text(word.category?.name ?? "Без темы")
                                    .scaledFont(size: 17)
                                    .foregroundStyle(Color.brandDark)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .scaledFont(size: 13, weight: .semibold)
                                    .foregroundStyle(Color.brandMuted)
                            }
                            .contentShape(Rectangle())
                        }
                    }
                    picturePicker
                    listsSection
                    reportSection
                    deleteSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .confirmationDialog("Удалить «\(word.english)»?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                deleteOnClose = true
                dismiss()
            }
        }
        .onDisappear {
            guard deleteOnClose else { return }
            modelContext.delete(word)
            modelContext.saveReporting()
        }
        .onAppear {
            if !word.isCustom, original == nil { original = DictionarySignals.fields(of: word) }
            if snapshot == nil {
                snapshot = Snapshot(english: word.english, transcription: word.transcription, russian: word.russian,
                                    partOfSpeech: word.partOfSpeech, example: word.example, cefrLevel: word.cefrLevel,
                                    category: word.category)
            }
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task { await usePhoto(item) }
        }
        .sheet(isPresented: $isReporting) {
            ReportWordView(word: word)
                .presentationDetents([.large])
                .appThemedColorScheme()
        }
    }

    // MARK: - Части формы

    private var levelPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            LXSectionLabel(text: "Уровень")
            HStack(spacing: 8) {
                ForEach(CEFRLevel.allCases, id: \.rawValue) { level in
                    LXChip(title: level.rawValue, isOn: word.cefrLevel == level.rawValue) { word.cefrLevel = level.rawValue }
                }
            }
        }
    }

    /// Картинка слова — из фото или галереи; иначе её подбирает интернет
    private var picturePicker: some View {
        LXCard(radius: 14) {
            HStack(spacing: 12) {
                Group {
                    if let data = word.imageData, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Image(systemName: "photo").scaledFont(size: 20).foregroundStyle(Color.brandMuted)
                    }
                }
                .frame(width: 52, height: 52)
                .background(Color.brandFill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Картинка").scaledFont(size: 16, weight: .semibold).foregroundStyle(Color.brandDark)
                    Text("Из фото или галереи").scaledFont(size: 12).foregroundStyle(Color.brandMuted)
                }
                Spacer()
                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    LXChipLabel(title: "Заменить")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    /// Слово в своих словарях (например, из книги): убрать из одного, не удаляя само слово
    @ViewBuilder
    private var listsSection: some View {
        if !word.lists.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(word.lists) { list in
                    LXButton(title: word.lists.count == 1 ? "Удалить из словаря" : "Удалить из словаря «\(DictionaryView.shortName(list.name))»",
                             style: .outline) {
                        word.lists.removeAll { $0.id == list.id }
                        modelContext.saveReporting()
                    }
                }
                Text("Слово и его прогресс останутся — пропадёт только из выбранного словаря.")
                    .scaledFont(size: 12)
                    .foregroundStyle(Color.brandMuted)
            }
            .padding(.top, 6)
        }
    }

    /// Ошибка в слове из встроенного словаря — сообщить, чтобы поправили в базе для всех
    @ViewBuilder
    private var reportSection: some View {
        if !word.isCustom {
            VStack(alignment: .leading, spacing: 6) {
                LXButton(title: "Сообщить об ошибке", systemImage: "flag", style: .outline) { isReporting = true }
                Text("Ваши правки выше меняют слово только у вас. Сообщение об ошибке поможет исправить его во встроенном словаре.")
                    .scaledFont(size: 12)
                    .foregroundStyle(Color.brandMuted)
            }
            .padding(.top, 6)
        }
    }

    /// Удалить можно только своё слово: слово из базы вернулось бы при обновлении words.csv
    @ViewBuilder
    private var deleteSection: some View {
        if word.isCustom {
            VStack(alignment: .leading, spacing: 6) {
                Button { isConfirmingDelete = true } label: {
                    Text("Удалить слово")
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundStyle(Color.statusLearning)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.brandBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Text(word.lists.isEmpty ? "Слово удалится с устройства вместе с прогрессом."
                     : "Слово удалится с устройства и из всех ваших словарей (\(word.lists.count)).")
                    .scaledFont(size: 12)
                    .foregroundStyle(Color.brandMuted)
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Действия

    private func cancel() {
        if let snapshot {
            word.english = snapshot.english
            word.transcription = snapshot.transcription
            word.russian = snapshot.russian
            word.partOfSpeech = snapshot.partOfSpeech
            word.example = snapshot.example
            word.cefrLevel = snapshot.cefrLevel
            word.category = snapshot.category
        }
        dismiss()
    }

    private func save() {
        word.english = word.english.trimmingCharacters(in: .whitespacesAndNewlines)
        word.transcription = word.transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        word.russian = word.russian.trimmingCharacters(in: .whitespacesAndNewlines)
        word.example = word.example.trimmingCharacters(in: .whitespacesAndNewlines)
        word.partOfSpeech = word.partOfSpeech.trimmingCharacters(in: .whitespacesAndNewlines)
        if let original { DictionarySignals.recordEdit(word, original: original) }
        dismiss()
    }

    /// Фото из галереи — в слово; большое сжимаем, чтобы база не пухла
    private func usePhoto(_ item: PhotosPickerItem) async {
        defer { pickedPhoto = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let jpeg = Self.compressed(data) else { return }
        word.imageData = jpeg
        word.imageNotFound = false
        word.isImageHidden = false
    }

    private static func compressed(_ data: Data, maxSide: CGFloat = 1024) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.8) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
