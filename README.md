# markme

Leitor de Markdown para macOS. Um dois cliques no Finder abre o arquivo já formatado. A janela só lê: o texto pode ser selecionado e copiado, e não é editado.

Precisa do macOS 14 ou mais novo.

## Na janela

A abertura fica na página. Enquanto a janela está aberta, o menu Visualizar troca o modo:

| Modo | Atalho |
| --- | --- |
| Texto | ⌘1 |
| Lado a lado | ⌘2 |
| Página | ⌘3 |
| Apresentação | ⌘4 |

Na apresentação, cada `---` do markdown começa um slide. A seta para a direita, espaço e Return avançam. A seta para a esquerda volta. Escape retorna à página.

O zoom fica no mesmo menu: aumentar (⌘+), diminuir (⌘-) e tamanho real (⌘0). Command com a rodinha do mouse usa o mesmo zoom.

A página colore o código, inclusive Dart, Flutter e Kotlin. Um bloco `mermaid` vira diagrama. Um bloco Gherkin colore as tags e as palavras de passo.

Extensões: `md`, `markdown`, `mdown`, `mkd`, `mdwn`. Só UTF-8. Um arquivo, uma janela.

## Compilar

```sh
swift test
scripts/package-app.sh
open -a "$PWD/Markme.app" Fixtures/fim-de-semana.md
```

`scripts/package-app.sh` gera `Markme.app` com assinatura ad hoc desta máquina. A pasta do app não entra no git.

Os exemplos em `Fixtures/` são texto inventado para abrir o leitor.

## Licença

[MIT](LICENSE). Highlight.js, a gramática Dart e o Mermaid têm licença própria. Os avisos estão em [NOTICE](NOTICE).
