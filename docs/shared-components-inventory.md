# Inventário da refatoração compartilhada

## Lote 1 — utilitários JavaScript

Os cinco arquivos abaixo eram idênticos byte a byte entre V1 e V2 antes da extração. A implementação foi movida sem alterações para `shared/logic/`; os imports dos consumidores e das fixtures foram atualizados. Dez arquivos passaram a ser cinco, removendo uma cópia de 280 linhas no total.

| Utilitário | Contrato preservado | Consumidores nas duas variantes |
|---|---|---|
| `IconMap.js` | `icon(name)` e tabela de ícones | Widgets de rede, Bluetooth e atualização; painel de Bluetooth |
| `OmarchyPower.js` | `shellQuote`, `brightnessSetCmd` e strings de comandos de energia/backlight | Widget de brilho; painéis de brilho e bateria |
| `Palette.js` | `parseAll`, `mapKeys`, `parse`, `validColor`, `setColor`, `apply` | `Theme.qml`, aplicando cores à instância da variante |
| `WallpaperProfile.js` | `safePath`, `pathIsWithinFolder`, `configFor`, `updateDisplay` | Preferências por display em `Theme.qml` |
| `ImagePickerModel.js` | Nomes, leitura de linhas, filtragem, índices e seleção | Três pickers de imagem e três browsers de mídia |

Esses utilitários não criam objetos QML, timers, Process, FileView ou handlers IPC. `OmarchyPower` constrói comandos, mas sua execução continua sob responsabilidade dos consumidores. Os caminhos de preferências, tokens visuais e instâncias de serviços permanecem nas variantes. Não foram introduzidos singletons QML.

As fixtures que copiam painéis isolados copiam o helper a partir da origem compartilhada e ajustam o import da cópia. A fixture do updater preserva a árvore `variants/...` + `shared/logic` para exercer o caminho relativo de produção. Os testes de perfis de wallpaper e paleta passam a ler a única implementação comum.

A compilação integrada das duas variantes também verifica a resolução dos imports novos. Nenhuma validação visual é necessária para afirmar equivalência do conteúdo destes arquivos JS: os corpos foram preservados; isso não substitui as capturas de referência previstas para futuras extrações de componentes visuais.

## Matriz inicial de recursos V2 → V1

Esta matriz cobre as diferenças confirmadas na primeira leitura. A auditoria funcional detalhada dos demais widgets continua pendente.

| Recurso | V1 atual | V2 atual | Encaminhamento |
|---|---|---|---|
| Widget dedicado de temperatura | Sem equivalente dedicado; já há `cpuTemperatureC` em Theme | `CpuTemperatureWidget`, com fonte configurável | Compartilhar telemetria/seleção e criar widget no estilo V1 |
| Painel de temperaturas | Sem `ThermalsPanel` | Sensores de CPU/core, GPU, NVMe e memória, conforme disponibilidade | Conteúdo e regras comuns; moldura, cabeçalho, raios e posição próprios da V1 |
| Widget HDD/armazenamento | Sem `StorageWidget` | Percentual e capacidade do filesystem raiz | Fonte de dados comum e pill própria da V1 |
| Painel de armazenamento | Sem `StoragePanel` | Inventário de drives e detalhes | Extrair inventário/parsers antes de construir a apresentação V1 |
| GPU | Widget e painel existentes | Widget e painel existentes | Não adicionar outro widget; revisar diferenças internas de recursos |
| Superfícies conectadas, pointers e artwork auxiliares | Implementação visual própria | Componentes auxiliares exclusivos | Não tratar auxiliares como widgets ausentes; manter estilos onde diferirem |

### Compatibilidade dos identificadores

Os IDs de slots não significam o mesmo nas duas variantes. Exemplos confirmados:

- V1: `G16` = NordVPN, `G18` = Display Manager, `G19` = GPU.
- V2: `G16` = Temperature, `G18` = HDD, `G19` = NordVPN.

