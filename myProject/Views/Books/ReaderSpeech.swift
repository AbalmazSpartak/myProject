import AVFoundation
import MediaPlayer
import NaturalLanguage
import Observation
import SwiftUI

/// Чтение книги вслух: абзац за абзацем, по предложениям, с подсветкой абзаца и произносимого слова.
/// Нейросетевым голосом, если он скачан (английские — Kokoro, русские — Piper), — с подсветкой предложения.
/// Играет и при выключенном экране, как аудиокнига: пауза — с экрана блокировки и кнопкой наушников
@MainActor
@Observable
final class ReaderSpeech: NSObject {
    /// Скорость относительно настройки «Озвучки»
    static let speedKey = "reader_speech_speed"
    static let speeds: [Double] = [0.75, 1, 1.25, 1.5]
    /// Паузы чтеца: между предложениями — короткая, между абзацами — длиннее
    private static let sentencePause: TimeInterval = 0.12
    private static let paragraphPause: TimeInterval = 0.3

    private(set) var isPlaying = false
    /// Читаемый абзац главы; nil — чтение не начиналось или остановлено
    private(set) var paragraph: Int?
    /// Произносимое слово внутри абзаца (UTF-16, как NSRange); у нейросетевого голоса — всё предложение
    private(set) var word: NSRange?
    /// Нейросетевой голос готовит фразу — на ▶️ крутится индикатор
    private(set) var isPreparing = false
    /// Короткое сообщение в читалке (например, голос сменился сам); читалка показывает и убирает
    var notice: String?

    /// Глава кончилась — читалка открывает следующую и вызывает start
    @ObservationIgnored var onChapterEnd: (() -> Void)?
    /// Язык книги не английский — голос этого языка; nil — английский голос из «Озвучки»
    @ObservationIgnored var language: String?

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var paragraphs: [String] = []
    @ObservationIgnored private var title = ""
    @ObservationIgnored private var bookTitle = ""
    @ObservationIgnored private var author = ""
    @ObservationIgnored private var artwork: MPMediaItemArtwork?
    /// Начало каждого абзаца в символах от начала главы — для полоски на экране блокировки
    @ObservationIgnored private var offsets: [Int] = []
    /// Сколько символов в секунду читает голос; уточняется по прочитанным абзацам
    @ObservationIgnored private var charsPerSecond = 14.0
    @ObservationIgnored private var utteranceStart: Date?
    /// Предложения абзаца, отданные голосу: где в абзаце каждый их символ. Колбэки прерванных старых не засчитываются
    @ObservationIgnored private var maps: [ObjectIdentifier: SpokenText.Piece] = [:]
    /// Последнее предложение абзаца — после него следующий абзац
    @ObservationIgnored private var lastPiece: AVSpeechUtterance?
    @ObservationIgnored private var remoteReady = false

    // Нейросетевой голос: звук готовится по предложению вперёд и играет через свой плеер
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private let player = AVAudioPlayerNode()
    /// Частота, на которую подключён плеер (у Kokoro и Piper она разная); nil — плеер ещё не подключён
    @ObservationIgnored private var playerRate: Double?
    @ObservationIgnored private var neuralTask: Task<Void, Never>?
    /// Номер чтения нейросетевым голосом: после паузы или перемотки старые куски не засчитываются
    @ObservationIgnored private var generation = 0
    /// Готовые, но ещё не доигранные куски — по порядку, со своей длиной звука
    @ObservationIgnored private var queue: [(paragraph: Int, range: NSRange, seconds: Double)] = []
    /// Сколько секунд звука готово вперёд; голос готовит дальше, пока запас меньше lookahead
    @ObservationIgnored private var queuedSeconds = 0.0
    private static let lookahead = 18.0
    /// Kokoro: запас больше — куски крупнее и выгоднее; чтение начинается (и после перебоя продолжается),
    /// когда готово 10 с: с меньшим запасом на iPhone 12 следующий кусок не успевает
    private static let kokoroLookahead = 30.0
    private static let kokoroStartBuffer = 10.0
    /// Ждём запаса holdThreshold секунд, прежде чем играть (старт или перебой)
    @ObservationIgnored private var isHolding = false
    @ObservationIgnored private var holdThreshold = 0.0
    /// Пауза нейросетевого голоса — настоящая: готовый звук ждёт, продолжение сразу
    @ObservationIgnored private var neuralPaused = false
    @ObservationIgnored private var neuralIsKokoro = false
    @ObservationIgnored private var producerDone = false
    /// Нейросетевой голос не справился — до выхода из читалки читает системный
    @ObservationIgnored private var neuralFailed = false
    /// Замер Kokoro: сколько фраз, сколько готовил и сколько звучит
    @ObservationIgnored private var kokoroCheck = (count: 0, made: 0.0, length: 0.0, underruns: 0)
    /// Подписки на события звука — пока идёт чтение, снимаются при выходе из читалки
    @ObservationIgnored private var audioObservers: [NSObjectProtocol] = []

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Текст главы для чтения
    func load(paragraphs: [String], chapterTitle: String, bookTitle: String, author: String, cover: Data?) {
        self.paragraphs = paragraphs
        title = chapterTitle
        if bookTitle != self.bookTitle || artwork == nil {
            artwork = Self.artwork(cover: cover, title: bookTitle)
        }
        self.bookTitle = bookTitle
        self.author = author
        var total = 0
        offsets = paragraphs.map { paragraph in
            defer { total += (paragraph as NSString).length }
            return total
        }
        offsets.append(total)
    }

