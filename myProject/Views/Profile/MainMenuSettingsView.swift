import SwiftUI

/// Настройки → Ленты «Обзора»: порядок (перетаскиванием), видимость, свои группы — каждая группа становится лентой
struct MainMenuSettingsView: View {
    @AppStorage(MainMenuLayout.storageKey) private var layout = MainMenuLayout.standard

    @State private var isCreatingGroup = false
    @State private var editingGroup: MenuGroup?
    @State private var isConfirmingReset = false

    var body: some View {
        List {
            Section {
                ForEach(FixedRibbon.allCases, id: \.self) { ribbon in
                    HStack(spacing: 12) {
                        Image(systemName: ribbon.icon)
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        Text(ribbon.title)
                        Spacer()
                        Toggle(ribbon.title, isOn: Binding(
                            get: { !layout.isHidden(ribbon) },
                            set: { layout.setHidden(!$0, for: ribbon) }
                        ))
                        .labelsHidden()
                    }
                }
            } header: {
                Text("Постоянные ленты")
            } footer: {
                Text("«Слово дня» и «Ваши подборки» всегда вверху «Обзора». Их можно только скрыть.")
            }

            Section {
                ForEach(layout.items.filter { !Self.isTab($0) }, id: \.self) { item in
                    topLevelRow(item)
                }
                .onMove(perform: moveTopLevel)
            } header: {
                Text("Порядок лент")
            } footer: {
                Text("Каждая группа — отдельная лента на «Обзоре», разделы вне групп — лента «Разделы». Профиль и Словарь — во вкладках внизу. Нажмите на группу, чтобы изменить её. Скрытая группа скрывается целиком.")
            }

            ForEach(layout.orderedGroups) { group in
                Section {
                    if group.sections.isEmpty {
                        Text("Пусто — перенесите сюда разделы кнопкой ⋯")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(group.sections.filter { !$0.isTab }, id: \.self) { section in
                        sectionRow(section)
                    }
                    .onMove { moveInGroup(group.id, from: $0, to: $1) }
                } header: {
                    Text("В группе «\(group.name)»")
                } footer: {
                    if !group.sections.isEmpty, layout.visibleSections(in: group.id).isEmpty {
                        Text("Все разделы скрыты — группа не показывается в меню.")
                    }
                }
            }

            Section {
                Button {
                    isCreatingGroup = true
                } label: {
                    Label("Новая группа", systemImage: "folder.badge.plus")
                }
                Button("По умолчанию") { isConfirmingReset = true }
                    .disabled(layout == .standard)
            }
        }
        // Ручки для перетаскивания видны сразу, без кнопки «Изменить»
        .environment(\.editMode, .constant(.active))
        .brandListBackground()
        .navigationTitle("Ленты «Обзора»")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isCreatingGroup) {
            MenuGroupEditorView(group: nil) { name, icon, colorName in
                layout.addGroup(name: name, icon: icon, colorName: colorName)
            }
        }
        .sheet(item: $editingGroup) { group in
            MenuGroupEditorView(group: group) { name, icon, colorName in
                layout.groups[group.id]?.name = name
                layout.groups[group.id]?.icon = icon
                layout.groups[group.id]?.colorName = colorName
            } onDelete: {
                layout.deleteGroup(group.id)
            }
        }
        .alert("Вернуть меню по умолчанию?", isPresented: $isConfirmingReset) {
            Button("Отмена", role: .cancel) {}
            Button("Вернуть", role: .destructive) { layout = .standard }
        } message: {
            Text("Ваши группы удалятся, порядок и скрытые разделы сбросятся, скрытые ленты снова появятся. Сами разделы останутся.")
        }
    }

    /// Вкладки (Словарь) в настройке не показываются — их строки пропускаем
    private static func isTab(_ item: MenuItem) -> Bool {
        if case .section(let section) = item { return section.isTab }
        return false
    }

    /// Перенос в отфильтрованном списке → перенос в полном списке разделов меню
    private func moveTopLevel(from source: IndexSet, to destination: Int) {
        var shown = layout.items.filter { !Self.isTab($0) }
        shown.move(fromOffsets: source, toOffset: destination)
        let hidden = layout.items.filter(Self.isTab)
        layout.items = shown + hidden
    }

    private func moveInGroup(_ groupID: String, from source: IndexSet, to destination: Int) {
        guard let sections = layout.groups[groupID]?.sections else { return }
        var shown = sections.filter { !$0.isTab }
        shown.move(fromOffsets: source, toOffset: destination)
        layout.groups[groupID]?.sections = shown + sections.filter(\.isTab)
    }

    // MARK: - Строки

    @ViewBuilder
    private func topLevelRow(_ item: MenuItem) -> some View {
        switch item {
        case .group(let id):
            if let group = layout.groups[id] {
                HStack(spacing: 12) {
                    Button { editingGroup = group } label: {
                        HStack(spacing: 12) {
                            Image(systemName: group.icon)
                                .foregroundColor(group.color)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Группа «\(group.name)»")
                                    .foregroundColor(.primary)
                                Text(group.sections.isEmpty ? "пустая" : "разделов: \(group.sections.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                    visibilityToggle(for: item, title: group.name)
                }
            }
        case .section(let section):
            sectionRow(section)
        }
    }

    private func sectionRow(_ section: MenuSection) -> some View {
        HStack(spacing: 12) {
            Image(systemName: section.icon)
                .foregroundColor(section.color)
                .frame(width: 24)
            Text(section.title)
            Spacer()
            moveMenu(for: section)
            visibilityToggle(for: .section(section), title: section.title)
        }
    }

    /// «Переместить в…»: в любую группу или в общий список
    private func moveMenu(for section: MenuSection) -> some View {
        let current = layout.groupID(of: section)
        return Menu {
            Section("Переместить в…") {
                ForEach(layout.orderedGroups) { group in
                    Button {
                        withAnimation { layout.move(section, toGroup: group.id) }
                    } label: {
                        Label("«\(group.name)»", systemImage: group.icon)
                    }
                    .disabled(current == group.id)
                }
                Button {
                    withAnimation { layout.move(section, toGroup: nil) }
                } label: {
                    Label("Без группы", systemImage: "list.bullet")
                }
                .disabled(current == nil)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Переместить «\(section.title)»")
    }

    private func visibilityToggle(for item: MenuItem, title: String) -> some View {
        Toggle(title, isOn: Binding(
            get: { !layout.isHidden(item) },
            set: { layout.setHidden(!$0, for: item) }
        ))
        .labelsHidden()
    }
}
