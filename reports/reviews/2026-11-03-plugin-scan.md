# Varredura do plugin — 03/11/2026

Escopo: checkout `quickshell-rise-review`, incluindo entradas, core, shared,
variantes V1/V2, helpers, integrações e verificações automatizadas. As primeiras
rodadas ficaram no checkout. Após autorização para executar os seis itens,
as correções foram aplicadas à instalação ativa com backup. O fechamento
abaixo registra o estado final; os resultados anteriores são históricos.

## Achados e correções

| Achado | Efeito | Correção |
| --- | --- | --- |
| Contadores inválidos no cache de autenticação | `ValueError`, `TypeError` ou `OverflowError` podia interromper o helper e impedir o retorno das ferramentas independentes | Ignorar o contador inválido, avaliar os demais e permitir o fallback para o CLI |
| 12 referências a IDs externos em componentes internos de temperatura e armazenamento V1 | Avisos de escopo e dependência do contexto implícito | Declarar `pragma ComponentBehavior: Bound` nos dois componentes |
| Variável de tooltip declarada com `var` dentro de bloco | Aviso de hoisting | Usar `const` no cálculo da posição vertical |
| Duas cópias do mapeamento de condições meteorológicas | Manutenção repetida e possibilidade de divergência entre widget e previsão | Centralizar em `WeatherData.glyphForCode`, preservando os ícones diurnos e noturnos |
| Import de `QtQuick.Dialogs` sem uso nos dois painéis de wallpaper | Dependência/import desnecessário | Remover os imports |
| Cobertura incompleta do runner para scripts sem extensão e integrações | Helpers de produção não passavam pela análise automática de shell; não havia verificação geral da sintaxe Python | Descobrir scripts Bash versionados pelo shebang, incluir integrações, verificar sintaxe Python e incorporar a regressão do cache |

A falha de autenticação foi reproduzida com um cache temporário contendo
`{"totalPrompts":"invalid"}`. Os testes novos não consultam contas reais:
substituem o diretório pessoal, a descoberta do executável e o subprocesso.
Também verificam que um contador válido após um inválido dispensa o CLI.

## Duplicidade

A comparação por SHA-256 dos arquivos de produção em `core`, `shared`, `variants`
e `scripts` não encontrou arquivos inteiros idênticos com mais de 150 bytes.
A inspeção dos mapeamentos de clima encontrou a repetição removida nesta revisão.

A comparação de arquivos correspondentes entre V1/V2 também identificou forte
semelhança em `VariantRoot`, `ArchUpdaterWidget`, `ClockWidget`, `MprisWidget`,
`ScreenRecordWidget` e `VoxtypeWidget`. Semelhança não comprova código redundante:
nesses pares existem adaptações de apresentação/contexto de cada variante.
Não foram substituídos por cópias ou adapters vazios para reduzir a contagem.
A busca automatizada não equivale a uma prova de ausência de duplicação semântica.

## Validação e limites

Resultado final: `bash tests/run-plugin-checks.sh` concluiu com
**48 etapas aprovadas** e `ALL PLUGIN CHECKS PASSED`.

- Lint inicial: **189 arquivos QML, 28 avisos**.
- Lint após as correções: **189 arquivos QML, 15 avisos**; mesma versão,
  imports e categorias, sem supressões.
- Os 15 avisos restantes são `PanelWindow is not creatable`. Uma instância
  isolada, invisível, foi carregada no Wayland com `PANEL_WINDOW_RUNTIME_PASS`,
  sem erros. Isso confirma a disponibilidade do tipo no runtime usado e sustenta
  a classificação como limitação dos metadados; não valida todas as interações
  de todos os painéis.
- O primeiro runner no sandbox parou no teste vertical V1 porque a criação do
  socket IPC foi bloqueada, apesar de emitir `V1_VERTICAL_LAYOUT_PASS`.
  A repetição com acesso aos sockets locais concluiu a suíte.
- A análise adicional de 27 scripts Bash de produção passou pelo ShellCheck.
- Testes dos ícones cobrem todos os códigos mapeados, dia/noite, códigos em texto
  e condições desconhecidas. As regressões de provedor e troca de localização
  também passaram.