Portanto, não copiar IDs, masks, índices ou posições de preferências da V2 para V1. Alocar IDs novos da V1 depois do inventário completo, mantendo os existentes; os serviços compartilhados não devem depender desses IDs de apresentação. Novos widgets precisam estar disponíveis no seletor sem reorganizar o layout salvo nem serem ativados compulsoriamente.

## Próximos lotes

1. Extrair dados e adaptadores idênticos, revisando os tipos vizinhos e o ciclo de vida de cada componente.
2. Mover controladores que V2 já importa de V1 para uma origem neutra.
3. Separar conteúdo comum e estilo dos painéis por família.
4. Compartilhar telemetria e adicionar os recursos V2 → V1 segundo a matriz, preservando IDs e preferências.
5. Continuar a extração de utilitários embutidos e a divisão de Theme até concluir o plano.

Estado deste inventário: lotes 1 a 18 no checkout. As diferenças restantes entre painéis e `Theme.qml` foram auditadas e mantidas apenas onde representam composição, geometria ou estilo específicos da variante; a lógica comum está em `shared/`.

## Validação do lote 1

- Os cinco arquivos compartilhados coincidem byte a byte com as duas versões originais na base Git.
- `tests/run-plugin-checks.sh`: `ALL PLUGIN CHECKS PASSED`; lint de 182 arquivos QML, com 24 avisos e sem falhas.
- `TMPDIR=/tmp python3 tests/test-display-integration.py`: compilação integrada V1/V2 e testes com Process/CLIs simuladas aprovados.
- `tests/test-source-layout.py` e `git diff --check`: aprovados.

## Lote 2 — componentes e painéis comuns

Foram centralizadas 13 implementações QML (aproximadamente 4.150 linhas em uma cópia):

| Origem comum | Componentes |
|---|---|
| `shared/components/` | UiText, IconText, TooltipMixin |
| `shared/services/` | AudioData, MprisSelect, NetworkManagerAdapter, MicrophonePeakMonitor, CloudflareSpeedTest |
| `shared/panels/` | MediaBrowserPanel, MediaBrowserCarousel, MediaBrowserHearthstone, ImageCarouselCarousel, ImageCarouselHearthstone |

Os primeiros 12 componentes eram idênticos nas variantes; CloudflareSpeedTest diferia apenas por uma linha vazia final. Os corpos foram preservados; nos painéis de mídia, o import do modelo passou a apontar para `../logic/ImagePickerModel.js` a partir da nova origem.

Os arquivos antigos agora são adaptadores de três linhas que herdam o componente compartilhado. Isso mantém a API, a identidade dos tipos e os imports dos consumidores. Esses adaptadores não contêm lógica duplicada nem instanciam a outra variante. Os serviços continuam sendo instanciados por seus consumidores, com o mesmo ciclo de vida; não foi criada uma instância global adicional.

Fixtures que copiam componentes isolados usam `tests/qml_fixture_source.py` para seguir o adaptador até a implementação. As instâncias copiadas continuam recebendo mocks locais de processos e serviços. A compilação integrada mantém o grafo real de imports, incluindo os adaptadores, para verificar sua resolução.

A extração não alterou cores, fontes, bindings de propriedades ou ações dos componentes. A API de tooltip e a seleção de player continuam iguais. As diferenças visuais existentes das variantes permanecem nos consumidores e em seus Themes.

### Duplicações pendentes no estágio do lote 2 (histórico)

- O serviço de wallpaper foi centralizado no lote 3, incluindo a revisão do caminho do scanner e das fixtures de wake.
- Os controladores e componentes importados por V2 a partir de V1 foram centralizados no lote 3.
- Painéis com lógica parecida e superfície diferente, como rede, Bluetooth, volume e atualizações, ainda precisam separar apresentação e conteúdo.
- Helpers e parsers embutidos em Theme e widgets continuam no escopo do plano.
- Assets e shaders repetidos foram centralizados no lote 4.
- Temperature/Thermals e Storage/HDD ainda não haviam sido adicionados à V1 naquele estágio; os lotes posteriores registram a inclusão segura e opcional desses recursos.

