# Indicadores do Omarchy na Rise — revisão de viabilidade

**Fechamento:** grupo completo implementado e aplicado à instalação após a
confirmação do usuário. A seção final registra a validação e o backup; as
seções iniciais descrevem a análise anterior à implementação.

Inspeção do checkout e dos fontes locais de `/usr/share/omarchy/shell`,
Omarchy `4.0.0.alpha`, em 05/11/2026. Não é uma comparação com releases
remotos nem uma validação visual da sessão instalada.

## Resultado

É viável integrar o grupo da imagem usando os serviços do próprio host.
O componente nativo é `omarchy.indicators`, registrado em
`plugins/bar/widgets/Indicators.manifest.json`. Não requer instalar outro
plugin nem iniciar outra instância do Quickshell.

O catálogo inclui PasswordlessSudo, ScreenRecording, RemoteSession, Reminder,
NightLight, Dnd e StayAwake. A sessão remota aparece apenas quando ativa.
Os demais podem ser revelados por hover ou pela opção `alwaysShow`.

## Contratos e adaptação necessária

- `Bar.qml` já recebe `shell` e `barWidgetRegistry`, mas `VariantHost.qml`
  não encaminha esses objetos às variantes. A integração precisa de uma
  ponte explícita e restrita para os serviços usados.
- O host oferece `firstPartyServiceFor` para `omarchy.idle`,
  `omarchy.nightlight`, `omarchy.notifications` e `omarchy.remote-session`.
  Esses proxies fornecem estado e ações sem recriar os serviços.
- Gravação, lembretes e sudo usam os comandos oficiais e atualizações via
  `omarchy.indicators refresh`. O refresh precisa atingir todos os monitores,
  com um único coordenador/handler na variante ativa.
- O widget nativo depende de `qs.Ui` e `qs.Commons`: carregá-lo diretamente
  mantém dimensões e estilos globais do Omarchy. Para preservar a Rise,
  usar lógica compartilhada e apresentação por variante, com `pillH`,
  tipografia, cores, bordas e superfícies dos adapters existentes.
- Preservar a orientação vertical e criar apenas a árvore da orientação ativa.
  O próprio código nativo documenta que manter duas árvores invisíveis
  duplicava indicadores e processos.

## Evitar duplicidade

A Rise já possui `ScreenRecordWidget`, `IdleWidget` e
`NotificationSilenceWidget`. O grupo deve reutilizar os respectivos estados
e ter uma regra explícita de exclusividade visual com os widgets separados.
Não remover preferências nem reordenar silenciosamente os slots existentes.
Um novo slot deve preservar layouts salvos e permitir desativação.

Não copiar serviços, instalar clones nem criar outro alvo IPC para o mesmo
recurso. V1/V2 devem compartilhar comportamento; somente a variante ativa
deve possuir o coordenador. A disponibilidade de serviços desativados precisa
ser tratada sem apresentar um estado falso de funcionamento.

## Revisão após a atualização

Os caminhos consultados atualmente pela Rise para idle e notificações ainda
existem no Omarchy instalado. Os comandos `idle status` e
`notifications ping` continuam implementados. O arquivo `stay-awake` ainda
é persistido pelo serviço nativo no caminho usado pela Rise.
Não foi demonstrada quebra desses contratos por esta inspeção.

A API de proxies permite substituir progressivamente probes/processos por
bindings reativos no modo plugin, mantendo fallback apenas onde necessário.
Essa é uma melhoria de integração proposta, ainda não implementada.

O validador recusou o checkout porque `.agents/skills/rise-bar` é um symlink;
isso é uma restrição do pacote de desenvolvimento, não um erro QML
demonstrado. A validação da pasta instalada terminou com código zero.
`omarchy plugin list` não conseguiu consultar a shell neste contexto
(resposta: `omarchy-shell is not running`); isso não prova que a sessão
gráfica do usuário esteja parada.

Até essa primeira etapa, nenhum arquivo da instalação, configuração pessoal,
plugin habilitado ou serviço de conta havia sido alterado. A integração
visual ainda não estava implementada.

## Verificações automatizadas

Executado `PATH=/usr/bin:/bin bash tests/run-plugin-checks.sh`; o PATH evita
o shim do mise, que tentou escrever fora do workspace na primeira tentativa.
Log temporário: `/tmp/rise-omarchy-review-20261105.log`.

O lint analisou 235 arquivos QML e registrou 130 avisos. Essa contagem não
deve ser comparada diretamente à revisão anterior de 189 arquivos. Os avisos
não foram classificados individualmente nesta análise de viabilidade.