- A validação do manifesto pelo gerenciador Omarchy passou para este checkout.

Não houve instalação, reinício da barra ativa, exclusão de caches, mudanças de
monitor ou ações em VPN, DNS, Bluetooth ou controles físicos. Testes usam os
limites simulados definidos no projeto. Esta revisão não garante ausência de
defeitos futuros nem substitui uma sessão manual completa na interface.

## Continuação da varredura

Mais três falhas foram identificadas e corrigidas:

1. **Snapshots de notificações:** um arquivo contendo `[]`, `null`, texto,
   número ou booleano era aceito pelo parser JSON, mas o acesso subsequente
   a `.get()` encerrava o helper. O leitor Omarchy e o fallback Mako agora
   ignoram registros que não são objetos e preservam as notificações válidas.
2. **Identidade do processo das notificações:** separar `/proc/<pid>/stat`
   diretamente por espaços deslocava o campo de início do processo quando
   o nome continha espaços. A leitura agora separa primeiro o nome delimitado
   por parênteses, inclusive nomes que contêm `)`, e só então lê o campo 22.
   Dados incompletos continuam retornando token vazio.
3. **Limite do scanner de wallpapers:** `list(os.scandir(...))` enumerava o
   diretório inteiro antes de aplicar `MAX_ENTRIES`, permitindo uso excessivo
   de memória e trabalho em diretórios grandes. A enumeração agora usa apenas
   o orçamento restante e fecha explicitamente o iterador antes de ordenar.

Os quatro testes novos do snapshot usam arquivos temporários e subprocessos
simulados. O scanner ganhou uma regressão que conta as entradas efetivamente
enumeradas: com limite 3 e 20 arquivos disponíveis, lê apenas 3. Seus cinco
casos (limite, recursão, modo flat, symlink e diretório ausente) passaram.
O runner agora inclui a regressão do snapshot de notificações.

### Validação da continuação

A suíte completa foi repetida após essas três correções e concluiu com
**49 etapas aprovadas** e `ALL PLUGIN CHECKS PASSED`. O lint manteve
**189 arquivos QML e 15 avisos**.
Os quatro testes do snapshot e os cinco do scanner passaram, assim como as
regressões de notificações V1/V2 e os controles do painel de wallpapers.

A primeira execução desta continuação voltou a encontrar o bloqueio de socket
IPC no sandbox no teste vertical V1, mesmo emitindo `V1_VERTICAL_LAYOUT_PASS`.
A repetição com acesso aos sockets locais passou, sem alterar o teste ou
suprimir erros. O log completo está em `/tmp/rise-plugin-scan-validation.log`
(arquivo temporário desta sessão).

Esta etapa concluiu a validação das correções pendentes no checkout. Nenhuma
alteração foi aplicada à instalação ativa e a barra não foi reiniciada.

## Nova rodada: integridade da resposta meteorológica

Foi reproduzida uma atualização parcial no painel compartilhado de clima:
uma resposta Open-Meteo com `current.temperature_2m: 99` e `daily.time`, mas
sem os demais campos, alterava a temperatura para `99`, preenchia sensação,
umidade e vento com `NaN` e lançava uma exceção ao acessar a previsão ausente.
Como o coletor captura a exceção, a previsão anterior permanecia junto aos
valores parcialmente atualizados.

`WeatherPanel.parseReport` agora verifica os campos numéricos atuais e as
listas de previsão utilizadas antes de alterar o estado do painel. Respostas
incompletas, valores nulos e tipos incorretos preservam os dados anteriores.
O teste `tests/weather-panel-report.test.cjs` executa a função de produção,
verifica a preservação de todos os campos e confirma que valores iguais a
zero continuam atualizando condições e previsão corretamente. O runner já
inclui esse arquivo pelo padrão `tests/*.test.cjs`.

Validação desta rodada: **49 etapas aprovadas**, com
`ALL PLUGIN CHECKS PASSED`; lint de **189 arquivos QML e 15 avisos**.
Os dois casos de teste novos passaram. A suíte foi executada com acesso aos
sockets IPC locais, usando as fixtures isoladas do projeto. Log temporário:
`/tmp/rise-plugin-scan-weather-validation.log`. A instalação ativa não foi
alterada e a barra não foi reiniciada.

