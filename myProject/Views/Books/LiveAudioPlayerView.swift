import SwiftUI

/// Плеер живой озвучки LibriVox: обложка, глава и чтец, полоска времени, кнопки, скорость, список глав
struct LiveAudioPlayerView: View {
    let book: Book

    @State private var player = LiveAudioPlayer.shared
    @State private var downloader = LiveAudioDownloader.shared
    @State private var scrubTime: Double?
    @State private var isShowingChapters = false

    private var isMine: Bool { player.isCurrent(book.id) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Color.clear
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .frame(width: 180)
                    .overlay { BookCover(data: book.coverData, title: book.title) }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
                    .padding(.top, 8)

                VStack(spacing: 4) {
                    Text(player.currentSection?.title ?? book.title)
                        .scaledFont(size: 22, weight: .semibold, design: .serif)
                        .foregroundStyle(Color.brandDark)
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .scaledFont(size: 14)
                        .foregroundStyle(Color.brandMuted)
                        .multilineTextAlignment(.center)
                }

                if isMine { timeline; controls; speedPicker }
                chapters
                Text("Живой голос LibriVox: книгу читает человек-волонтёр. Запись — общественное достояние. Скачанные главы играют без интернета, остальные — онлайн.")
                    .scaledFont(size: 12)
                    .foregroundStyle(Color.brandMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .frame(maxWidth: PadLayout.columnWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { player.open(book: book.id, title: book.title, cover: book.coverData) }
    }

    private var subtitle: String {
        let reader = player.currentSection?.reader ?? ""
        return [book.author, reader.isEmpty ? "" : "читает \(reader)"].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    // MARK: - Время и кнопки

    private var timeline: some View {
        VStack(spacing: 4) {
            Slider(value: Binding(get: { scrubTime ?? player.time }, set: { scrubTime = $0 }),
                   in: 0...max(player.duration, 1)) { editing in
                if !editing, let scrubTime {
                    player.seek(to: scrubTime)
                    self.scrubTime = nil
                }
            }
            .tint(.brandTint)
            HStack {
                Text(Self.clock(scrubTime ?? player.time))
                Spacer()
                if player.isLoading { ProgressView().controlSize(.mini) }
                Spacer()
                Text("−" + Self.clock(max(player.duration - (scrubTime ?? player.time), 0)))
            }
            .scaledFont(size: 12)
            .monospacedDigit()
            .foregroundStyle(Color.brandMuted)
        }
    }

    private var controls: some View {
        HStack(spacing: 28) {
            controlButton("backward.end.fill", size: 20, label: "Предыдущая глава") { player.previousSection() }
            controlButton("gobackward.15", size: 24, label: "Назад на 15 секунд") { player.skip(-15) }
            Button { player.togglePlay() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.brandOnButton)
                    .frame(width: 68, height: 68)
                    .background(Color.brandButton, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Пауза" : "Слушать")
            controlButton("goforward.30", size: 24, label: "Вперёд на 30 секунд") { player.skip(30) }
            controlButton("forward.end.fill", size: 20, label: "Следующая глава") { player.nextSection() }
        }
    }

    private func controlButton(_ icon: String, size: CGFloat, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundStyle(Color.brandTint)
                .frame(width: 40, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var speedPicker: some View {
        Picker("Скорость", selection: $player.speed) {
            ForEach(LiveAudioPlayer.speeds, id: \.self) { speed in
                Text(speed == 1 ? "1×" : "\(speed.formatted())×").tag(speed)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Главы

    @ViewBuilder
    private var chapters: some View {
        if let audiobook = player.audiobook, isMine {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isShowingChapters.toggle() }
                } label: {
                    HStack {
                        Text("Главы: \(audiobook.sections.count)")
                            .scaledFont(size: 15, weight: .semibold)
                            .foregroundStyle(Color.brandDark)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .scaledFont(size: 14, weight: .semibold)
                            .foregroundStyle(Color.brandTint)
                            .rotationEffect(.degrees(isShowingChapters ? 90 : 0))
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if isShowingChapters {
                    ForEach(audiobook.sections) { section in
                        Divider()
                        chapterRow(section)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.brandBorder, lineWidth: 1))
        }
    }

    private func chapterRow(_ section: LibriVox.Section) -> some View {
        let isCurrent = player.section == section.number
        // Чтение job.done — чтобы значок обновлялся по ходу загрузки
        _ = downloader.job?.done
        let isLocal = LiveAudioStore.isDownloaded(book: book.id, section: section.number)
        return Button { player.play(section: section.number) } label: {
            HStack(spacing: 10) {
                Text(section.title)
                    .lineLimit(1)
                    .foregroundStyle(isCurrent ? Color.brandTint : Color.brandDark)
                    .fontWeight(isCurrent ? .semibold : .regular)
                Spacer()
                Text(LibriVox.durationText(section.seconds))
                    .foregroundStyle(Color.brandMuted)
                Image(systemName: isLocal ? "checkmark.circle" : "icloud")
                    .foregroundStyle(Color.brandMuted)
                    .accessibilityLabel(isLocal ? "Скачана" : "Онлайн")
            }
            .scaledFont(size: 15)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    static func clock(_ seconds: Double) -> String {
        let total = Int(seconds.isFinite ? seconds : 0)
        let hours = total / 3600, minutes = total % 3600 / 60, rest = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, rest) : String(format: "%d:%02d", minutes, rest)
    }
}
