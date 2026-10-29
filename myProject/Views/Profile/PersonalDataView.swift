import SwiftUI
import PhotosUI

/// Профиль → нажатие на аватар или имя: фото, аватарка и имя
struct PersonalDataView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserProfile

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isChoosingAvatar = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.teal.opacity(0.15))
                                .frame(width: 60, height: 60)

                            if let data = profile.avatarData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.fill")
                                    .scaledFont(size: 30)
                                    .foregroundColor(.teal)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            // Подпись PhotosPicker — Sendable-замыкание: профиль читаем заранее
                            let photoButtonTitle = profile.avatarData == nil ? "Загрузить фото" : "Изменить фото"
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Text(photoButtonTitle)
                                    .scaledFont(size: 15, weight: .semibold)
                                    .foregroundColor(.teal)
                            }
                            .buttonStyle(.borderless)

                            Button("Выбрать аватарку") { isChoosingAvatar = true }
                                .scaledFont(size: 15, weight: .semibold)
                                .foregroundColor(.teal)
                                .buttonStyle(.borderless)

                            if profile.avatarData != nil {
                                Button("Удалить фото", role: .destructive) {
                                    profile.avatarData = nil
                                    selectedPhotoItem = nil
                                }
                                .scaledFont(size: 13)
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    TextField("Ваше имя", text: $profile.name)
                        .autocorrectionDisabled()
                }
                .listRowBackground(Color.cardBackground)
            }
            .brandListBackground()
            .navigationTitle("Личные данные")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .sheet(isPresented: $isChoosingAvatar) {
                AvatarPickerView(name: profile.name) { data in
                    profile.avatarData = data
                    selectedPhotoItem = nil
                }
                .appThemedColorScheme()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            if let uiImage = UIImage(data: data),
                               let compressedData = uiImage.jpegData(compressionQuality: 0.7) {
                                profile.avatarData = compressedData
                            } else {
                                profile.avatarData = data
                            }
                        }
                    }
                }
            }
        }
    }
}