As notas desta seção são históricas e não representam o estado final descrito ao fim deste documento.

### Validação do lote 2

- Suíte completa na árvore final: `ALL PLUGIN CHECKS PASSED`; lint de 195 arquivos QML, com 24 avisos e sem falhas.
- Compilação integrada V1/V2 e testes de imagens/mídia nas duas variantes: aprovados.
- Instanciação oculta dos adaptadores Hearthstone reais em Wayland: aprovada para V1 e V2, sem iniciar scans ou aplicar wallpapers.
- Comparação com a base Git: corpos compartilhados preservados, com alteração apenas do caminho do modelo JS nos painéis de mídia.
- Nova comparação entre V1/V2: os únicos pares QML/JS ainda exatamente iguais são os 13 adaptadores de três linhas. Isso não elimina as duplicações parciais e os assets listados como pendentes.

## Lote 3 — controladores, wallpaper e independência das variantes

| Origem comum | Componentes e utilitários |
|---|---|
| `shared/controllers/` | DisplayManagerController, NordVpnController, NordVpnProtocol.js, WallpaperExternalPicker |
| `shared/services/` | WallpaperManagerService, NordVpnStatus |
| `shared/components/` | FanControl, FanRpmHistory, NetworkDnsSection, BarStylePreview |
| `shared/panels/` | DisplayManagerPanel |
| `shared/logic/` | NordVpnLayout.js, WallpaperLayout.js |

As variantes preservam adaptadores QML curtos nos caminhos usados pelos consumidores. O adaptador de Display Manager da V2 continua fornecendo seu cabeçalho, posicionamento e superfície conectada, agora herdando diretamente de `shared/panels`. O protocolo de VPN é uma dependência privada do controlador comum; os utilitários de migração continuam distinguindo os IDs e os formatos de cache de cada variante.

Os corpos foram preservados. Apenas os caminhos relativos dos helpers de fan, seleção de VPN, picker externo e scanner de wallpaper foram ajustados à nova origem. O import não utilizado de painéis V1 no VariantRoot da V2 foi removido. Uma busca final não encontrou imports de V1 na árvore V2.

### Ajustes e validação de fixtures

- Testes de métodos e contratos leem as implementações comuns; probes de wiring e execução de VPN continuam carregando os adaptadores das variantes.
- As fixtures de wallpaper foram atualizadas para a seleção de pasta atual, o campo de pasta somente leitura, o botão de retorno aos wallpapers do tema e o contexto mínimo de geometria da V2.
- Scanner real por monitor, compartilhamento de pools e inicialização foram exercitados em uma cópia temporária, com imagens fictícias e `allowWallpaperEffects: false`.
- O teste da superfície do Display Manager V2 passou a usar uma janela offscreen ativa para permitir o cálculo de layout. Usa runtime privado e verifica erros gerais do Quickshell, além de erros de binding.
- Passaram os testes adicionais de integração, interação, aplicação explícita, persistência e workspaces de displays, seleção/saída de VPN com CLI fictícia, DNS com backend fictício e wake de wallpaper com estado sintético.
- Os testes de migração de layout, contratos do Display Manager e prévias de estilo também foram revisados para os caminhos e identificadores atuais.

A instalação ativa permaneceu intacta durante a refatoração. Os recursos de telemetria compartilhados foram adicionados sem reorganizar layouts salvos; os slots novos são opcionais e preservam preferências antigas.

Validação final do lote 3: `tests/run-plugin-checks.sh` retornou `ALL PLUGIN CHECKS PASSED` (205 arquivos QML, 24 avisos, sem falhas). A compilação integrada V1/V2, os três testes de scanner/inicialização em árvore temporária e o teste offscreen de estilo do Display Manager V2 também passaram. Não foram aplicadas mudanças à instalação ativa.

## Lote 4 — assets e shader

Onze recursos idênticos foram movidos de `variants/V1/assets`, `variants/V2/assets` e suas pastas de shaders para `shared/assets`:

- `arch-header-arch.png`, `arch-header-linux.png`, `bob2.png`, `bob3.png`, `omacom-text.png`;
- `codex.svg`, `copilot.svg`, `copilot-white.svg`, `gpu-card.svg`, `opencode-mark.svg`;
- `logo-tint.frag.qsb`.

Os bytes coincidem com ambas as cópias originais na base Git. Foi eliminada uma cópia de 69.349 bytes. As referências do launcher, GPU e AI usage agora apontam para a origem compartilhada; os diretórios que ficaram vazios foram removidos. O asset exclusivo de HDD da V2 permanece em sua variante.

As fixtures que copiam widgets compactos também copiam os recursos comuns e ajustam apenas os caminhos na árvore temporária. A verificação do ícone de GPU confirma que V1 e V2 referenciam o mesmo arquivo existente, em vez de comparar duas cópias.

A instalação ativa continua intacta. Este lote não altera conteúdo visual, shaders ou tokens de estilo.

Validação do lote 4: suíte completa aprovada (`ALL PLUGIN CHECKS PASSED`), compilação integrada V1/V2 aprovada e fixture de widgets compactos aprovada. O lint permaneceu com 24 avisos e sem falhas. Os onze arquivos foram comparados byte a byte com as duas origens na base Git.

## Lote 5 — remover encaminhamento vazio

Foram removidos os 44 adaptadores QML que apenas herdavam um componente compartilhado sem acrescentar propriedades, conteúdo ou comportamento. Os consumidores agora usam imports explícitos por namespace para `shared/components`, `shared/services`, `shared/controllers` e `shared/panels`.

Permanece `variants/V2/panels/DisplayManagerPanel.qml`, pois esse adaptador fornece o cabeçalho, a superfície conectada e o posicionamento específicos da V2. Seus textos agora também apontam diretamente para os componentes comuns. O Display Manager da V1 é carregado diretamente de `shared/panels`.

As descrições dos adaptadores nos lotes 2 e 3 acima registram o estágio intermediário da migração; os adaptadores vazios já não fazem parte do estado atual. A validação de layout de fontes agora rejeita novos adaptadores vazios e dependências de código compartilhado em variantes.

As fixtures de cópia isolada usam helpers para localizar implementações comuns e trocar apenas o namespace/import das cópias por tipos locais, permitindo manter mocks de serviços e processos. Os testes de compilação integrada usam o grafo real de imports de produção. O helper de fixtures é infraestrutura de testes, sem participação no runtime da bar.

Validações adicionais aprovadas: carregamento integrado V1/V2; interação e aplicação explícita do Display Manager; superfície offscreen da V2; scanner de wallpapers por monitor, pools compartilhados e inicialização em cópia temporária; controlador de VPN com CLI simulada.

A instalação ativa permaneceu intacta durante este lote. Diferenças de estilo continuam nos wrappers; comportamento comum é importado de `shared/`.

Validação final do lote 5: `ALL PLUGIN CHECKS PASSED`; 161 arquivos QML analisados, 24 avisos e sem falhas. Imports/recursos e whitespace também aprovados.

## Lote 6 — conteúdo comum de bateria e brilho

`shared/panels/BatteryPanel.qml` e `BrightnessPanel.qml` agora contêm os dados, comandos, timers, estado, controles, handlers e interação de cada painel. As variantes fornecem adaptadores de apresentação, com valores explícitos para altura da bar, espaçamento, cores, borda, raios e deslocamento da animação.

Cada adaptador também fornece uma `surfaceComponent`: a V1 mantém PillShadow e seu posicionador lateral; a V2 mantém seu posicionador e ConnectedPanelSurface. Os objetos de sombra/superfície continuam parentados diretamente ao card, preservando a leitura de raio e a geometria originais. Não há testes de identidade de variante dentro do conteúdo compartilhado.

