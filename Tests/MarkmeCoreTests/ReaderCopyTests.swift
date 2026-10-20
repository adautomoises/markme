import XCTest
@testable import MarkmeCore

final class ReaderCopyTests: XCTestCase {
    func testPortugueseAndEnglishCopy() {
        XCTAssertEqual(ReaderCopy.string(.modeSource, languageCode: "pt-BR"), "Texto")
        XCTAssertEqual(ReaderCopy.string(.modeSplit, languageCode: "pt"), "Lado a lado")
        XCTAssertEqual(ReaderCopy.string(.modePage, languageCode: "pt-BR"), "Página")
        XCTAssertEqual(ReaderCopy.string(.bannerQuestion, languageCode: "pt-BR"), "Quer abrir os markdown neste visualizador?")
        XCTAssertEqual(ReaderCopy.string(.bannerAccept, languageCode: "pt-BR"), "Usar como padrão")
        XCTAssertEqual(ReaderCopy.string(.bannerNotNow, languageCode: "pt-BR"), "Agora não")
        XCTAssertEqual(ReaderCopy.string(.menuMakeDefault, languageCode: "pt-BR"), "Usar como leitor padrão de Markdown")
        XCTAssertEqual(ReaderCopy.string(.notUTF8, languageCode: "pt-BR"), "Este arquivo não está em texto UTF-8.")
        XCTAssertEqual(ReaderCopy.string(.unreadable, languageCode: "pt-BR"), "Não foi possível ler este arquivo.")
        XCTAssertEqual(ReaderCopy.string(.findPrompt, languageCode: "pt-BR"), "Buscar")
        XCTAssertEqual(ReaderCopy.string(.viewMenu, languageCode: "pt-BR"), "Visualizar")
        XCTAssertEqual(ReaderCopy.string(.viewMenu, languageCode: "en"), "View")
        XCTAssertEqual(ReaderCopy.string(.modeSource, languageCode: "en"), "Text")
        XCTAssertEqual(ReaderCopy.string(.modeSplit, languageCode: "fr"), "Side by side")
        XCTAssertEqual(ReaderCopy.string(.modePage, languageCode: "en"), "Page")
        XCTAssertEqual(ReaderCopy.string(.bannerQuestion, languageCode: "en"), "Open Markdown files in this viewer?")
        XCTAssertEqual(ReaderCopy.string(.notUTF8, languageCode: "en"), "This file is not UTF-8 text.")
        XCTAssertEqual(ReaderCopy.string(.unreadable, languageCode: "en"), "Could not read this file.")
    }
}