## Continuação: previsão do provedor wttr.in

O caminho alternativo do mesmo painel também atualizava as condições atuais
antes de terminar de ler a previsão. Uma resposta com `weather: [null]`
reproduziu `TypeError` no acesso a `day.date`; uma entrada horária nula
também interrompia os cálculos. Isso deixava condições novas junto à
previsão antiga, apesar do tratamento de exceção no coletor.

A previsão agora é construída e sua estrutura é validada antes de alterar
os campos do painel. Listas inválidas, dias nulos e entradas horárias nulas
são rejeitados, preservando os dados anteriores. A regressão executa a função
de produção e os helpers reais de previsão, cobrindo tanto respostas inválidas
quanto uma resposta válida com temperatura zero e probabilidades de chuva.

Validação desta continuação: os quatro casos em
`tests/weather-panel-report.test.cjs`, a suíte JavaScript completa do runner,
o lint do painel (sem avisos) e o teste de ciclo de vida do radar V1/V2 passaram.
A suíte completa de 49 etapas não foi repetida nesta rodada; o resultado
anterior continua registrado acima. Log JavaScript temporário:
`/tmp/rise-plugin-scan-wttr-js.log`. Nenhuma alteração na instalação ativa.

## Fechamento dos seis itens

| Item | Resultado |
| --- | --- |
| 1. Suíte completa | **50 etapas aprovadas no checkout e 50 na instalação**, ambas com `ALL PLUGIN CHECKS PASSED`. A etapa adicional cobre IA e frases. |
| 2. Revisão complementar | Inspecionados estado/IPC/troca de variante, despacho de painéis, lógica de tray, mídia, wallpapers, notificações e normalização VPN. Executadas mais dez suítes isoladas de notificações, VPN e wake, além das sete verificações de display/ciclo de vida descritas abaixo. Achados desta etapa corrigidos. |
| 3. Semelhanças V1/V2 | Comparados os seis pares identificados anteriormente. Diferenças funcionais/visuais preservadas; não foi necessária outra extração para corrigir os problemas desta rodada. |
| 4. Interface e monitores | Troca real V2 → V1 → V2, abertura do seletor de wallpaper e fechamento por Escape em ambas as variantes; inspeção visual das barras, inclusive no monitor em retrato. Interações de display, rollback e mudanças de topologia verificadas com controladores simulados. |
| 5. Avisos QML | **15 avisos**, todos `PanelWindow is not creatable`. Os 15 componentes compilaram no Wayland e uma janela oculta carregou, sem erros. Mantidos como limitação dos metadados nesta versão. |
| 6. Aplicação e sessão | **24 arquivos adicionados/alterados**, três adapters vazios arquivados e removidos da instalação, manifesto validado e shell reiniciada. Sessão final: **V2 ativa**, ping `ok`, sem os erros de binding pesquisados nos logs finais. |

### Correções adicionais encontradas no fechamento

- **Painel de IA em V1:** o painel compartilhado lia `root.aiUsageReveal`,
  propriedade disponível apenas em V2, gerando `Unable to assign [undefined]
  to double` e impedindo a revelação correta. Agora usa a visibilidade em V1
  e mantém o progresso animado de V2. O teste executa o binding de produção
  com os dois contratos de root.
- **Frases da animação V1:** o caminho absoluto antigo
  `~/.config/quickshell/bar/quotes.txt` não acompanha a instalação como plugin.
  A leitura agora resolve `../quotes.txt` a partir do módulo. A regressão
  verifica a leitura real do arquivo empacotado, com a mesma estrutura relativa.
- **Descoberta de scripts no runner:** a instalação tem uma migração local
  de diretórios, ainda não consolidada no Git. O runner lia arquivos removidos
  do índice e ignorava arquivos novos. Agora inclui arquivos não ignorados,
  versionados ou novos, e descarta caminhos que já não existem.
- **Fixture de diagnóstico de crash:** a simulação dependia das permissões
  dos ancestrais de `/tmp` ou do checkout. Agora simula uma cadeia confiável
  fora da árvore privada do teste e mantém as verificações reais de permissões
  dentro dela. Os 12 testes passaram no checkout e na instalação, incluindo
  a rejeição do diretório `0777`; a verificação de produção não foi relaxada.