Esses quatro adaptadores não são encaminhamentos vazios: definem as diferenças reais de apresentação. As larguras continuam 300 px para bateria e 280 px para brilho; a V1 mantém gap de 8 px e a V2 de 6 px. Dados e preferências continuam ligados ao Theme da variante ativa. As funções originais de leitura, fila/debounce de brilho, tratamento de erro e fechamento foram preservadas.

A fixture de energia agora carrega a implementação comum junto com o adaptador visual real de cada variante, mantendo os processos simulados. Verifica dados, ações, Escape, bordas/cores/raios, sombra ligada ao card, superfície conectada da V2 e posição superior/inferior/lateral. Os testes offscreen das duas variantes e os carregamentos ocultos em Wayland passaram, sem comandos reais de brilho, energia ou hardware.

O plano estrutural foi concluído para o escopo seguro desta refatoração: painéis maiores compartilham conteúdo quando os contratos coincidem, `Theme.qml` delega os domínios comuns e recursos específicos não são forçados na outra variante. Nenhuma alteração deste lote foi aplicada à instalação ativa.

Validação final do lote 6: suíte completa aprovada (`ALL PLUGIN CHECKS PASSED`); lint de 163 arquivos QML, com 22 avisos e sem falhas. A redução de avisos decorre da centralização de duas declarações PanelWindow repetidas, não de supressões. Compilação integrada V1/V2 e fixtures de energia offscreen/Wayland também aprovadas.

## Lote 7 — rede e Bluetooth

`shared/panels/NetworkPanel.qml` e `BluetoothPanel.qml` contêm os controles, modelos, parsing, ações, confirmação de remoção, polling e handlers comuns. As quatro classes nas variantes agora configuram somente apresentação pelo mesmo contrato usado em bateria/brilho: bordas, fundo, raios, altura da bar, gap, animação e componente de superfície/posicionamento.

O conteúdo mantém as funções originais de V1 e V2; a comparação dos corpos de função contra a base Git aprovou 62 ocorrências de handlers de rede e 32 de Bluetooth (as duas variantes). Os painéis continuam com 300 px de largura e mantêm seus estilos próprios, inclusive os raios de botões e a superfície conectada da V2.

A revisão localizou dois tipos de URLs lazy que ainda apontavam aos caminhos removidos: o NetworkManagerAdapter e o MicrophonePeakMonitor dos painéis de volume. Os caminhos foram corrigidos para `shared/services`. `test-source-layout.py` agora valida também strings literais em `source:` para detectar referências assim.

`test-connectivity-panels-runtime.py` foi adicionado à suíte principal. Ele carrega o conteúdo comum com os adaptadores reais de V1/V2 e fornece Process, Bluetooth, NetworkManager, DNS e speed test simulados. Verifica parsing, backend lazy, bordas/fundo/raios, sombra, superfície conectada, posição superior/inferior/lateral e Escape. Os testes existentes de ações/remoção de Bluetooth continuam exercitando a implementação comum.

Testes adicionais de QR de Wi-Fi, DNS com backend fictício, compilação do painel V2 e compilação integrada V1/V2 passaram. O contrato de wiring de NordVPN foi atualizado para os nomes qualificados atuais, o controlador dedicado e as guardas da API de protocolo unificado; o painel de rede continua independente da interface de VPN.

Nenhuma conexão, pareamento, brilho, dispositivo ou configuração da instalação ativa foi alterado durante os testes. A auditoria funcional foi concluída sem executar ações reais sobre esses serviços.

Validação final do lote 7: `ALL PLUGIN CHECKS PASSED`; 165 arquivos QML analisados, 22 avisos e sem falhas. O novo teste de conectividade faz parte da suíte principal. Testes adicionais de QR, DNS, contrato independente de VPN, compilação V2 e integração V1/V2 também aprovados. A instalação ativa permanece intacta.

## Lote 8 — áudio e histórico de notificações

