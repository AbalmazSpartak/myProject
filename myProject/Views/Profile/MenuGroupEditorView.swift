import SwiftUI

/// Создание и правка своей группы главного меню: название, иконка, цвет
struct MenuGroupEditorView: View {
    @Environment(\.dismiss) private var dismiss

    /// nil — новая группа
    let group: MenuGroup?
    let onSave: (_ name: String, _ icon: String, _ colorName: String) -> Void
    var onDelete: (() -> Void)? = nil

    @State private var name: String
    @State private var icon: String
    @State private var colorName: String
    @State private var isConfirmingDelete = false

    init(group: MenuGroup?, onSave: @escaping (String, String, String) -> Void, onDelete: (() -> Void)? = nil) {
        self.group = group
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: group?.name ?? "")
        _icon = State(initialValue: group?.icon ?? MenuPalette.icons[0])
        _colorName = State(initialValue: group?.colorName ?? MenuPalette.colors[0].name)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        preview
                    }

                    Section("Название") {
                        TextField("Например, «Каждый день»", text: $name)
                    }

                    Section("Иконка") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 14) {
                            ForEach(MenuPalette.icons, id: \.self) { symbol in
                                Button { icon = symbol } label: {
                                    Image(systemName: symbol)
                                        .scaledFont(size: 20)
                                        .foregroundColor(symbol == icon ? .white : MenuPalette.color(named: colorName))
                                        .frame(width: 40, height: 40)
                                        .background(symbol == icon ? MenuPalette.color(named: colorName) : Color.brandFill)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                    }

                    Section("Цвет") {
                        HStack {
                            ForEach(MenuPalette.colors, id: \.name) { item in
                                Button { colorName = item.name } label: {
                                    Circle()
                                        .fill(item.color)
                                        .frame(width: 30, height: 30)
                                        .overlay(Circle().stroke(Color.primary, lineWidth: item.name == colorName ? 3 : 0).padding(-4))
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 6)
                    }

                    if group != nil, onDelete != nil {
                        Section {
                            Button("Удалить группу", role: .destructive) { isConfirmingDelete = true }
                        } footer: {
                            Text("Разделы группы не удалятся — они встанут в меню на её место.")
                        }
                    }
                }
                // Строки — тёплого цвета карточек, а не системного серого
                .listRowBackground(Color.cardBackground)
            }
            .brandListBackground()
            .navigationTitle(group == nil ? "Новая группа" : "Группа")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        onSave(trimmedName, icon, colorName)
                        dismiss()
                    }
                    .bold()
                    .disabled(trimmedName.isEmpty)
                }
            }
            .confirmationDialog("Удалить группу «\(group?.name ?? "")»?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            }
        }
    }

    /// Как группа будет выглядеть в главном меню
    private var preview: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(MenuPalette.color(named: colorName))
                .scaledFont(size: 18)
            Text(trimmedName.isEmpty ? "Название группы" : trimmedName)
                .scaledFont(size: 20, weight: .bold)
                .foregroundColor(trimmedName.isEmpty ? .secondary : .primary)
            Spacer()
            Image(systemName: "chevron.down")
                .scaledFont(size: 14, weight: .semibold)
                .foregroundColor(.gray)
        }
        .padding(14)
        .background(Color.brandFill)
        .cornerRadius(18)
        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
    }
}
