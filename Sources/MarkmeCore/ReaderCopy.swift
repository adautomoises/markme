import Foundation

public enum CopyKey: String, Sendable {
    case viewMenu
    case modeSource
    case modeSplit
    case modePage
    case modePresentation
    case bannerQuestion
    case bannerAccept
    case bannerNotNow
    case menuMakeDefault
    case notUTF8
    case unreadable
    case findPrompt
    case zoomIn
    case zoomOut
    case actualSize
    case changesSeen
    case changesPrevious
    case changesNext
}

public enum ReaderCopy {
    /// Interface copy. Portuguese when the language code starts with "pt", English otherwise.
    public static func string(_ key: CopyKey, languageCode: String) -> String {
        let portuguese = languageCode.lowercased().hasPrefix("pt")
        switch key {
        case .viewMenu: return portuguese ? "Visualizar" : "View"
        case .modeSource: return portuguese ? "Texto" : "Text"
        case .modeSplit: return portuguese ? "Lado a lado" : "Side by side"
        case .modePage: return portuguese ? "Página" : "Page"
        case .modePresentation: return portuguese ? "Apresentação" : "Presentation"
        case .bannerQuestion:
            return portuguese
                ? "Quer abrir os markdown neste visualizador?"
                : "Open Markdown files in this viewer?"
        case .bannerAccept: return portuguese ? "Usar como padrão" : "Use as default"
        case .bannerNotNow: return portuguese ? "Agora não" : "Not now"
        case .menuMakeDefault:
            return portuguese
                ? "Usar como leitor padrão de Markdown"
                : "Use as Default Markdown Reader"
        case .notUTF8:
            return portuguese
                ? "Este arquivo não está em texto UTF-8."
                : "This file is not UTF-8 text."
        case .unreadable:
            return portuguese
                ? "Não foi possível ler este arquivo."
                : "Could not read this file."
        case .findPrompt: return portuguese ? "Buscar" : "Find"
        case .zoomIn: return portuguese ? "Aumentar" : "Zoom In"
        case .zoomOut: return portuguese ? "Diminuir" : "Zoom Out"
        case .actualSize: return portuguese ? "Tamanho real" : "Actual Size"
        case .changesSeen: return portuguese ? "Visto" : "Seen"
        case .changesPrevious: return portuguese ? "Mudança anterior" : "Previous change"
        case .changesNext: return portuguese ? "Próxima mudança" : "Next change"
        }
    }

    public static func linesRemoved(_ count: Int, languageCode: String) -> String {
        let portuguese = languageCode.lowercased().hasPrefix("pt")
        if count == 1 {
            return portuguese ? "1 linha removida" : "1 line removed"
        }
        return portuguese ? "\(count) linhas removidas" : "\(count) lines removed"
    }

    public static func changePosition(current: Int, total: Int, languageCode: String) -> String {
        let portuguese = languageCode.lowercased().hasPrefix("pt")
        return portuguese ? "\(current) de \(total)" : "\(current) of \(total)"
    }
}