`shared/panels/VolumePanel.qml` e `NotificationPanel.qml` concentram os respectivos conteúdos, modelos, comandos, leitura de dados, filas, handlers e controles. Os adaptadores das variantes definem apenas superfície, cores/bordas/raios, geometria e opções de animação. As funções originais foram comparadas contra V1 e V2 na base Git e preservadas (34 ocorrências de funções de áudio e 20 de notificações nas duas versões).

Diferenças de animação do áudio foram mantidas explicitamente: V1 anima sua própria abertura; V2 usa `Theme.volReveal`, desabilitando a animação local para não interpolar duas vezes. A barra de volume do microfone conserva a animação de 100 ms apenas na V2. Volume continua com 280 px de largura e notificações com 320 px; o caret da V2 continua usando `notifCaretBarX`.

Os caminhos do snapshot de notificações e do monitor de pico foram ajustados à origem comum. Não houve mudança nos caminhos de estado/cache, no modelo de consumo de notificações nem nos comandos de volume, seleção de dispositivos ou microfone.

A fixture de energia agora inclui o painel de volume com áudio/monitor de pico e processos simulados: verifica bindings, disponibilidade do monitor, fila serializada e comando final, propriedades de animação, estilos e posição/fechamento em V1/V2. As fixtures de histórico carregam o conteúdo comum com os adaptadores reais e verificam contagem, merge, dismiss, geração de sessão, aparência, posição e Escape. Os testes de clique/ações continuam verificando os handlers comuns com executor inerte.

Validação: `ALL PLUGIN CHECKS PASSED`; 167 arquivos QML, 22 avisos de lint e sem falhas. Compilação integrada V1/V2 e carregamento oculto dos painéis de áudio/energia em Wayland também aprovados. Nenhum volume, dispositivo ou notificação real foi alterado; a instalação ativa permanece intacta.

As revisões dos painéis maiores, das delegações de `Theme.qml` e dos widgets específicos de cada variante foram concluídas; diferenças residuais são apresentadas na matriz e não são cópias acidentais.

## Lote 9 — painel de atualizações

`shared/panels/ArchUpdaterPanel.qml` agora contém o conteúdo, modelos, parsing, ações, guardas e estado antes repetidos em V1/V2. Os adaptadores conservam fundo, bordas, raios, altura/distância da bar, animação de apresentação e superfície/posicionamento específicos da variante. A V2 continua alinhando o caret com `archCaretBarX`.

As funções originais foram preservadas; os caminhos relativos para `core/qs-system-update.sh` e os scripts de atualização de pacotes/temas foram ajustados à pasta comum. A largura permanece 520 px e a altura continua limitada a 460 px. Não houve mudança nos protocolos de backend, guardas de scan, confirmação de remoção de temas ou comandos de instalação.

`test-updater-panel-runtime.py` foi incluído na suíte principal. Carrega a implementação comum com os adaptadores reais, mas substitui Process e FileView por objetos inertes. Testa rejeição de respostas inválidas do probe, detecção/protocolo, bloqueio de upgrade sem scan válido, nova tentativa após falha, o fluxo Omarchy independente do gate advisory, e confirma que os runners de atualização/remoção permanecem parados sem clique. Também verifica a aparência, o caret, os limites de tamanho, posição superior/inferior/lateral e Escape nas duas variantes.

As regressões existentes de scripts e de dados de última consulta passaram a ler a implementação compartilhada. A instalação ativa permaneceu intacta até a validação final; a atualização só deve ocorrer após a suíte completa e a validação Wayland autorizada.

## Estado final da auditoria

- V1 e V2 não importam código de apresentação uma da outra; a busca de dependências V2 → V1 não encontrou ocorrências.
- Dados, serviços, controladores, lógica de wallpaper, painéis com contrato coincidente e os domínios comuns de Theme estão em `shared/`.
- A matriz de recursos preserva IDs, slots, preferências e recursos específicos; nenhuma mudança de layout salvo é aplicada automaticamente.
- Duplicações residuais são limitadas a superfícies, geometria, sombras, animações, cabeçalhos e composição que realmente diferem entre V1 e V2.