A suíte interrompeu em `shared clock and recording widgets`: a fixture
emitiu `SHARED_STATUS_WIDGETS_PASS`, mas o Quickshell falhou ao abrir seu
socket IPC no sandbox e retornou erro. Portanto, a suíte completa não passou;
o marcador interno não substitui o resultado do processo. As etapas anteriores
aprovadas constam no log, incluindo OneDrive, painéis e ciclo de vida.
Não houve teste visual no Wayland nem reinício da barra instalada.

## Implementação e aplicação do grupo completo

Após a confirmação do usuário, foi implementado um coordenador compartilhado
em `shared/services/OmarchyIndicators.qml` e um componente visual em
`shared/components/OmarchyIndicatorsWidget.qml`. O host encaminha sua fachada
pública ao coordenador da variante ativa. Não há novo plugin, cópia dos
serviços do Omarchy nem coordenador por monitor.

O grupo ocupa o G8 existente, junto ao relógio, em V1/V2 e nas duas orientações.
Substitui as instâncias inline de idle, DND e gravação; mantém voz e update.
Preserva IDs, ordem, preferências, superfícies e cores por variante/grupo.
Os ativos aparecem primeiro; os inativos aparecem ao passar o mouse no G8.
Sessão remota só aparece quando ativa. A apresentação não replica toda a
ordenação cronológica/ancoragem do widget nativo; preserva a ordem do catálogo
dentro dos blocos ativo e inativo.

Idle, DND, luz noturna e sessão remota consultam os proxies nativos. Gravação
reutiliza o estado já coletado pela Rise. Lembretes e sudo consultam os helpers
oficiais, sem polling adicional. Atualizações concorrentes são coalescidas.
O handler único `omarchy.indicators refresh` é alcançado pelo fallback de
`omarchy-shell` para `qs ipc`; não duplica o registro interno `ShellIpc`.
Texto dinâmico de tooltips é neutralizado antes de chegar ao host AutoText.

### Validação final

- Checkout: **59 verificações aprovadas**, `ALL PLUGIN CHECKS PASSED`, com
  acesso aos sockets locais. Log: `/tmp/rise-indicators-full-checks.log`.
- Lint: **237 arquivos QML, 130 avisos**, mantendo a contagem da análise
  inicial desta sessão. Não foram suprimidos nem classificados todos os
  avisos preexistentes.
- Fixture nova: sete indicadores, transições, ações nativas com proxies
  fictícios, respostas inválidas, coalescência, geometria e texto de tooltip.
  Outra fase usa Process/collector e IPC reais com executáveis fictícios.
- Imports reais de V1/V2 compilaram no probe de display com controlador
  simulado. As fixtures verticais de V1/V2 passaram, incluindo os estilos
  exercitados pela suíte. Foi necessário incluir o componente novo nas
  cópias planas das fixtures; a validação de produção não foi relaxada.
- Na instalação, repetidos os testes novos de indicadores/IPC e a verificação
  de fontes/imports. O validador Omarchy passou. A suíte completa de 59
  verificações foi executada no checkout, não repetida inteira na instalação.

### Instalação e estado final

Aplicado patch mínimo de **15 arquivos** após `git apply --check`, com backup:

`/home/guiestrela/.local/state/quickshell-rise/review-backups/2026-11-05-native-indicators`

O backup contém arquivos anteriores, patch, lista de arquivos novos, estado e
hashes anteriores e lista de plugins. Quatorze arquivos aplicados coincidem
por conteúdo com o checkout; a fixture vertical V2 mantém diferenças locais
anteriores, sobre as quais o patch foi aplicado sem substituição integral.

Foram habilitados somente `omarchy.nightlight` e `omarchy.reminders`, que
estavam instalados e desativados e são necessários aos controles completos.
Nenhum outro estado de plugin foi alterado. A comparação estrutural de
`shell.json` confirmou somente essa mudança. A shell foi reiniciada pelo
comando oficial, respondeu `ok` e permaneceu em **V2**. Hashes de
`active-variant`, `quickshell_widgets` e `quickshell_widgets_v2` permaneceram
iguais aos anteriores.

Os logs finais não contêm `ERROR`, `ReferenceError`, `TypeError`,
`Unable to assign` ou `Binding loop` nos trechos inspecionados.
O refresh nativo respondeu sem erro. Capturas da faixa superior nos dois
monitores confirmaram a barra renderizando em V2, com o grupo inativo
recolhido. O hover nativo não foi confirmado: o comando legado de movimentação
de ponteiro não é aceito pelo Hyprland desta sessão; ambas as tentativas
retornaram erro. A revelação dos ícones foi exercitada pelas fixtures.

Não foram acionados gravação, alteração de sudo, criação de lembretes nem
toggles reais de DND/idle/luz noturna para testar as ações. A confirmação
funcional desses cliques vem das fronteiras simuladas, não de mudanças nos
estados reais da sessão. Também não foi realizada troca visual nativa para V1.
