import SwiftUI
import SwiftData

/// Настройки → Словари: какие уровни, части речи и темы участвуют в тренировках
struct StudyDictionariesView: View {
    @AppStorage(StudyScope.storageKey) private var scope = StudyScope()
    @Environment(\.modelContext) private var modelContext
    @State private var allWords: [Word] = []
    @Query(sort: \WordList.createdAt, order: .reverse) private var lists: [WordList]

    private struct ScopeGroup: Identifiable {
        let key: String
        let title: String
        let count: Int
        var id: String { key }
    }

    private var builtInWords: [Word] { allWords.filter { !$0.isCustom } }

    var body: some View {
        Form {
            Group {
                Section {
                    LabeledContent("Слов для изучения", value: "\(allWords.filter { scope.includes($0) }.count)")
                    if !scope.isEverythingEnabled {
                        Button("Включить все словари") { scope = StudyScope() }
                    }
                } footer: {
                    Text("Слово попадает в тренировки, если отмечены его уровень, часть речи и тема. Например, уровень A1 и только «Глаголы» — это глаголы A1.")
                }

                if !lists.isEmpty {
                    Section {
                        ForEach(lists) { list in
                            checkRow(ScopeGroup(key: list.id.uuidString, title: list.name, count: list.words.count),
                                     isOn: scope.enabledLists.contains(list.id)) {
                                scope.enabledLists.formSymmetricDifference([list.id])
                            }
                        }
                    } header: {
                        Text("Мои словари")
                    } footer: {
                        Text("Если отмечен хотя бы один свой словарь, тренировки идут только по его словам — фильтры ниже не действуют.")
                    }
                }

                Group {
                    Section("Уровни") {
                        ForEach(levelGroups) { group in
                            checkRow(group, isOn: !scope.disabledLevels.contains(group.key)) {
                                scope.disabledLevels.formSymmetricDifference([group.key])
                            }
                        }
                        checkRow(ScopeGroup(key: "custom", title: "Мои слова", count: allWords.filter(\.isCustom).count),
                                 isOn: scope.includeCustomWords) {
                            scope.includeCustomWords.toggle()
                        }
                    }

                    groupSection("Части речи", groups: partOfSpeechGroups, disabled: \.disabledPartsOfSpeech)
                    groupSection("Темы", groups: topicGroups, disabled: \.disabledTopics)
                }
                .disabled(!scope.enabledLists.isEmpty)
            }
            // Строки — тёплого цвета карточек, а не системного серого
            .listRowBackground(Color.cardBackground)
        }
        .brandListBackground()
        .navigationTitle("Словари")
        .onAppear { allWords = modelContext.fetchAllWords() }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Группы со счётчиками
    // Счётчик показывает, сколько слов группа даст с учётом остальных фильтров

    private var levelGroups: [ScopeGroup] {
        CEFRLevel.allCases.map { level in
            ScopeGroup(
                key: level.rawValue,
                title: level.rawValue,
                count: builtInWords.filter { $0.cefrLevel == level.rawValue && scope.includes($0, ignoring: .level) }.count
            )
        }
    }

    private var partOfSpeechGroups: [ScopeGroup] {
        Dictionary(grouping: builtInWords) { StudyScope.partOfSpeechGroup(of: $0) }
            .filter { !$0.key.isEmpty }
            .map { key, words in
                ScopeGroup(key: key, title: key, count: words.filter { scope.includes($0, ignoring: .partOfSpeech) }.count)
            }
            .sorted { StudyScope.partOfSpeechOrder($0.key) < StudyScope.partOfSpeechOrder($1.key) }
    }

    private var topicGroups: [ScopeGroup] {
        Dictionary(grouping: builtInWords) { StudyScope.topic(of: $0) }
            .map { key, words in
                ScopeGroup(key: key, title: key.isEmpty ? "Без темы" : key,
                           count: words.filter { scope.includes($0, ignoring: .topic) }.count)
            }
            .sorted { $0.title < $1.title }
    }

    // MARK: - Строки

    private func groupSection(_ title: String, groups: [ScopeGroup], disabled: WritableKeyPath<StudyScope, Set<String>>) -> some View {
        let allOn = groups.allSatisfy { !scope[keyPath: disabled].contains($0.key) }
        return Section {
            ForEach(groups) { group in
                checkRow(group, isOn: !scope[keyPath: disabled].contains(group.key)) {
                    scope[keyPath: disabled].formSymmetricDifference([group.key])
                }
            }
        } header: {
            HStack {
                Text(title)
                Spacer()
                Button(allOn ? "Снять все" : "Выбрать все") {
                    scope[keyPath: disabled] = allOn ? Set(groups.map(\.key)) : []
                }
                .font(.caption)
                .textCase(nil)
            }
        }
    }

    private func checkRow(_ group: ScopeGroup, isOn: Bool, toggle: @escaping () -> Void) -> some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .scaledFont(size: 20)
                    .foregroundStyle(isOn ? Color.teal : Color.gray.opacity(0.5))
                Text(group.title)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(group.count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}