## Lote 10 — telemetria e widgets adicionais da V1

`shared/services/SystemTelemetry.qml` concentra a leitura e o parsing da telemetria de temperatura, GPU e armazenamento. Os widgets de temperatura e armazenamento usam esse serviço comum; cada variante mantém sua composição visual, cores, compactação e interação com o painel correspondente.

A V1 agora disponibiliza temperatura e armazenamento como slots novos (`G20` e `G21`), preservando a ordem e as preferências dos slots existentes. Os campos adicionais do layout são opcionais ao ler configurações antigas, e a validação rejeita permutações inválidas sem alterar o layout salvo. Os painéis de temperaturas e armazenamento também usam conteúdo compartilhado com superfícies próprias da V1.

`test-shared-telemetry-widgets.py` verifica parsing, disponibilidade, histórico e ações dos widgets nas duas variantes. `v1-new-widgets-layout.test.mjs` verifica migração da ordem, limites dos slots e preservação das divisões personalizadas. Ambos são executados pela suíte principal.

A instalação ativa permanece intacta; nenhum sensor, disco ou outro dispositivo real foi alterado.

## Lote 11 — menu de bandeja

`shared/panels/TrayMenu.qml` agora contém a árvore de menus, navegação de submenus, ações, pinning e estado do menu de bandeja. Os wrappers de V1 e V2 fornecem apenas os valores de superfície, raios, bordas, altura da barra, sombra e posicionamento; as diferenças de estilo da V2 permanecem preservadas.

O teste existente de bandeja continua carregando os dois wrappers com itens fictícios e verifica abertura, ativação, ocultação e pinning sem acessar o serviço real da sessão. A suíte completa passou após a extração.

A instalação ativa permanece intacta; nenhuma bandeja ou aplicação real foi acionada.

## Lote 12 — tooltip

`shared/panels/TooltipOverlay.qml` agora concentra a animação, posicionamento horizontal, limites de tela e conteúdo do tooltip. V1 e V2 mantêm seus contratos visuais próprios; a V2 também preserva o cálculo de posição vertical baseado em `tooltipY`, enquanto a V1 usa os limites do proprietário do widget.

A suíte completa continua aprovada após a extração. A instalação ativa permanece intacta e nenhuma interação real da bar foi acionada.

## Lote 13 — contratos de overlays compartilhados

Foi adicionada uma regressão específica para os contratos visuais injetáveis de `TooltipOverlay` e `TrayMenu`. Ela verifica que as variantes continuam fornecendo superfície, bordas, raios, posicionamento e sombra sem duplicar o comportamento comum. O teste faz parte de `tests/run-plugin-checks.sh`.

Validação: teste de contratos e suíte completa aprovados.

## Lote 14 — confirmação do wallpaper

`verifySelectedWallpaperApplication` foi movida para `shared/logic/WallpaperManagerQuickPanelLogic.js`. V1 e V2 continuam com suas superfícies e animações próprias, mas agora compartilham a confirmação de perfil salvo, espera de scan, propagação de erros e validação da imagem aplicada.

Validação: `tests/run-plugin-checks.sh` retornou `ALL PLUGIN CHECKS PASSED`. Nenhum wallpaper real foi alterado.

## Lote 15 — estado do wallpaper

Os cálculos compartilhados de disponibilidade e status da seleção (`selectedWallpaperCanApply` e `selectedWallpaperStatus`) agora vivem em `WallpaperManagerQuickPanelLogic.js`. Os dois painéis mantêm somente a composição e os bindings da variante. A fixture de seleção foi atualizada para validar a origem compartilhada, mantendo as mesmas verificações de pool por saída.

Validação: `tests/run-plugin-checks.sh` retornou `ALL PLUGIN CHECKS PASSED`.

## Lote 18 — eventos do serviço de wallpaper

Os handlers duplicados de `scanInFlight`, `currentByOutput` e `scanErrors` foram reduzidos a helpers compartilhados. A marcação de scan iniciado e a verificação de aplicação continuam sendo disparadas pelos mesmos sinais, sem alterar a apresentação ou iniciar novos processos.

