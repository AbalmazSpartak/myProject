import SwiftUI

/// Настройки → «Обзор»: раздел «Фокуса дня», плитки «Быстрого доступа» (порядок — перетаскиванием),
/// показывать ли «Слово дня» и «Ваши подборки»
struct OverviewSettingsView: View {
    @AppStorage(OverviewLayout.storageKey) private var layout = OverviewLayout.standard
    @State private var isConfirmingReset = false

    /// Разделы, которых ещё нет в «Быстром доступе»
    private var available: [MenuSection] {
        OverviewLayout.choices.filter { !layout.quickAccess.contains($0) }
    }

    var body: some View {
        List {
            Group {
                Section {
                    ForEach(layout.focusSections, id: \.self) { section in
                        focusRow(section)
                    }
                    .onMove { layout.focusSections.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { offsets in
                        guard layout.focusSections.count > 1 else { return }
                        layout.focusSections.remove(atOffsets: offsets)
                    }
                    .deleteDisabled(layout.focusSections.count == 1)

                    if layout.focusSections.count < OverviewLayout.maxFocus {
                        Menu {
                            ForEach(OverviewLayout.choices.filter { !layout.focusSections.contains($0) }, id: \.self) { section in
                                Button {
                                    withAnimation { layout.focusSections.append(section) }
                                } label: {
                                    Label(focusTitle(section), systemImage: section.icon)
                                }
                            }
                        } label: {
                            Label("Добавить в карусель", systemImage: "plus.circle.fill")
                        }
                    }
                } header: {
                    Text("Фокус дня")
                } footer: {
                    Text("Большие карточки вверху «Обзора» — листаются свайпом, до трёх. При запуске видна средняя карточка, остальные — свайпом в стороны. Порядок — перетаскиванием, убрать — «−» (одна карточка остаётся всегда). «Интервальное повторение» — «Карточки для запоминания»: слова, которым пора на повторение, и новые по дневной норме.")
                        .textSelection(.enabled)
                }

                Section {
                    if layout.quickAccess.isEmpty {
                        Text("Пусто — блок не показывается")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(layout.quickAccess, id: \.self) { section in
                        sectionRow(section)
                    }
                    .onMove { layout.quickAccess.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { layout.quickAccess.remove(atOffsets: $0) }

                    if !available.isEmpty {
                        Menu {
                            ForEach(available, id: \.self) { section in
                                Button {
                                    withAnimation { layout.quickAccess.append(section) }
                                } label: {
                                    Label(section.title, systemImage: section.icon)
                                }
                            }
                        } label: {
                            Label("Добавить раздел", systemImage: "plus.circle.fill")
                        }
                    }
                } header: {
                    Text("Быстрый доступ")
                } footer: {
                    Text("Плитки по две в ряд. Порядок — перетаскиванием за ручку справа, убрать — кнопкой «−».")
                        .textSelection(.enabled)
                }

                Section {
                    Toggle(isOn: $layout.showsWordOfDay) {
                        Label("Слово дня", systemImage: "bolt.fill")
                    }
                    Toggle(isOn: $layout.showsCollections) {
                        Label("Ваши подборки", systemImage: "text.book.closed.fill")
                    }
                } footer: {
                    Text("«Ваши подборки» — темы «Сообщества», добавленные кнопкой «В мои подборки». Все сразу — по кнопке «Все».")
                        .textSelection(.enabled)
                }

                Section {
                    Button("По умолчанию") { isConfirmingReset = true }
                        .disabled(layout == .standard)
                }
            }
            // Строки — тёплого цвета карточек, а не системного серого
            .listRowBackground(Color.cardBackground)
        }
        // Ручки для перетаскивания видны сразу, без кнопки «Изменить»
        .environment(\.editMode, .constant(.active))
        .brandListBackground()
        .navigationTitle("Обзор")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Вернуть «Обзор» по умолчанию?", isPresented: $isConfirmingReset) {
            Button("Отмена", role: .cancel) {}
            Button("Вернуть", role: .destructive) { layout = .standard }
        } message: {
            Text("«Фокус дня» — «Произнеси», интервальное повторение (в середине) и Таблицы Шульте, в «Быстром доступе» — Карточки ввода, Викторина, Тетрис слов и Слово в контексте; «Слово дня» и «Ваши подборки» снова видны.")
        }
    }

    private func focusTitle(_ section: MenuSection) -> String {
        section == .flashcards ? "Интервальное повторение" : section.title
    }

    private func focusRow(_ section: MenuSection) -> some View {
        HStack(spacing: 12) {
            Image(systemName: section.icon)
                .foregroundColor(section.color)
                .frame(width: 24)
            Text(focusTitle(section))
        }
    }

    private func sectionRow(_ section: MenuSection) -> some View {
        HStack(spacing: 12) {
            Image(systemName: section.icon)
                .foregroundColor(section.color)
                .frame(width: 24)
            Text(section.title)
        }
    }
}
