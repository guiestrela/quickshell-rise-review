# V2: orientação, estilos e painéis

Use esta referência ao modificar a apresentação lateral da Rise. Confirme os valores atuais no código; a V1 continua horizontal.

Os caminhos de implementação abaixo são relativos a `versions/V1/`.

## Onde alterar

- `variants/V2/Theme.qml`: posição persistida em `barPosition`, `barVertical`, largura derivada de `verticalBarWidth`, cores e preferências. O Frost altera `barBg`; fundos de painéis e tooltips usam `bg` para manter legibilidade. Preserve o campo de cache usado anteriormente pelo Notch Frost.
- `variants/V2/BarSlot.qml`: dono dos modelos de slots, ordem salva, controlador de ciclo de vida e janela por saída. A apresentação horizontal e `modules/VerticalBarContent.qml` reutilizam esses modelos; somente a apresentação ativa instancia os widgets. A largura, `exclusiveZone`, máscara e `VariantRoot.barSize` devem concordar.
- `VerticalBarContent.qml`: colunas separadas para Left/topo, Center/meio e Right/base. `Instantiator` cria os delegates nas colunas correspondentes; evite reparentear delegates de um Repeater entre pais diferentes. Colunas medem os widgets reais, incluindo workspaces de altura variável. Layouts que excedem a altura disponível rolam sem sobrepor regiões.
- `modules/SidePanelPositioner.qml`: aplica bindings de X/Y apenas na orientação lateral e restaura os bindings horizontais ao sair dela. Todo novo painel ligado à barra precisa dessa adaptação, incluindo componentes compartilhados com V1 que exponham um `surfaceHost`.
- `modules/AiPanelSurface.qml`: renderiza o fundo arredondado nas laterais e o contorno conectado no modo horizontal. Ocultar o componente inteiro para remover o conector também remove o fundo de cards transparentes.

## Contratos visuais e de interação

Full ocupa a altura disponível; Fit tem margem externa; Dock encosta na borda; Notch acrescenta curvas nas extremidades. As curvas do Notch precisam caber na máscara de entrada. Alterar a posição preserva o estilo selecionado.

O grupo G8 lateral usa clima somente com ícone e relógio compacto. Publique âncoras Y distintas para clima e calendário, conforme a posição real dos filhos. Respeite `clock12h` e `widgetContentColor` para que hora e clima sigam o contraste do grupo. Não acrescente temperatura ou outros elementos sem considerar a escolha do usuário.

Workspaces reutilizam `WorkspaceWidget.qml`: coluna nas laterais, linha em Top/Bottom; preservam os estilos e modos 5/10/ativos. O frame animado precisa seguir o eixo correto. Não sobrescreva configurações salvas de compactação para obter o modo lateral: derive a apresentação de `barVertical`.

Arraste captura origem e destino antes de alterar os modelos: a alteração pode destruir o delegate. Não acesse o delegate depois do swap. Preserve isolamento das âncoras e recuperação das janelas por saída.

## Evidência e testes

Execute os testes relevantes sem tocar em contas, monitores ou serviços reais:

```bash
python3 tests/test-vertical-bar-layout.py
python3 tests/test-vertical-workspaces.py
python3 tests/v2-default-layout-regression.py
node --test tests/bar-style-settings.test.mjs
python3 tests/test-bar-style-preview.py
```

O teste de layout usa o workspace e a superfície de painel reais, com widgets de serviço inertes. Valida sobreposição, redimensionamento, Full/Fit/Dock/Notch, âncoras e restauração horizontal. A amostragem do fundo renderizado usa `magick`. Os demais testes precisam de `qs`, Qt/QML e Node conforme o runner. Rejeite também `ERROR qml:`: um `Qt.quit()` posterior pode mascarar um `Qt.exit(1)` anterior.

Lint e fixtures offscreen não comprovam interação física, múltiplas saídas ou arraste real. Após aplicar à instalação, valide o plugin, confira `omarchy-shell shell ping` e o log próprio do PID. Relate separadamente o que foi testado e o que ainda exige conferência visual; não altere preferências do usuário só para obter evidência.