    /// Начать с абзаца; offset — с какого символа в нём («Читать отсюда» в карточке слова)
    func start(from index: Int, offset: Int = 0) {
        guard paragraphs.indices.contains(index) else { return }
        stopSynthesizer()
        activateSession()
        setUpRemoteCommands()
        isPlaying = true
        word = nil
        speak(index, from: offset)
    }

    func pause() {
        guard isPlaying else { return }
        isPlaying = false
        utteranceStart = nil
        if neuralTask != nil {
            // Нейросетевой голос — настоящая пауза: готовый звук не выбрасываем, продолжение сразу
            neuralPaused = true
            player.pause()
            isPreparing = false
        } else {
            // Не pauseSpeaking: после нескольких пауз с экрана блокировки continueSpeaking
            // «играет» без звука. Останавливаем, а продолжаем заново с этого слова
            stopSynthesizer()
        }
        updateNowPlaying()
    }

    /// ⏭ на экране блокировки, двойное нажатие на наушниках
    func nextParagraph() {
        guard let paragraph else { return }
        if paragraphs.indices.contains(paragraph + 1) {
            start(from: paragraph + 1)
        } else {
            stopSynthesizer()
            isPlaying = false
            self.paragraph = nil
            onChapterEnd?()
        }
    }

    /// ⏮ — предыдущий абзац; в самом первом — с его начала
    func previousParagraph() {
        guard let paragraph else { return }
        start(from: max(paragraph - 1, 0))
    }

    /// Скорость сменили во время чтения — дальше с этого же слова уже на новой (абзац отдан голосу целиком)
    func speedChanged() {
        // На паузе готовый звук — на старой скорости: выбрасываем, продолжение приготовит заново
        if neuralPaused {
            stopNeural()
            return
        }
        guard isPlaying, let paragraph else { return }
        let from = word?.location ?? 0
        stopSynthesizer()
        speak(paragraph, from: from)
    }

    func resume() {
        guard !isPlaying, let paragraph else { return }
        activateSession()
        isPlaying = true
        if neuralPaused {
            neuralPaused = false
            if isHolding {
                isPreparing = true
                startPlaybackIfReady()
            } else {
                if !audioEngine.isRunning { try? audioEngine.start() }
                player.play()
            }
            updateNowPlaying()
            return
        }
        speak(paragraph, from: word?.location ?? 0)
    }

