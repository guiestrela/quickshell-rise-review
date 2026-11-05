# Notificações — compatibilidade com Omarchy 4.5

Adaptado e aplicado à instalação em 05/11/2026, para o pacote Omarchy
`4.5.0-3`. A análise anterior encontrou uma migração para o motor derivado
do Omapager: os arquivos individuais e `notifications.json` foram substituídos
por `notifications/live.json`, `history.json` e `quiet.json`.

## Correções

- O leitor compartilhado reconhece os arrays nativos novos, mantém o fallback
  de Omarchy antigo/Mako e limita tamanho de arquivo e quantidade de entradas.
  JSON incompleto não é interpretado como histórico vazio válido.
- A identidade usa a chave nativa persistente, separando IDs de remetente
  reutilizados e evitando duplicação após reiniciar. Os timestamps em segundos
  do host são normalizados para o formato em milissegundos da Rise.
- Entradas modernas são removidas do cache da Rise quando saem dos dois
  arquivos nativos. A leitura respeita a retenção nativa de 24 horas para
  entradas fechadas. A lista Rise mantém seu limite existente de 50 entradas.
- V1/V2 leem `quiet.json` e observam alterações. O arquivo antigo continua
  como fallback. Estado incompleto preserva o último DND válido.
- A limpeza usa `notifications dismissAll` e marcações persistentes locais;
  foi removida a chamada inexistente `notifications clear`. A ação dispensa
  popups e limpa a lista da Rise; não edita os arquivos de histórico do host.
- Fechar uma entrada moderna a oculta na Rise sem dispensar outros popups
  com títulos iguais. O IPC nativo atual dispensa por substring de título,
  sem oferecer uma operação pública por chave individual.
- Os campos de aplicativo, título e corpo usam texto simples.
- A verificação das ações já suportadas de captura/janelas também reconhece
  os novos arquivos nativos, mantendo as restrições de identidade/comandos.
  Os botões de ação arbitrários de aplicativos continuam pertencendo aos
  popups nativos; não são reproduzidos de comandos armazenados no histórico.

## Validação

- Suíte completa: **59 verificações aprovadas**, com
  `ALL PLUGIN CHECKS PASSED`, no checkout.
- Lint: **237 QML, 130 avisos**, mesma contagem anterior; os avisos existentes
  não foram suprimidos nem todos classificados nesta tarefa.
- Leitor: sete testes de formatos/identidades/retenção e robustez passaram.
- Regressões JavaScript executam a lógica de merge, limpeza, identidade e DND
  da produção, incluindo IDs reutilizados, reinício, retenção e JSON inválido.
- Históricos V1/V2 passaram nos testes de runtime com cache e comandos inertes.
- Uma fixture adicional testa os FileViews reais de V1/V2: fallback antigo,
  criação de quiet.json, DND ligado/desligado e preservação em JSON incompleto.
  Passou separadamente e foi incorporada ao runner após a execução das 59
  etapas. A suíte inteira não foi repetida após essa adição de cobertura.
- Testes adicionais de crash, captura, navegador, app e callbacks selecionados
  passaram com ações simuladas. A fixture de falha do editor passou a simular
  também a validação dos executáveis, pois Tensaku não está instalado.
- Na instalação, repetidos leitor, JavaScript, DND e históricos V1/V2.
  O manifesto instalado passou no validador Omarchy.

## Aplicação e sessão

Aplicado patch mínimo de **13 arquivos**, conferido com `git apply --check`
e comparação de conteúdo com o checkout. Backup externo:

`/home/guiestrela/.local/state/quickshell-rise/review-backups/2026-11-05-notifications-45`

Contém código anterior, patch, lista de arquivos novos, cache anterior da Rise,
preferências e hashes anteriores e lista de plugins. Não contém uma cópia
adicional dos arquivos de mensagens nativos do Omarchy.

A shell foi reiniciada pelo comando oficial e respondeu `ok`, permanecendo em
**V2** e com DND **off**, como antes. A lista de plugins permaneceu idêntica.
Os hashes de shell.json, active-variant e preferências V1/V2 ficaram iguais.
O cache da Rise passou a conter **34 entradas com chaves nativas modernas**,
confirmando a integração real sem expor o texto das mensagens na saída.
Os trechos finais inspecionados do log não apresentam ERROR, ReferenceError,
TypeError, Unable to assign ou Binding loop.

Não foram criadas, abertas ou dispensadas notificações reais para testar.
A limpeza e as ações foram verificadas com fixtures; os estados reais de DND
e notificações não foram alternados. Não houve troca visual nativa para V1.
Logs temporários: `/tmp/rise-notifications-45-checks.log` e
`/tmp/rise-notifications-45-runtime.log`.
