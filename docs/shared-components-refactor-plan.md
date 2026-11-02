# Plano de compartilhamento entre V1 e V2

## Objetivo e conclusão

É viável retirar boa parte da duplicação entre as variantes. O projeto é um plugin Omarchy com duas interfaces; os widgets, controladores e painéis internos podem compartilhar implementação sem se tornarem plugins separados.

O escopo inclui centralizar todos os utilitários e levar à V1 os widgets e funcionalidades adicionais da V2, adaptados ao estilo da V1. O levantamento deve verificar diferenças funcionais, não apenas arquivos com nomes exclusivos.

A proposta é colocar comportamento comum em `shared/` e manter em cada variante a composição da bar, as superfícies, o posicionamento e os estilos que realmente diferem. Componentes visuais idênticos também podem ser compartilhados. Não é necessário duplicar um painel inteiro apenas para mudar borda, raio ou fundo.

A execução já centralizou utilitários, componentes idênticos e controladores anteriormente reutilizados a partir de V1; veja o [inventário e progresso](shared-components-inventory.md). As etapas restantes continuam planejadas, e esses lotes ainda não alteram a instalação ativa. A redução do Display Manager para 420 px e os ajustes dos testes continuam sendo mudanças independentes.

## Inventário inicial

Comparação dos arquivos de mesmo caminho relativo em `variants/V1` e `variants/V2`, em 2026-11-02:

| Resultado | Quantidade | Interpretação |
|---|---:|---|
| Pares de arquivos QML/JS | 87 | A comparação não inclui componentes exclusivos de uma variante |
| QML/JS idênticos byte a byte | 17 | Aproximadamente 4.075 linhas em uma cópia redundante |
| Adaptadores de V2 que importam V1 | 8 | Reutilização existente; mover a implementação para uma pasta neutra |
| Outros pares QML/JS diferentes | 62 | Exigem revisão funcional; semelhança não prova equivalência |
| Assets/shaders idênticos | 11 | Candidatos a uma única origem com atualização dos caminhos |

As 4.075 linhas são uma medida de duplicação textual, não uma promessa de economia final: imports, contratos e adaptadores podem acrescentar código.

### Código exatamente igual

- Utilitários: `IconMap.js`, `OmarchyPower.js`, `Palette.js`, `WallpaperProfile.js`, `ImagePickerModel.js`.
- Dados e adaptadores: `AudioData.qml`, `MprisSelect.qml`, `NetworkManagerAdapter.qml`, `MicrophonePeakMonitor.qml`.
- Primitivos visuais: `IconText.qml`, `UiText.qml`, `TooltipMixin.qml`.
- Navegação de imagens e mídia: `ImageCarouselCarousel.qml`, `ImageCarouselHearthstone.qml`, `MediaBrowserCarousel.qml`, `MediaBrowserHearthstone.qml`, `MediaBrowserPanel.qml`.

Mesmo arquivos iguais podem depender de tipos vizinhos e de propriedades de `root`. Essas dependências precisam acompanhar a extração.

### Reutilização já existente

V2 importa implementações de V1 para `DisplayManagerController`, `FanControl`, `FanRpmHistory`, `NetworkDnsSection`, `NordVpnController`, `NordVpnStatus`, `WallpaperExternalPicker` e `DisplayManagerPanel`.

O Display Manager é um exemplo útil: controles compartilhados com cabeçalho, posicionamento e superfície próprios de V2. A implementação comum deve deixar de morar dentro de V1.

### Diferenças mínimas e candidatos grandes

- `CloudflareSpeedTest.qml`: a diferença observada é uma linha vazia final.
- `WallpaperManagerService.qml`: a diferença observada é um comentário.
- `NetworkPanel.qml`: aproximadamente 98,5% de similaridade por linhas; as diferenças examinadas incluem superfície conectada, posicionamento, animação e raios de botões.
- `BluetoothPanel.qml`, `ArchUpdaterPanel.qml`, `VolumePanel.qml` e `NotificationPanel.qml`: forte semelhança textual; revisar todos os handlers e bindings antes de compartilhar.
- `Theme.qml`: mistura estado, persistência, serviços e apresentação. Precisa ser dividido por responsabilidade em etapas.
- `BarSlot.qml`, `ControlPanel.qml`, `WorkspaceWidget.qml` e os widgets de CPU/GPU têm diferenças maiores. Manter a composição por variante inicialmente e extrair somente dados/ações comprovadamente comuns.
- Storage/HDD e Temperature/Thermals são candidatos iniciais à inclusão na V1, com lógica compartilhada e apresentação própria. Os componentes de superfícies conectadas continuam específicos da V2; não devem ser copiados para a V1.

## Estrutura proposta

