# markme 1.0 — visualizador de markdown

Data: 2026-10-20

## Intent

O markme é um visualizador pequeno de markdown para Mac. O Finder abre ele quando a pessoa dá dois cliques num arquivo. A página formatada aparece na hora.

Hoje esse clique cai num editor grande e o arquivo chega cru, com a marcação à vista. A comparação com o bloco de notas do Windows vale só para três coisas: peso, velocidade e ser o programa padrão do sistema. A janela em si é um visualizador fácil. A página é o lugar onde a pessoa fica.

A versão 1.0 só lê. Nada é gravado de volta no arquivo.

## Para quem

Uma pessoa no MacBook, no meio de outra tarefa, que achou um `.md` no Finder, na Mesa, em Downloads ou num anexo salvo. Ela quer ler. Não quer esperar um editor de projeto subir, nem ver árvore de pastas, git ou painel de plugin.

## Goals

- Dois cliques num markdown no Finder abrem o markme já na página formatada.
- A pessoa consegue tornar o markme o leitor padrão, com a confirmação que o macOS exige. O app não troca o padrão em silêncio.
- Três modos, na ordem do plugin de markdown do IntelliJ: Texto, Lado a lado, Página.
- A página cobre o markdown do dia a dia, por inteiro.
- A janela sobe rápido e fica leve na memória.
- Dá para selecionar e copiar, no texto e na página.
- Um arquivo, uma janela.

## Non-goals da 1.0

- Editar ou gravar o arquivo. Recortar e colar no documento ficam desligados. Copiar fica ligado.
- Diagrama (Mermaid e semelhantes) e fórmula matemática (TeX, KaTeX, MathJax).
- Git, árvore de pastas, painel de projeto, abas de workspace, plugins, temas baixáveis.
- MDX e outros formatos com código executável misturado ao markdown.
- Exportar PDF, imprimir, publicar, sincronizar conta.
- App Store e notarização. A 1.0 roda na máquina de quem desenvolve.

## Decisões já tomadas

Estas vieram da conversa ou foram assumidas em voz alta e seguidas adiante.

- A 1.0 é só visualizador.
- App nativo de Mac, uma janela por arquivo.
- Ao abrir, o modo é sempre Página. Trocar de modo vale enquanto a janela estiver aberta. A próxima abertura volta para Página.
- Ordem dos botões, da esquerda para a direita: Texto, Lado a lado, Página. Página é o botão selecionado na abertura.
- Diagrama e fórmula ficam fora, para o app não carregar um motor pesado.

## Como é feito

App SwiftUI, no modelo de documento do sistema (`DocumentGroup` somente leitura). Isso entrega de graça abrir, abrir recente, uma janela por arquivo e restaurar a janela.

- A visão Texto é um campo de texto nativo, somente leitura, monoespaçado, com quebra de linha e número de linha. Sem cor de sintaxe. A cor fica na página.
- A visão Página é HTML gerado na hora, mostrado no WebKit que já vem no macOS. Não embutir outro navegador.
- O markdown é interpretado com cmark-gfm, no próprio processo, fora da thread principal.
- Blocos de código na página ganham cor para as linguagens comuns: bash, css, go, html, javascript, json, markdown, python, rust, sql, swift, typescript, yaml. Linguagem desconhecida ou ausente aparece como texto monoespaçado, sem cor.
- No modo Lado a lado, o texto fica à esquerda e a página à direita. O divisor começa no meio, pode ser arrastado, e cada lado guarda no mínimo 240 pontos.
- A rolagem dos dois lados se acompanha nos dois sentidos, pelo número da linha de origem marcado em cada bloco da página. Acompanhar por bloco basta. Não precisa casar o pixel.

### Arquivos que abre

Extensões: `md`, `markdown`, `mdown`, `mkd`, `mdwn`. Não abre `mdx` nem `txt`.

Codificação: UTF-8. Se o arquivo não for texto UTF-8, a janela fica aberta com o nome do arquivo e a frase "Este arquivo não está em texto UTF-8."

Arquivo vazio: página em branco, nome do arquivo na barra, sem ilustração de estado vazio.

Arquivo grande: sem corte artificial. A interface continua respondendo enquanto a página é montada.

Se o arquivo mudar no disco com a janela aberta, a janela relê sozinha. Se a leitura falhar, a janela mostra "Não foi possível ler este arquivo." e a mensagem do sistema, curta, sem pilha de erro.

### Página