    /// Выход из читалки: тишина, подсветка снимается, экран блокировки очищается
    func stop() {
        isPlaying = false
        paragraph = nil
        word = nil
        stopSynthesizer()
        audioEngine.stop()
        audioObservers.forEach(NotificationCenter.default.removeObserver)
        audioObservers = []
        TextToSpeechManager.keepsSessionActive = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Речь

    private func speak(_ index: Int, from offset: Int = 0) {
        if !neuralFailed, let voice = NeuralVoice.shared.bookVoice(language: language ?? BookLanguage.english) {
            speakNeural(index, from: offset, voice: voice)
        } else {
            speakSystem(index, from: offset)
        }
    }

    /// Абзац (с символа offset) — системному голосу сразу всеми предложениями: между ними паузы, но без задержек на запуск
    private func speakSystem(_ index: Int, from offset: Int = 0) {
        paragraph = index
        let text = paragraphs[index]
        let start = offset > 0 && offset < (text as NSString).length ? offset : 0
        word = start > 0 ? word : nil
        maps = [:]
        utteranceStart = nil
        let pieces = SpokenText.pieces(of: text, from: start, language: language ?? BookLanguage.english)
        guard !pieces.isEmpty else {
            // Абзац без слов («* * *», одна сноска) — сразу дальше
            paragraphFinished()
            return
        }
        let voice = currentVoice()
        let rate = currentRate()
        for (number, piece) in pieces.enumerated() {
            let utterance = AVSpeechUtterance(string: piece.text)
            utterance.voice = voice
            utterance.rate = rate
            // Перед репликой — вдох
            if number == 0, start == 0, SpokenText.isDialogue(text) { utterance.preUtteranceDelay = 0.15 }
            let isLast = number == pieces.count - 1
            utterance.postUtteranceDelay = isLast ? Self.paragraphPause : Self.sentencePause
            maps[ObjectIdentifier(utterance)] = piece
            if isLast { lastPiece = utterance }
            synthesizer.speak(utterance)
        }
        updateNowPlaying()
    }

    private func currentVoice() -> AVSpeechSynthesisVoice? {
        if let language { return SpeechSettings.bestVoice(language: language) }
        let accent = UserDefaults.standard.string(forKey: SpeechSettings.accentKey) ?? SpeechSettings.defaultAccent
        let identifier = UserDefaults.standard.string(forKey: SpeechSettings.voiceKey) ?? ""
        return SpeechSettings.resolveVoice(accent: accent, identifier: identifier)
    }

    private func currentRate() -> Float {
        let base = UserDefaults.standard.object(forKey: SpeechSettings.rateKey) as? Double ?? SpeechSettings.defaultRate
        let speed = UserDefaults.standard.object(forKey: Self.speedKey) as? Double ?? 1
        // Выше 0,75 голос iOS начинает глотать слова
        return Float(min(max(base * speed, Double(AVSpeechUtteranceMinimumSpeechRate)), 0.75))
    }

    private func stopSynthesizer() {
        maps = [:]
        lastPiece = nil
        if synthesizer.isSpeaking || synthesizer.isPaused { synthesizer.stopSpeaking(at: .immediate) }
        stopNeural()
    }

    private func finished(_ utterance: AVSpeechUtterance) {
        guard maps[ObjectIdentifier(utterance)] != nil, isPlaying else { return }
        calibrate(utterance)
        if utterance === lastPiece { paragraphFinished() }
    }

    private func paragraphFinished() {
        guard let paragraph else { return }
        word = nil
        if paragraphs.indices.contains(paragraph + 1) {
            speak(paragraph + 1)
        } else {
            // Следующую главу читалка готовит сама и продолжает чтение
            isPlaying = false
            self.paragraph = nil
            onChapterEnd?()
        }
    }

    /// Произносимое слово в предложении → то же место в абзаце
    private func spoke(_ range: NSRange, in utterance: AVSpeechUtterance) {
        guard let piece = maps[ObjectIdentifier(utterance)], !piece.starts.isEmpty else { return }
        let lower = min(range.location, piece.starts.count - 1)
        let upper = min(max(range.location + range.length, lower + 1), piece.starts.count)
        let start = piece.starts[lower]
        word = NSRange(location: start, length: max(piece.ends[upper - 1] - start, 1))
    }

    /// Сессия звука — общая с озвучкой слов; пока идёт чтение, озвучка слов её не выключает.
    /// Без .duckOthers: приглушающее приложение iOS не считает плеером — кнопка наушников
    /// и экран блокировки достались бы другому. Музыка на время книги встаёт на паузу
    private func activateSession() {
        TextToSpeechManager.keepsSessionActive = true
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        observeAudio()
    }

    private func observeAudio() {
        guard audioObservers.isEmpty else { return }
        let center = NotificationCenter.default
        audioObservers = [
            // Наушники вынули — пауза, как у любого плеера
            center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
                let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                guard reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
                MainActor.assumeIsolated { self?.pause() }
            },
            // Звук переключился на другое устройство — плеер нейросетевого голоса остановлен, продолжаем с предложения
            center.addObserver(forName: .AVAudioEngineConfigurationChange, object: audioEngine, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.speedChanged() }
            },
        ]
    }

    /// Предложение прочитано без пауз — уточняем скорость голоса для полоски времени
    private func calibrate(_ utterance: AVSpeechUtterance) {
        let length = (utterance.speechString as NSString).length
        guard let utteranceStart, length > 40 else { return }
        let seconds = Date().timeIntervalSince(utteranceStart) - utterance.postUtteranceDelay
        guard seconds > 1 else { return }
        charsPerSecond = charsPerSecond * 0.6 + Double(length) / seconds * 0.4
    }

    private func started(_ utterance: AVSpeechUtterance) {
        guard maps[ObjectIdentifier(utterance)] != nil else { return }
        utteranceStart = Date()
        updateNowPlaying()
    }

    // MARK: - Нейросетевой голос

    /// Звук готовится вперёд, пока звучит готовое, — главы идут без пауз. Piper — по предложению,
    /// Kokoro — большими кусками (см. produceKokoro). Подсвечивается предложение целиком: время отдельных слов
    /// модель не отдаёт. Пока запас не накоплен, на ▶️ крутится индикатор
    private func speakNeural(_ index: Int, from offset: Int, voice: NeuralVoice.BookVoice) {
        stopNeural()
        paragraph = index
        isPreparing = true
        let isKokoro = if case .kokoro = voice.model { true } else { false }
        neuralIsKokoro = isKokoro
        holdThreshold = isKokoro ? Self.kokoroStartBuffer : 0
        isHolding = true
        let current = generation
        let language = language ?? BookLanguage.english
        let speed = neuralSpeed()
        neuralTask = Task {
            if isKokoro {
                await produceKokoro(from: index, offset: offset, voice: voice, speed: speed, language: language, generation: current)
            } else {
                await producePiper(from: index, offset: offset, voice: voice, speed: speed, language: language, generation: current)
            }
            guard generation == current else { return }
            producerDone = true
            if queue.isEmpty {
                chapterFinished()
            } else {
                startPlaybackIfReady()
            }
        }
    }

    /// Piper готовит быстро — по предложению, с паузами чтеца между ними
    private func producePiper(from index: Int, offset: Int, voice: NeuralVoice.BookVoice, speed: Float,
                              language: String, generation current: Int) async {
        var paragraphIndex = index
        var from = offset
        while paragraphIndex < paragraphs.count {
            let text = paragraphs[paragraphIndex]
            let pieces = SpokenText.pieces(of: text, from: from, language: language)
            for (number, piece) in pieces.enumerated() {
                guard await waitForRoom(limit: Self.lookahead, generation: current),
                      let result = await generate(piece.text, voice: voice, speed: speed, generation: current,
                                                  fallback: (paragraphIndex, piece.starts[0])) else { return }
                // Перед репликой — вдох; после предложения — короткая пауза, после абзаца — длиннее
                let before = number == 0 && from == 0 && SpokenText.isDialogue(text) ? 0.15 : 0
                let after = number == pieces.count - 1 ? Self.paragraphPause : Self.sentencePause
                guard enqueue(result.audio.samples[...], rate: Double(result.audio.sampleRate), before: before, after: after,
                              paragraph: paragraphIndex, range: Self.range(of: piece), generation: current) else {
                    fail(paragraph: paragraphIndex, from: piece.starts[0])
                    return
                }
            }
            paragraphIndex += 1
            from = 0
        }
    }

    /// Kokoro на каждый вызов тратит ~1,35 с «разгона» (iPhone 12) плюс ~0,8 с на секунду речи — короткими фразами
    /// он не успевает, большими кусками успевает. Поэтому куски — через абзацы, размером по запасу: успеет
    /// приготовиться, пока звучит готовое (от 8 до 25 с речи). Чтение начинается, когда готово 10 с.
    /// Звук куска делится обратно на предложения — подсветка идёт по ним
    private func produceKokoro(from index: Int, offset: Int, voice: NeuralVoice.BookVoice, speed: Float,
                               language: String, generation current: Int) async {
        var sentences: [(paragraph: Int, piece: SpokenText.Piece, endsParagraph: Bool)] = []
        var nextParagraph = index
        var from = offset
        while true {
            guard await waitForRoom(limit: Self.kokoroLookahead, generation: current) else { return }
            // До старта — стартовый запас; дальше — 85% того, что уже готово
            let seconds = isHolding && queue.isEmpty ? holdThreshold : min(max(queuedSeconds * 0.85, 8), 25)
            let target = max(Int(seconds * charsPerSecond), 40)
            var length = sentences.reduce(0) { $0 + $1.piece.text.count }
            while length < target, nextParagraph < paragraphs.count {
                let pieces = SpokenText.pieces(of: paragraphs[nextParagraph], from: from, language: language)
                for (number, piece) in pieces.enumerated() {
                    sentences.append((nextParagraph, piece, number == pieces.count - 1))
                    length += piece.text.count
                }
                nextParagraph += 1
                from = 0
            }
            guard !sentences.isEmpty else { return }
            // Кусок — целые предложения, пока не набрана нужная длина
            var batch: [(paragraph: Int, piece: SpokenText.Piece, endsParagraph: Bool)] = []
            var batchLength = 0
            while let next = sentences.first, batch.isEmpty || batchLength + next.piece.text.count <= target {
                batch.append(sentences.removeFirst())
                batchLength += next.piece.text.count
            }
            let first = batch[0]
            guard let result = await generate(batch.map(\.piece.text).joined(separator: " "), voice: voice, speed: speed,
                                              generation: current, fallback: (first.paragraph, first.piece.starts[0])) else { return }
            let rate = Double(result.audio.sampleRate)
            if NeuralVoice.shared.checksKokoroSpeed,
               kokoroCantKeepUp(made: result.made, length: Double(result.audio.samples.count) / rate) {
                switchFromKokoro(paragraph: first.paragraph, from: first.piece.starts[0])
                return
            }
            // Границы предложений — по длине текста (с поправкой на паузу после каждого), подогнанные к тишине
            let pause = Int(charsPerSecond * 0.35)
            let parts = Self.split(result.audio.samples, rate: rate, weights: batch.map { $0.piece.text.count + pause })
            for (number, (sentence, part)) in zip(batch, parts).enumerated() {
                let after = number < batch.count - 1 ? 0 : sentence.endsParagraph ? Self.paragraphPause : Self.sentencePause
                guard enqueue(result.audio.samples[part], rate: rate, before: 0, after: after, paragraph: sentence.paragraph,
                              range: Self.range(of: sentence.piece), generation: current) else {
                    fail(paragraph: sentence.paragraph, from: sentence.piece.starts[0])
                    return
                }
            }
        }
    }

    /// Ждём, пока запас не опустится ниже limit; на паузе не готовим — модель свободна для слов из карточки.
    /// false — чтение остановлено или начато заново
    private func waitForRoom(limit: Double, generation current: Int) async -> Bool {
        while queuedSeconds >= limit || neuralPaused, generation == current, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(200))
        }
        return generation == current && !Task.isCancelled
    }

    /// Звук от модели и сколько он готовился; модель не справилась — дальше системным голосом (nil)
    private func generate(_ text: String, voice: NeuralVoice.BookVoice, speed: Float, generation current: Int,
                          fallback: (paragraph: Int, offset: Int)) async -> (audio: NeuralVoiceEngine.Audio, made: Double)? {
        let began = Date()
        do {
            var audio = try await NeuralVoice.shared.bookAudio(text, voice: voice, speed: speed)
            guard generation == current else { return nil }
            // Каждый кусок модель выдаёт со своей громкостью — выравниваем, чтобы чтение не «скакало»
            audio = NeuralVoiceEngine.Audio(samples: Self.leveled(audio.samples), sampleRate: audio.sampleRate)
            let made = Date().timeIntervalSince(began)
            #if DEBUG
            let length = Double(audio.samples.count) / Double(audio.sampleRate)
            print(String(format: "[TTS] %.2f с готовил → %.2f с звука (×%.2f), запас %.1f с, %d симв.",
                         made, length, made / max(length, 0.01), queuedSeconds, text.count))
            fflush(stdout)
            #endif
            return (audio, made)
        } catch {
            guard generation == current, !(error is CancellationError) else { return nil }
            fail(paragraph: fallback.paragraph, from: fallback.offset)
            return nil
        }
    }

    /// Нейросетевой голос не справился — до выхода из читалки читает системный, с этого места
    private func fail(paragraph index: Int, from offset: Int) {
        neuralFailed = true
        stopNeural()
        speakSystem(index, from: offset)
    }

    /// Замер Kokoro по кускам 2–4 (в первом — загрузка модели): готовит ли он быстрее, чем звучит
    private func kokoroCantKeepUp(made: Double, length: Double) -> Bool {
        kokoroCheck.count += 1
        guard kokoroCheck.count > 1, kokoroCheck.count <= 4 else { return false }
        kokoroCheck.made += made
        kokoroCheck.length += length
        return kokoroCheck.count == 4 && kokoroCheck.made >= kokoroCheck.length
    }

    /// Kokoro не успевает — запоминаем и продолжаем с этого места другим голосом: Piper, если скачан, иначе системным
    private func switchFromKokoro(paragraph index: Int, from offset: Int) {
        NeuralVoice.shared.markKokoroTooSlow()
        let resume = queue.first.map { ($0.paragraph, $0.range.location) } ?? (index, offset)
        stopNeural()
        let next = NeuralVoice.shared.bookVoice(language: language ?? BookLanguage.english)
        notice = next == nil
            ? "Kokoro не успевает на этом устройстве — читает системный голос. Быстрый голос Piper: Настройки → Озвучка → Нейросетевой голос"
            : "Kokoro не успевает на этом устройстве — читает голос Piper"
        speak(resume.0, from: resume.1)
    }

    /// Звук — в очередь плеера, с тишиной до и после; false — плеер не запустился
    private func enqueue(_ samples: ArraySlice<Float>, rate: Double, before: TimeInterval, after: TimeInterval,
                         paragraph: Int, range: NSRange, generation current: Int) -> Bool {
        do { try preparePlayer(rate: rate) } catch { return false }
        let lead = Int(before * rate)
        let count = lead + samples.count + Int(after * rate)
        guard count > 0, let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)),
              let channel = buffer.floatChannelData?[0] else { return true }
        buffer.frameLength = AVAudioFrameCount(count)
        channel.initialize(repeating: 0, count: count)
        samples.withUnsafeBufferPointer { part in
            if let base = part.baseAddress { channel.advanced(by: lead).update(from: base, count: part.count) }
        }
        let seconds = Double(count) / rate
        queue.append((paragraph, range, seconds))
        queuedSeconds += seconds
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in self?.bufferPlayed(current) }
        }
        // Скорость голоса для полоски времени — по настоящей длине звука
        if seconds > 1 { charsPerSecond = charsPerSecond * 0.6 + Double(range.length) / seconds * 0.4 }
        startPlaybackIfReady()
        return true
    }

    private func preparePlayer(rate: Double) throws {
        if playerRate != rate {
            audioEngine.stop()
            if playerRate == nil { audioEngine.attach(player) } else { audioEngine.disconnectNodeOutput(player) }
            audioEngine.connect(player, to: audioEngine.mainMixerNode,
                                format: AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
            playerRate = rate
        }
        if !audioEngine.isRunning { try audioEngine.start() }
    }

    /// Запас накоплен (или больше готовить нечего) — играем
    private func startPlaybackIfReady() {
        guard isHolding, !neuralPaused, !queue.isEmpty, queuedSeconds >= holdThreshold || producerDone else { return }
        isHolding = false
        isPreparing = false
        if !audioEngine.isRunning { try? audioEngine.start() }
        player.play()
        showCurrent()
    }

    /// Предложение доиграло — подсветка на следующее; всё доиграло и больше нечего — глава кончилась
    private func bufferPlayed(_ current: Int) {
        guard current == generation, !queue.isEmpty else { return }
        let played = queue.removeFirst()
        queuedSeconds = max(queuedSeconds - played.seconds, 0)
        if !queue.isEmpty {
            showCurrent()
        } else if producerDone {
            chapterFinished()
        } else {
            // Голос не успел приготовить следующее — ждём запаса (Kokoro — как на старте, чтобы не заикаться)
            player.pause()
            isHolding = true
            holdThreshold = neuralIsKokoro ? Self.kokoroStartBuffer : 0
            isPreparing = true
            #if DEBUG
            print("[TTS] запас кончился — пауза")
            fflush(stdout)
            #endif
            if neuralIsKokoro, NeuralVoice.shared.checksKokoroSpeed {
                kokoroCheck.underruns += 1
                // Запас кончается второй раз — Kokoro здесь не тянет
                if kokoroCheck.underruns >= 2 { switchFromKokoro(paragraph: played.paragraph, from: played.range.location) }
            }
        }
    }

    private func showCurrent() {
        guard let first = queue.first else { return }
        paragraph = first.paragraph
        word = first.range
        updateNowPlaying()
    }

    private func chapterFinished() {
        // Следующую главу читалка готовит сама и продолжает чтение
        isPlaying = false
        paragraph = nil
        word = nil
        onChapterEnd?()
    }

    private func stopNeural() {
        generation += 1
        neuralTask?.cancel()
        neuralTask = nil
        queue = []
        queuedSeconds = 0
        producerDone = false
        neuralPaused = false
        isHolding = false
        isPreparing = false
        if playerRate != nil { player.stop() }
    }

    /// Громкость куска — к одному уровню: средняя громкость речи (без тишины) → 0,1, пики не выше 0,95
    private static func leveled(_ samples: [Float]) -> [Float] {
        let window = 480
        var energies: [Float] = []
        var index = 0
        while index + window <= samples.count {
            var energy: Float = 0
            for sample in samples[index..<(index + window)] { energy += sample * sample }
            energies.append(energy / Float(window))
            index += window
        }
        // Речь — окна громче четверти самого громкого: паузы среднюю не занижают
        guard let loudest = energies.max(), loudest > 0 else { return samples }
        let speech = energies.filter { $0 > loudest * 0.25 * 0.25 }
        let rms = sqrt(speech.reduce(0, +) / Float(max(speech.count, 1)))
        guard rms > 0.0001 else { return samples }
        let peak = samples.reduce(0) { max($0, abs($1)) }
        let gain = min(0.1 / rms, 0.95 / max(peak, 0.0001))
        return samples.map { $0 * gain }
    }

    private static func range(of piece: SpokenText.Piece) -> NSRange {
        NSRange(location: piece.starts[0], length: piece.ends[piece.ends.count - 1] - piece.starts[0])
    }

    /// Звук куска — по предложениям: границы по весам (длине текста), подогнанные к самому тихому месту рядом (±0,6 с)
    private static func split(_ samples: [Float], rate: Double, weights: [Int]) -> [Range<Int>] {
        let total = weights.reduce(0, +)
        guard weights.count > 1, total > 0 else { return [0..<samples.count] }
        let window = max(Int(rate * 0.02), 2)
        let radius = Int(rate * 0.6)
        var bounds = [0]
        var sum = 0
        for weight in weights.dropLast() {
            sum += weight
            let estimate = Int(Double(samples.count) * Double(sum) / Double(total))
            let lower = bounds[bounds.count - 1]
            let from = max(lower + window, estimate - radius)
            let to = min(samples.count - window, estimate + radius)
            var best = min(max(estimate, lower), samples.count)
            if from < to {
                var quietest = Float.infinity
                for position in stride(from: from, to: to, by: window / 2) {
                    var energy: Float = 0
                    for index in position..<(position + window) { energy += samples[index] * samples[index] }
                    if energy < quietest {
                        quietest = energy
                        best = position + window / 2
                    }
                }
            }
            bounds.append(best)
        }
        bounds.append(samples.count)
        return zip(bounds, bounds.dropFirst()).map { $0..<$1 }
    }

    /// Скорость нейросетевого голоса: множитель читалки и — мягче — скорость речи из «Озвучки»
    private func neuralSpeed() -> Float {
        let base = UserDefaults.standard.object(forKey: SpeechSettings.rateKey) as? Double ?? SpeechSettings.defaultRate
        let speed = UserDefaults.standard.object(forKey: Self.speedKey) as? Double ?? 1
        return Float(speed * min(max(base / SpeechSettings.defaultRate, 0.75), 1.25))
    }

    // MARK: - Экран блокировки и наушники

    private func setUpRemoteCommands() {
        guard !remoteReady else { return }
        remoteReady = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isPlaying ? self.pause() : self.resume()
            }
            return .success
        }
        // ⏮ ⏭ — по абзацам; у AirPods это двойное и тройное нажатие
        center.nextTrackCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.nextParagraph() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.previousParagraph() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let time = event.positionTime
            MainActor.assumeIsolated { self?.seek(to: time) }
            return .success
        }
    }

    /// Полоска на экране блокировки перетащена — читаем с абзаца, куда она попала
    private func seek(to time: TimeInterval) {
        guard !paragraphs.isEmpty else { return }
        let index = (0..<paragraphs.count).last { seconds(at: offsets[$0], paragraph: $0) <= time } ?? 0
        start(from: index)
    }

    /// Время от начала главы; паузы между абзацами — отдельно, паузы между предложениями входят в скорость
    private func seconds(at characters: Int, paragraph: Int) -> TimeInterval {
        Double(characters) / charsPerSecond + Double(paragraph) * Self.paragraphPause
    }

    private func updateNowPlaying() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: author.isEmpty ? bookTitle : author,
            MPMediaItemPropertyAlbumTitle: bookTitle,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let total = offsets.last, total > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = seconds(at: total, paragraph: paragraphs.count)
            if let paragraph, offsets.indices.contains(paragraph) {
                info[MPNowPlayingInfoPropertyElapsedPlaybackTime] =
                    seconds(at: offsets[paragraph] + (word?.location ?? 0), paragraph: paragraph)
            }
        }
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Обложка для экрана блокировки; без картинки — та же плашка с названием, что в библиотеке
    private static func artwork(cover: Data?, title: String) -> MPMediaItemArtwork? {
        let image: UIImage? = cover.flatMap(UIImage.init(data:)) ?? {
            let renderer = ImageRenderer(content: BookCover(data: nil, title: title).frame(width: 300, height: 450))
            renderer.scale = 2
            return renderer.uiImage
        }()
        return image.map(Self.artwork(image:))
    }

    /// Картинку система просит из своего потока — замыкание не должно быть привязано к главному
    private nonisolated static func artwork(image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}