```text
core/                         # Ciclo de vida, seleção e IPC existentes
shared/
  logic/                      # Funções JS, mapeamentos e regras comuns
  services/                   # Fontes de dados e adaptadores de sistema
  controllers/                # Ações, validação, drafts e confirmação
  components/                 # Primitivos visuais realmente comuns
  panels/                     # Conteúdo e comportamento comum dos painéis
  assets/                     # Imagens e shaders idênticos
  integrations/               # Helpers externos já compartilhados
variants/
  V1/                         # Theme, composição, estilos e adaptadores V1
  V2/                         # Theme, composição, estilos e adaptadores V2
```

Os nomes exatos de subpastas devem acompanhar as dependências encontradas. Evitar renomear arquivos sem necessidade na mesma etapa em que se altera comportamento.

## Contrato entre comportamento e apresentação

1. Controladores expõem estado e ações, sem consultar cores, dimensões ou nomes de variantes. Separar dependências hoje passadas pelo objeto `theme` quando a extração justificar isso.
2. Conteúdo compartilhado recebe explicitamente o controlador, os dados e um contrato visual pequeno: cores, fonte, raios, espaçamento e geometria necessária.
3. V1 e V2 fornecem componentes de superfície/cabeçalho e posicionamento por composição (`Component`, propriedades e sinais), seguindo a experiência do Display Manager.
4. Diferenças de layout reais permanecem nas variantes. Evitar espalhar verificações `variant === "v2"` pelo código compartilhado ou criar um único objeto de estilo com toda a API de `Theme.qml`.
5. Compartilhar o código não implica criar um singleton global. Continuar instanciando apenas os serviços/controladores necessários à variante ativa, sem duplicar timers, Process, watchers ou handlers IPC.
6. Preferências, layouts e caches específicos de V1/V2 mantêm seus caminhos e semântica. Nenhuma migração de dados deve ser necessária apenas para mover código.

## Execução em etapas

### 1. Fixar os contratos e a referência visual

- Registrar API, consumidores, tipos locais, imports JS, assets, helpers e efeitos iniciados no carregamento de cada candidato.
- Capturar painéis equivalentes em V1/V2, incluindo barras horizontais/laterais, estados vazios e erro.
- Usar a árvore atual como referência, incluindo a largura de 420 px do Display Manager.

Entrega: inventário revisado e checklist por componente, antes de qualquer movimentação.

### 2. Centralizar todos os utilitários e extrair código idêntico

- Inventariar e centralizar todos os utilitários: funções JS, parsers, validações, mapeamentos e helpers hoje embutidos em widgets, painéis ou Theme. Consolidar implementações equivalentes; quando houver uma regra realmente específica de estilo, manter essa decisão na variante e compartilhar o mecanismo comum.
- Começar por JS e componentes sem efeitos externos; seguir com dados/adaptadores e famílias de mídia.
- Mover famílias dependentes em conjunto, preservando os imports locais.
- Consolidar `CloudflareSpeedTest` e `WallpaperManagerService` após confirmar a equivalência semântica.
- Centralizar assets em etapa própria, atualizando cada referência.

Entrega: uma implementação comum por candidato, com imports explícitos em ambas as variantes.

### 3. Remover a dependência de V2 sobre V1

- Mover os controladores já reutilizados para `shared/controllers` ou `shared/services`.
- Extrair o conteúdo do Display Manager para `shared/panels`; preservar os adaptadores visuais de V1/V2.
- Fazer o mesmo para DNS e o picker externo, mantendo a apresentação que já possuem.
- Adaptadores temporários nos caminhos antigos só quando necessários para compatibilidade; registrar consumidores e critério de remoção.

Entrega: componentes comuns deixam de ter V1 como proprietária implícita.

### 4. Compartilhar painéis por família

- Migrar um painel pequeno primeiro, como Brightness ou Battery, para validar o contrato visual.
- Depois avançar para Bluetooth, áudio, notificações, rede e atualizações, em mudanças separadas e revisáveis.
- Extrair regras e ações antes da apresentação quando as diferenças forem funcionais.
- Manter cabeçalhos, superfícies conectadas, animações e posicionamento na camada visual apropriada.

Entrega: cada correção de comportamento comum passa a ter um único ponto de implementação.

### 5. Levar os widgets adicionais da V2 para a V1

