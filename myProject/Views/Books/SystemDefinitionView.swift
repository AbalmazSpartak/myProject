import SwiftUI
import UIKit

/// Толкование слова из встроенного словаря iPhone — бесплатно и без интернета, для любого скачанного языка.
/// Нет словаря для языка — iOS сама предлагает его скачать («Управлять»)
struct SystemDefinitionView: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(_ controller: UIReferenceLibraryViewController, context: Context) {}
}

/// Слово для шторки толкования
struct DefinedWord: Identifiable {
    let id = UUID()
    let term: String
}