- **Notificações escapando da fixture do atualizador:** os cenários de erro
  simulavam pacman/sudo, mas deixavam `notify-send` alcançar a sessão real.
  A fixture agora captura as notificações num log privado e verifica esse
  efeito. Essa regressão passou separadamente no checkout e na instalação.
  As execuções anteriores produziram notificações de teste; não houve
  atualização real de pacotes.
- **Três adapters obsoletos na instalação:** `DisplayManagerController`,
  `NordVpnController` e `NordVpnStatus` em `variants/V2/modules` eram apenas
  encaminhamentos vazios para V1. Os consumidores de produção já importam
  diretamente os tipos compartilhados. Os três arquivos foram arquivados
  no backup antes da remoção; os demais arquivos locais foram preservados.

### Resultado da análise de semelhanças

| Par | Diferenças preservadas |
| --- | --- |
| `VariantRoot` | Tamanho da barra, requisitos de prontidão, ponte de compatibilidade V1, Reactor exclusivo de V1 e escolha do painel de display. |
| `ArchUpdaterWidget` | Cor por grupo, contraste do badge e estados de aviso em V2. |
| `ClockWidget` | Cor de conteúdo por grupo em V2. |
| `MprisWidget` | Escolha de estilo, altura vertical, fundo/sombra e cores por grupo. |
| `ScreenRecordWidget` | Cor de conteúdo por grupo em V2. |
| `VoxtypeWidget` | Contraste do estado de gravação quando o grupo tem preenchimento. |

Não foram criados adapters vazios para reduzir artificialmente a duplicação.
A análise complementar é uma revisão com escopo e evidências, não uma prova
de ausência de defeitos em todas as combinações possíveis.

### Evidência final e preservação da sessão

- Checkout: **189 QML, 15 avisos**. Instalação: **234 QML, 15 avisos**;
  a diferença vem de arquivos locais preexistentes, preservados.
- Sete suítes adicionais de display/ciclo de vida passaram: integração,
  ponteiro com Apply explícito, ponteiro geral, workspaces, Apply em runtime,
  memória de posições e falha/retry de variante. Os helpers e efeitos de
  monitor são simulados nessas suítes.
- Dez suítes adicionais de notificações/VPN/wake passaram, após a correção
  da fixture de permissões. Nenhum agente, browser ou aplicativo de email
  foi lançado pelas fixtures de notificações.
- O teste nativo final confirmou V1 ativa, seletor aberto e fechado por Escape,
  retorno a V2 ativa, erro de variante vazio e ping `ok`.
- Verificados por hash os 24 arquivos aplicados. Fora desses arquivos e dos
  três adapters arquivados, os arquivos anteriores da instalação permaneceram
  iguais, desconsiderando bytecode Python gerado pelos testes.
- A lista de plugins habilitados e a geometria/configuração dos dois monitores
  permaneceram iguais. Os hashes de `shell.json`, `active-variant`,
  `quickshell_widgets` e `quickshell_widgets_v2` foram conferidos ao final.
  O teste de clique alternou o formato de hora; a preferência original foi
  restaurada e seu hash original foi confirmado antes do fechamento.
- O log próprio da shell final não contém `ERROR`, `ReferenceError`,
  `TypeError`, `Unable to assign`, `Binding loop` ou falha de leitura das
  frases. Avisos preexistentes de scanner/portal e carregamento inicial de
  thumbnails não foram classificados como falhas de binding.

Backup fora da árvore observada:
`/home/guiestrela/.local/state/quickshell-rise/review-backups/2026-11-03-scan-100115`.
Contém os arquivos anteriores, manifestos de hashes, patches aplicados e os
três adapters removidos. Evidências textuais desta etapa estão em
`2026-11-03-plugin-scan-evidence/`, ao lado deste relatório.

Não houve desconexão física de monitores, alteração real de VPN/DNS/Bluetooth,
instalação de pacotes ou teste de controles físicos. Hotplug/rollback foram
exercitados por simulação. Os seis itens foram encerrados com esses limites
explícitos; nenhuma contagem de testes garante ausência de defeitos futuros.