- Comparar o catálogo de widgets, opções do Control Panel, ações e painéis das duas variantes. Produzir uma matriz por recurso: disponível em V1/V2, diferenças de comportamento, dados necessários e adaptação visual prevista.
- Começar pelos recursos exclusivos já identificados: `CpuTemperatureWidget.qml` com `ThermalsPanel.qml`, e `StorageWidget.qml` com `StoragePanel.qml` (HDD). Verificar também funcionalidades adicionais dentro de widgets com o mesmo nome; a lista inicial não limita o levantamento.
- Distinguir widgets oferecidos ao usuário de componentes auxiliares, como artwork e superfícies conectadas. Reutilizar auxiliares onde fizer sentido, sem tratá-los automaticamente como novos widgets.
- Extrair primeiro os coletores, parsers, estado e ações para `shared/`. V1 e V2 devem consumir a mesma implementação, sem copiar a lógica da V2 para arquivos novos da V1.
- Criar a apresentação da V1 usando suas pills, cores, fontes, bordas, raios, espaçamentos, cabeçalhos, posicionamento e animações. Preservar a apresentação existente da V2.
- Integrar os novos widgets ao seletor de widgets, visibilidade, modos compacto/ícone quando suportados, ordenação, slots e orientações horizontal/lateral da V1.
- Adicionar preferências da V1 com valores padrão seguros, preservando IDs, ordem e opções já salvas. A disponibilidade dos novos widgets não deve reorganizar ou ativar compulsoriamente itens no layout existente.
- Compartilhar os dados apenas dentro do ciclo de vida correto: não iniciar dois coletores para a mesma função e não carregar a variante inativa.

Entrega: os widgets e recursos adicionais identificados na V2 ficam disponíveis na V1 com comportamento equivalente e aparência coerente com V1; a matriz registra a cobertura e a justificativa de diferenças que forem exclusivamente visuais.

### 6. Dividir Theme sem unificar os layouts

- Extrair por domínio: leitura de dados, integração, preferências e coordenação de painéis.
- Manter tokens visuais, composição da bar, seleção de shells e preferências próprias nas variantes.
- Só avaliar uma base comum de `VariantRoot` depois das etapas anteriores, preservando scanner QML, ciclo de vida e tratamento de monitores.

Entrega: `Theme.qml` passa gradualmente a compor serviços e estilo, reduzindo a mistura de responsabilidades.

## Validação e cuidados de implementação

- Atualizar imports explícitos usados pelo scanner virtual do Quickshell; mover um arquivo sem registrar sua árvore pode quebrar o carregamento lazy.
- Revisar todos os `Qt.resolvedUrl`, imports relativos, helpers, imagens e shaders: o diretório de origem muda a resolução.
- Atualizar fixtures que copiam arquivos para árvores temporárias, asserções de caminhos e validação de instalação/update. Os testes também fazem parte da migração.
- Executar `tests/run-plugin-checks.sh` e os testes pertinentes a cada família. Para Display Manager: integração, interação e aplicação explícita com controladores simulados.
- Cobrir V1/V2, troca entre variantes, ausência de trabalho da variante inativa, fechamento/reabertura de painéis e confirmação/rollback onde existirem.
- Para widgets trazidos da V2 à V1, validar dados ausentes, estados de erro, ações, visibilidade, ordenação, persistência e modos horizontal/lateral; comparar capturas com o estilo da V1 e confirmar que V2 não mudou visualmente.
- Comparar imagens em Wayland para as superfícies afetadas, mantendo geometria, cores, foco, tooltip e comportamento lateral. Testes offscreen não comprovam a renderização layer-shell.
- Não usar contas reais, alterar monitores/conexões ou controlar fans para testar uma extração de código.
- Aplicar à instalação somente lotes validados, com backup e preservação de diferenças locais. Não misturar refatoração com redesign ou mudança de configuração.

## Critérios de conclusão

- Todos os utilitários têm uma origem central em `shared/`, com diferenças legítimas de apresentação delegadas às variantes.
- Candidatos migrados têm uma única implementação de comportamento comum.
- A matriz V1/V2 está concluída e os widgets adicionais identificados na V2 estão disponíveis na V1, adaptados ao seu estilo e sem duplicação de lógica.
- Não há dependência de componentes comuns em `variants/V1` ou `variants/V2`.
- Variantes preservam suas diferenças de aparência e comportamento intencionais.
- Preferências existentes continuam funcionando sem reset.
- A seleção continua instanciando somente uma variante, sem duplicar serviços, timers ou IPC.
- Testes pertinentes e suíte completa aprovados; diferenças visuais explicadas e verificadas.

Recomendação: executar primeiro as etapas 1–3 como um lote de fundação. Migrar os painéis maiores separadamente, incluir os widgets adicionais na V1 sobre a base compartilhada e deixar a divisão ampla de `Theme.qml` para o final. Extrações pontuais de dados de Theme necessárias aos novos widgets fazem parte da etapa 5. Isso permite medir a redução real e reverter cada família sem comprometer as duas interfaces ao mesmo tempo.
