import SwiftUI

/// Настройки → Главное меню: порядок разделов (перетаскиванием) и что показывать
struct MainMenuSettingsView: View {
    @AppStorage(MainMenuLayout.storageKey) private var layout = MainMenuLayout.standard

    var body: some View {
        List {
            Section {
                ForEach(layout.items, id: \.self) { item in
                    row(for: item)
                }
                .onMove { layout.items.move(fromOffsets: $0, toOffset: $1) }
            } header: {
                Text("Порядок в меню")
            } footer: {
                Text("«Мой профиль» всегда сверху — через него открываются настройки. Скрытая группа скрывается целиком.")
            }

            ForEach(MenuGroup.allCases, id: \.self) { group in
                Section {
                    ForEach(layout.sections(in: group), id: \.self) { section in
                        row(for: .section(section))
                    }
                    .onMove { layout.groupOrder[group, default: group.sections].move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    Text("В группе «\(group.title)»")
                } footer: {
                    if layout.visibleSections(in: group).isEmpty {
                        Text("Все разделы скрыты — группа не показывается в меню.")
                    }
                }
            }

            Section {
                Button("Как было") { layout = .standard }
                    .disabled(layout == .standard)
            }
        }
        // Ручки для перетаскивания видны сразу, без кнопки «Изменить»
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Главное меню")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(for item: MenuItem) -> some View {
        let (title, icon, color) = description(of: item)
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(title)
            Spacer()
            Toggle(title, isOn: Binding(
                get: { !layout.isHidden(item) },
                set: { layout.setHidden(!$0, for: item) }
            ))
            .labelsHidden()
        }
    }

    private func description(of item: MenuItem) -> (String, String, Color) {
        switch item {
        case .group(let group): return ("Группа «\(group.title)»", group.icon, group.color)
        case .section(let section): return (section.title, section.icon, section.color)
        }
    }
}
