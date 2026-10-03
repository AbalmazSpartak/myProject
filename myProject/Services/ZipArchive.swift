import Foundation
import Compression

/// Минимальное чтение ZIP-архива (EPUB, позже .docx): оглавление архива и файлы без сжатия или со сжатием deflate.
/// Своё — в iOS нет открытого API для распаковки; ZIP64 и шифрованные архивы не поддерживаются
nonisolated struct ZipArchive {
    struct Entry {
        let name: String
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    /// Защита от «бомб»: один файл внутри архива больше этого не распаковываем
    static let maxEntrySize = 50 * 1024 * 1024

    private let bytes: [UInt8]
    let entries: [Entry]

    init?(data: Data) {
        let bytes = [UInt8](data)
        guard let directory = Self.endOfCentralDirectory(in: bytes) else { return nil }
        var entries: [Entry] = []
        var offset = directory.offset
        for _ in 0..<directory.count {
            guard offset + 46 <= bytes.count, Self.uint32(bytes, offset) == 0x0201_4b50 else { return nil }
            let nameLength = Int(Self.uint16(bytes, offset + 28))
            let extraLength = Int(Self.uint16(bytes, offset + 30))
            let commentLength = Int(Self.uint16(bytes, offset + 32))
            guard offset + 46 + nameLength <= bytes.count else { return nil }
            let name = String(decoding: bytes[(offset + 46)..<(offset + 46 + nameLength)], as: UTF8.self)
            entries.append(Entry(name: name,
                                 method: Self.uint16(bytes, offset + 10),
                                 compressedSize: Int(Self.uint32(bytes, offset + 20)),
                                 uncompressedSize: Int(Self.uint32(bytes, offset + 24)),
                                 localHeaderOffset: Int(Self.uint32(bytes, offset + 42))))
            offset += 46 + nameLength + extraLength + commentLength
        }
        self.bytes = bytes
        self.entries = entries
    }

    func contents(of name: String) -> Data? {
        guard let entry = entries.first(where: { $0.name == name }) else { return nil }
        return contents(of: entry)
    }

    func contents(of entry: Entry) -> Data? {
        let header = entry.localHeaderOffset
        guard header + 30 <= bytes.count, Self.uint32(bytes, header) == 0x0403_4b50,
              entry.uncompressedSize <= Self.maxEntrySize else { return nil }
        let start = header + 30 + Int(Self.uint16(bytes, header + 26)) + Int(Self.uint16(bytes, header + 28))
        let end = start + entry.compressedSize
        guard end <= bytes.count else { return nil }

        switch entry.method {
        case 0:
            return Data(bytes[start..<end])
        case 8:
            guard entry.uncompressedSize > 0 else { return Data() }
            return bytes[start..<end].withUnsafeBufferPointer { source -> Data? in
                guard let sourceBase = source.baseAddress else { return nil }
                var output = Data(count: entry.uncompressedSize)
                // COMPRESSION_ZLIB — это «сырой» deflate без заголовка, как в ZIP
                let written = output.withUnsafeMutableBytes { destination -> Int in
                    guard let destinationBase = destination.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                    return compression_decode_buffer(destinationBase, entry.uncompressedSize,
                                                     sourceBase, source.count, nil, COMPRESSION_ZLIB)
                }
                return written == entry.uncompressedSize ? output : nil
            }
        default:
            return nil
        }
    }

    // MARK: - Разбор заголовков

    /// Конец оглавления архива: ищем подпись с конца файла (после неё может быть комментарий до 64 КБ)
    private static func endOfCentralDirectory(in bytes: [UInt8]) -> (offset: Int, count: Int)? {
        guard bytes.count >= 22 else { return nil }
        let lowest = max(0, bytes.count - 22 - 65_535)
        var index = bytes.count - 22
        while index >= lowest {
            if uint32(bytes, index) == 0x0605_4b50 {
                return (Int(uint32(bytes, index + 16)), Int(uint16(bytes, index + 10)))
            }
            index -= 1
        }
        return nil
    }

    private static func uint16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private static func uint32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
    }
}