extension ReaderSpeech: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange,
                                       utterance: AVSpeechUtterance) {
        nonisolated(unsafe) let utterance = utterance
        Task { @MainActor in self.spoke(characterRange, in: utterance) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        nonisolated(unsafe) let utterance = utterance
        Task { @MainActor in self.started(utterance) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        nonisolated(unsafe) let utterance = utterance
        Task { @MainActor in self.finished(utterance) }
    }
}

/// Текст абзаца для голоса — по предложениям, как читает чтец: без сносок [1] и _подчёркиваний_ из текстов Gutenberg,
/// «т. е.» → «то есть», CHAPTER IV → CHAPTER 4, тире внутри фразы — пауза, а тире реплики не читается.
/// starts, ends — где в абзаце каждый символ произносимого текста (UTF-16): по ним подсвечивается слово в книге
enum SpokenText {
    struct Piece {
        let text: String
        let starts: [Int]
        let ends: [Int]
    }

    private typealias Spoken = (units: [unichar], starts: [Int], ends: [Int])

    /// Что найти и чем заменить; пустая строка — не читать
    private static let rules: [(NSRegularExpression, (String) -> String)] = [
        (regex("_"), { _ in "" }),
        (regex(#"\s?\[\d{1,3}\]|\s?\{\d{1,3}\}|[¹²³⁴⁵⁶⁷⁸⁹⁰]+"#), { _ in "" }),
        // В конце предложения точка сокращения — и точка предложения
        (regex(#"\bи\s?т\.\s?д\.(?=\s*(?:$|[—–A-ZА-ЯЁ"“«]))"#), { _ in "и так далее." }),
        (regex(#"\bи\s?т\.\s?д\."#), { _ in "и так далее" }),
        (regex(#"\bи\s?т\.\s?п\.(?=\s*(?:$|[—–A-ZА-ЯЁ"“«]))"#), { _ in "и тому подобное." }),
        (regex(#"\bи\s?т\.\s?п\."#), { _ in "и тому подобное" }),
        (regex(#"\bт\.\s?е\."#), { _ in "то есть" }),
        (regex(#"\bт\.\s?к\."#), { _ in "так как" }),
        (regex(#"\bi\.\s?e\."#), { _ in "that is" }),
        (regex(#"\be\.\s?g\."#), { _ in "for example" }),
        // Номер главы римскими цифрами — арабскими: голос читает «Chapter four», а не «Chapter i-v».
        // Только в заголовке: после номера — конец, точка, тире или заглавная («for my part I think» не трогаем)
        (regex(#"(?<=\b(?:CHAPTER|Chapter|BOOK|Book|PART|Part|ГЛАВА|Глава|ЧАСТЬ|Часть|КНИГА|Книга)\s)[IVXLC]+\b(?=\s*$|\s*[.:—–]|\s+[A-ZА-ЯЁ"“«])"#,
               caseSensitive: true), { arabic($0) }),
        (regex(#"^\s*[IVXLC]+(?=\.?\s*$)"#, caseSensitive: true), { arabic($0) }),
        // Тире реплики в начале не читается; после «!», «?», «.» — просто пробел; внутри фразы — пауза, как запятая
        (regex(#"^\s*[—–]\s*"#), { _ in "" }),
        (regex(#"(?<=[!?.…])\s+[—–]\s+"#), { _ in " " }),
        (regex(#",?\s+[—–]\s+|\s*--\s*"#), { _ in ", " }),
        (regex(#"(?<=\w)[—–](?=\w)"#), { _ in ", " }),
    ]

    /// Абзац с символа start — предложения для голоса
    static func pieces(of paragraph: String, from start: Int, language: String) -> [Piece] {
        let source = paragraph as NSString
        guard start < source.length else { return [] }
        var spoken: Spoken = (Array(source.substring(from: start).utf16), Array(start..<source.length),
                              Array(start + 1...source.length))
        for (pattern, replacement) in rules {
            spoken = apply(pattern, replacement, to: spoken)
        }
        let text = String(utf16CodeUnits: spoken.units, count: spoken.units.count)
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        tokenizer.setLanguage(NLLanguage(rawValue: language))
        var pieces: [Piece] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let found = NSRange(range, in: text)
            var lower = found.location
            var upper = found.location + found.length
            while lower < upper, isSpace(spoken.units[lower]) { lower += 1 }
            while upper > lower, isSpace(spoken.units[upper - 1]) { upper -= 1 }
            let piece = String(utf16CodeUnits: Array(spoken.units[lower..<upper]), count: upper - lower)
            // «* * *» и прочее без букв и цифр — не читаем
            if piece.contains(where: { $0.isLetter || $0.isNumber }) {
                pieces.append(Piece(text: piece, starts: Array(spoken.starts[lower..<upper]), ends: Array(spoken.ends[lower..<upper])))
            }
            return true
        }
        return pieces
    }

    /// Реплика: абзац начинается с тире или кавычки
    static func isDialogue(_ paragraph: String) -> Bool {
        guard let first = paragraph.first(where: { !$0.isWhitespace }) else { return false }
        return "—–“\"«‘'".contains(first)
    }

    /// Замена по правилу; каждый символ замены указывает на всё найденное — слово подсветится целиком
    private static func apply(_ pattern: NSRegularExpression, _ replacement: (String) -> String, to spoken: Spoken) -> Spoken {
        let string = String(utf16CodeUnits: spoken.units, count: spoken.units.count) as NSString
        let matches = pattern.matches(in: string as String, range: NSRange(location: 0, length: string.length))
        guard !matches.isEmpty else { return spoken }
        var result: Spoken = ([], [], [])
        var last = 0
        for match in matches {
            let range = match.range
            guard range.length > 0 else { continue }
            result.units += spoken.units[last..<range.location]
            result.starts += spoken.starts[last..<range.location]
            result.ends += spoken.ends[last..<range.location]
            let replaced = replacement(string.substring(with: range))
            let units = Array(replaced.utf16)
            // Пауза вместо тире («, ») не растягивает подсветку соседнего слова на тире
            let isPause = !replaced.contains { $0.isLetter || $0.isNumber }
            let start = spoken.starts[range.location]
            result.units += units
            result.starts += Array(repeating: start, count: units.count)
            result.ends += Array(repeating: isPause ? start : spoken.ends[range.location + range.length - 1], count: units.count)
            last = range.location + range.length
        }
        result.units += spoken.units[last...]
        result.starts += spoken.starts[last...]
        result.ends += spoken.ends[last...]
        return result
    }

    /// IV → 4; не римское число — как было
    private static func arabic(_ roman: String) -> String {
        let values: [Character: Int] = ["I": 1, "V": 5, "X": 10, "L": 50, "C": 100]
        var total = 0
        var largest = 0
        for character in roman.trimmingCharacters(in: .whitespaces).reversed() {
            guard let value = values[character] else { return roman }
            total += value < largest ? -value : value
            largest = max(largest, value)
        }
        return total > 0 ? String(total) : roman
    }

    private static func isSpace(_ unit: unichar) -> Bool {
        Unicode.Scalar(unit).map(CharacterSet.whitespacesAndNewlines.contains) ?? false
    }

    private static func regex(_ pattern: String, caseSensitive: Bool = false) -> NSRegularExpression {
        // Шаблоны написаны здесь же — ошибка в них видна при первом чтении вслух
        try! NSRegularExpression(pattern: pattern, options: caseSensitive ? [] : [.caseInsensitive])
    }
}
