import Foundation

public enum CopyKey: String, Sendable {
    case modeSource
    case modeSplit
    case modePage
    case bannerQuestion
    case bannerAccept
    case bannerNotNow
    case menuMakeDefault
    case notUTF8
    case unreadable
    case findPrompt
}

public enum ReaderCopy {
    public static func string(_ key: CopyKey, languageCode: String) -> String {
        let portuguese = languageCode.lowercased().hasPrefix("pt")
        switch key {
        case .modeSource: return portuguese ? "Texto" : "Text"
        case .modeSplit: return portuguese ? "Lado a lado" : "Side by side"
        case .modePage: return portuguese ? "Página" : "Page"
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
        }
    }
}