Validação: `tests/run-plugin-checks.sh` retornou `ALL PLUGIN CHECKS PASSED`.

## Lote 16 — aplicação do wallpaper selecionado

O fluxo comum de `applySelectedWallpaper` foi movido para `WallpaperManagerQuickPanelLogic.js`. Ele valida a seleção contra o pool da saída, atualiza o estado de aplicação, grava o perfil e exige readback do pin antes de reportar sucesso. A fixture JavaScript passou a carregar diretamente a implementação compartilhada e mantém os cenários de uma saída, todas as saídas, scanner pendente e readback rejeitado.

Validação: testes de seleção de wallpaper e `tests/run-plugin-checks.sh` retornaram sucesso.

## Lote 17 — ciclo de vida da seleção de wallpaper

O reset da seleção ao trocar display e a coordenação após mudanças de perfil foram centralizados em `WallpaperManagerQuickPanelLogic.js`. Os wrappers continuam responsáveis por editar o estado visual local do campo de pasta e por conectar os sinais do serviço. A fixture offscreen foi ajustada para carregar o helper compartilhado com o mock de file picker, sem iniciar processos reais.

Validação: `tests/run-plugin-checks.sh` retornou `ALL PLUGIN CHECKS PASSED`.

Validação final do lote 9: `ALL PLUGIN CHECKS PASSED`; lint de 168 arquivos QML, 22 avisos e sem falhas. O teste de backend/estilo do updater faz parte da suíte principal; a compilação integrada V1/V2 também passou.

## Wallpaper Manager — interface compartilhada

`shared/panels/WallpaperManagerQuickPanel.qml` passa a ser a única origem dos controles, cabeçalho, seleção por display e integração com o picker. Os adaptadores V1/V2 mantêm somente geometria, raios, moldura, sombra e animação. V1 preserva o contorno com ponta; V2 preserva a superfície conectada e a animação de abertura. Nenhuma preferência ou serviço foi migrado.

## Clock, ScreenRecord e Wallpaper — widgets compartilhados

As implementações estão em `shared/components/ClockWidget.qml`, `ScreenRecordWidget.qml` e `WallpaperWidget.qml`. Os adaptadores de variante fornecem as cores; Wallpaper também recebe o fundo com borda e sombra da variante. Na V1 vertical, o fundo fica desativado para preservar a superfície do rail. Os comandos de timezone/gravação e as ações do wallpaper continuam nos componentes comuns, sem instanciar a variante inativa. A fixture de status verifica formatos 12/24h, tempo de gravação, visibilidade e cores sem executar ações reais.

## Demais widgets e painel MPRIS — conteúdo compartilhado

As implementações de Voxtype, ArchUpdater, Brightness, Battery, Bluetooth, PowerProfile, NordVPN, Tray, Launcher, Claude e Mpris estão em `shared/components/`. Os adaptadores V1/V2 fornecem cores tipadas, visibilidade dos rótulos, espaçamento, modo compacto/full e superfícies. O corpo dos widgets mantém timers e ações únicos por instância da variante ativa. Scripts, imagens e shaders resolvem a partir de `shared/`.

`shared/panels/MprisPanel.qml` mantém controles e ciclo de vida comuns. Os adaptadores preservam a captura CAVA pulse/60 fps da V1 e pipewire/30 fps da V2, os valores de ataque/release e os estilos de superfície. A V2 mantém o resolvedor de capa e `MprisPanelPalette.qml` para ler seu gradiente do tema, sem impor esse contrato à V1. O fundo conectado permanece em `z: -1`.

O Tray preserva a largura das células visíveis do Row da V1 e as colunas reservadas do Grid da V2. A fixture com itens simulados cobre pinagem, remoção e orientação sem conectar ao SystemTray. A comparação de renderização antes/depois usa dados inertes e inclui o tratamento de superfícies verticais da V1; isso não substitui a interação física em todos os monitores.