O HTML do arquivo não executa. Remover `script`, `iframe`, `object`, `embed` e atributos de evento. HTML cru do markdown entra só como formatação.

Imagem com caminho relativo resolve a partir da pasta do arquivo. Imagem remota carrega se houver rede. Caminho que não abre permanece no fluxo, com o caminho visível.

Link `http` e `https` abre no navegador padrão. Link para outro markdown relativo abre outra janela do markme. Link âncora rola a página.

Dá para selecionar o texto da página. Copiar leva o texto composto, não a marcação.

A página mostra, quando o arquivo tiver:

- título e subtítulo em todos os níveis
- ênfase, forte, riscado
- lista, lista ordenada, lista de tarefas
- citação
- código em linha e bloco cercado
- link e link automático
- imagem
- tabela
- linha horizontal
- nota de rodapé do GFM, se o cmark-gfm já entregar

### Janela

Janela de documento do macOS. O nome do arquivo fica no título. Sem barra lateral. Sem barra de status.

Uma barra de ferramentas, fina. Na ponta direita, um controle segmentado com três ícones, na ordem acima:

- Texto: ícone de linhas de texto. Atalho Command-1.
- Lado a lado: ícone de duas colunas. Atalho Command-2.
- Página: ícone de figura. Atalho Command-3.

O botão do modo atual tem um fundo discreto. Os três têm dica ao pousar o cursor.

A página usa uma coluna de leitura de cerca de 68 caracteres, com folga nas bordas. A aparência clara e a escura seguem as do Mac. Não há tema próprio.

Tipografia da interface e da página: a fonte sans do sistema. Código: a fonte monoespaçada do sistema. Cor só com função: link, foco do teclado e o fundo do modo selecionado. O acento é o acento do sistema.

Busca: Command-F procura na visão que está ativa. No modo lado a lado, procura nos dois. Sem painel permanente.

Ajustar o tamanho da letra fica para depois. O zoom do sistema cobre a 1.0.

### Virar o leitor padrão

O app declara os tipos de documento no `Info.plist`.

Na primeira abertura, uma faixa fina dentro da janela, não uma caixa modal: "Quer abrir os markdown neste visualizador?" com "Usar como padrão" e "Agora não". "Agora não" some com a faixa e ela não volta. "Usar como padrão" chama a API do sistema, que pode pedir confirmação.

O mesmo comando fica no menu Visualizar, "Usar como leitor padrão de Markdown", para quem dispensou a faixa.

### Idioma

Português quando o idioma do Mac for português. Inglês nos outros casos. As frases fixas são poucas: os três modos, a faixa do padrão, a busca, os dois erros de leitura.

O conteúdo do arquivo aparece como foi escrito.

## Chamadas fechadas depois do desenho

A janela mostrada em 2026-10-20 foi aceita: página ao abrir, lado a lado, texto, cores do sistema, faixa só na primeira abertura.

- macOS 14 ou mais novo. Identificador `app.markme.viewer`.
- Parser: `https://github.com/swiftlang/swift-cmark.git`, versão `0.9.0`, produtos `cmark-gfm` e `cmark-gfm-extensions`.
- Realce de código: highlight.js 11 embarcado no app, tema claro e escuro conforme o Mac. Sem download na hora de abrir.
- Busca literal, sem diferenciar maiúsculas.
- A caixa de uma lista de tarefas não muda ao clique.
- Sem App Sandbox na 1.0, para o Finder entregar qualquer pasta que a pessoa já pode ler, inclusive iCloud.
- O `.app` sai de `scripts/package-app.sh`, com assinatura ad hoc. Sem conta de desenvolvedor e sem notarização.

## O que fica com quem constrói

- Organização interna dos arquivos Swift, desde que os nomes públicos do plano se mantenham.
- Medidas finas da barra, dentro do que a Apple recomenda para janela de documento.
- O tom exato do realce de código, desde que o contraste funcione no claro e no escuro.

## Pronto quando

- Dois cliques num `.md` de verdade abrem a Página com título, lista, tarefa, citação, código colorido, link, imagem local, tabela e texto riscado.
- Os três botões e os atalhos Command-1, Command-2 e Command-3 trocam o modo. Lado a lado rola junto.
- Não existe caminho na interface que altere o arquivo.
- A faixa da primeira abertura e o item de menu disparam a confirmação do sistema para virar o leitor padrão.
- Um arquivo vazio, um arquivo que não é UTF-8 e um arquivo que some no disco não derrubam a janela.
- HTML cru no markdown não executa script.
