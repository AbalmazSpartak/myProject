import Foundation

/// Распаковка архива .tar.bz2: сначала bzip2 (системная libbz2) во временный .tar, потом сам tar — по заголовкам в 512 байт.
/// Нужна для модели нейросетевого голоса: её официальный архив — .tar.bz2
nonisolated enum TarBz2Extractor {
    enum Failure: Error { case bzip2(Int32), corrupt, io }

    /// Распаковать archive в directory; progress — доля 0…1 по распакованному bzip2
    static func extract(_ archive: URL, to directory: URL, progress: @Sendable (Double) -> Void) throws {
        let tar = directory.appendingPathComponent(".download.tar")
        try decompressBzip2(archive, to: tar, progress: progress)
        defer { try? FileManager.default.removeItem(at: tar) }
        try untar(tar, to: directory)
    }

    // MARK: - bzip2

    private static func decompressBzip2(_ source: URL, to target: URL, progress: @Sendable (Double) -> Void) throws {
        guard let input = InputStream(url: source) else { throw Failure.io }
        FileManager.default.createFile(atPath: target.path, contents: nil)
        guard let output = FileHandle(forWritingAtPath: target.path) else { throw Failure.io }
        defer { try? output.close() }
        input.open()
        defer { input.close() }

        let total = Double((try? FileManager.default.attributesOfItem(atPath: source.path)[.size] as? Int) ?? 1)
        var stream = bz_stream()
        var status = BZ2_bzDecompressInit(&stream, 0, 0)
        guard status == BZ_OK else { throw Failure.bzip2(status) }
        defer { BZ2_bzDecompressEnd(&stream) }

        let chunk = 1 << 20
        var inBuffer = [CChar](repeating: 0, count: chunk)
        var outBuffer = [CChar](repeating: 0, count: chunk * 4)
        var consumed = 0.0
        var finished = false

        while !finished {
            let read = inBuffer.withUnsafeMutableBytes { input.read($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: chunk) }
            if read < 0 { throw Failure.io }
            if read == 0 { break }
            consumed += Double(read)
            try inBuffer.withUnsafeMutableBufferPointer { inPointer in
                stream.next_in = inPointer.baseAddress
                stream.avail_in = UInt32(read)
                while stream.avail_in > 0 {
                    try outBuffer.withUnsafeMutableBufferPointer { outPointer in
                        stream.next_out = outPointer.baseAddress
                        stream.avail_out = UInt32(outPointer.count)
                        status = BZ2_bzDecompress(&stream)
                        guard status == BZ_OK || status == BZ_STREAM_END else { throw Failure.bzip2(status) }
                        let produced = outPointer.count - Int(stream.avail_out)
                        if produced > 0 {
                            output.write(Data(bytes: outPointer.baseAddress!, count: produced))
                        }
                    }
                    if status == BZ_STREAM_END {
                        finished = true
                        break
                    }
                }
            }
            progress(min(consumed / total, 1))
        }
        guard finished else { throw Failure.corrupt }
    }

    // MARK: - tar

    private static func untar(_ tar: URL, to directory: URL) throws {
        guard let handle = FileHandle(forReadingAtPath: tar.path) else { throw Failure.io }
        defer { try? handle.close() }
        let manager = FileManager.default
        var longName: String?

        while true {
            guard let header = try handle.read(upToCount: 512), header.count == 512 else { break }
            // Два пустых блока — конец архива
            if header.allSatisfy({ $0 == 0 }) { break }

            let size = octal(header[124..<136])
            let type = header[156]
            var name = longName ?? string(header[0..<100])
            longName = nil
            let prefix = string(header[345..<500])
            if !prefix.isEmpty, header[257..<262] == Data("ustar".utf8) { name = prefix + "/" + name }
            let padded = (size + 511) / 512 * 512

            // Длинное имя (GNU): содержимое блока — имя следующего файла
            if type == UInt8(ascii: "L") {
                let data = try handle.read(upToCount: padded) ?? Data()
                longName = string(data.prefix(size))
                continue
            }

            guard !name.isEmpty, !name.contains(".."), !name.hasPrefix("/") else {
                try skip(handle, padded)
                continue
            }
            let target = directory.appendingPathComponent(name)
            switch type {
            case UInt8(ascii: "5"):
                try manager.createDirectory(at: target, withIntermediateDirectories: true)
            case UInt8(ascii: "0"), 0:
                try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                manager.createFile(atPath: target.path, contents: nil)
                guard let out = FileHandle(forWritingAtPath: target.path) else { throw Failure.io }
                var left = size
                while left > 0 {
                    let piece = try handle.read(upToCount: min(left, 1 << 20)) ?? Data()
                    if piece.isEmpty { throw Failure.corrupt }
                    out.write(piece)
                    left -= piece.count
                }
                try out.close()
                try skip(handle, padded - size)
            default:
                // Ссылки и служебные записи модели не нужны
                try skip(handle, padded)
            }
        }
    }

    private static func skip(_ handle: FileHandle, _ count: Int) throws {
        guard count > 0 else { return }
        try handle.seek(toOffset: handle.offsetInFile + UInt64(count))
    }

    private static func string(_ bytes: Data) -> String {
        let trimmed = bytes.prefix { $0 != 0 }
        return String(decoding: trimmed, as: UTF8.self)
    }

    private static func octal(_ bytes: Data) -> Int {
        Int(string(bytes).trimmingCharacters(in: .whitespaces), radix: 8) ?? 0
    }
}
