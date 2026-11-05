# Network nativo na Rise — 05/11/2026

Integrados os três recursos solicitados no painel compartilhado de V1/V2:

- Seleção de banda Wi-Fi com `omarchy-network-band`: somente opções disponíveis,
  Auto para remover fixação, estado pendente e mensagem de falha. A reconexão e
  eventual rollback continuam pertencendo ao helper nativo. Fechar o painel
  não interrompe uma troca de banda em andamento.
- Diagnóstico via `omarchy-network-status --verbose`: latência média das
  respostas válidas nas últimas cinco amostras e perda ICMP nas últimas 24.
  Valores zero são válidos; mudar interface reinicia as amostras. Consultas
  são serializadas, limitadas por timeout e param ao fechar o painel.
- Portal: consome a conectividade do NetworkManager. Portal e conexão limitada
  são distintos; o botão usa a URL fixa e o fluxo de login do Omarchy, que
  gerencia a pausa/restauração de exit node do Tailscale. O painel perde o foco
  exclusivo antes da abertura. Portal sem rota padrão continua acessível.

Não foi criado outro plugin. Comportamento está em
`shared/services/NetworkDiagnostics.qml` e apresentação em
`shared/components/NetworkDiagnosticsSection.qml`. Os adapters mantêm as
superfícies, cores e raios de V1/V2. O painel passa a ter altura limitada à
tela e rolagem, incluindo ajuste da lista de Wi-Fi para navegação por teclado.

## Evidências

- Suíte completa confirmada: **61 etapas aprovadas**,
  `ALL PLUGIN CHECKS PASSED` e código de saída **0**. A primeira execução
  imprimiu aprovação mas terminou com 143; foi repetida em sessão de processos
  isolada e não foi usada sozinha como prova de sucesso.
- Lint: **239 QML, 130 avisos**, sem supressões e sem aumento da contagem
  anterior de avisos. Não foram classificados todos os avisos preexistentes.
- Fixtures usam processos reais com helpers privados fictícios. Verificam
  amostras, perda, zero, mudança de interface, argumentos fixos, rejeição de
  banda inválida, ação em andamento ao fechar, falha e portal sem rota padrão.
- Painéis reais V1/V2 passaram nos testes de conteúdo/estilo com serviços
  simulados. Os imports completos das variantes compilaram no probe existente.
- Renderização isolada do componente foi inspecionada. Não houve inspeção
  visual do novo painel aberto na sessão real.
- Na instalação foram repetidas as fixtures novas e as de conectividade V1/V2,
  além da verificação de imports. O último ajuste de visibilidade do portal foi
  validado por teste focado e lint; a suíte completa não foi repetida depois
  dessa condição adicional.

## Aplicação

Oito arquivos aplicados por patch mínimo após `git apply --check`, com backup:

`/home/guiestrela/.local/state/quickshell-rise/review-backups/2026-11-05-native-network`

O backup contém arquivos anteriores, lista dos arquivos novos, patches,
lista de plugins e hashes de preferências/conexões, sem armazenar SSIDs ou
credenciais. O plugin instalado passou no validador Omarchy.

A shell reiniciada respondeu `ok`, permaneceu em V2 e não apresentou os erros
QML pesquisados no log. Os hashes de shell.json, variante, preferências V1/V2
e conexões ativas ficaram iguais; a lista de plugins também não mudou.
Nenhuma troca real de banda, DNS, conexão ou login de portal foi executada
para testar. Essas ações foram verificadas nas fixtures, não na rede real.

Logs temporários: `/tmp/rise-native-network-confirmed.log`,
`/tmp/rise-native-network-compile.log`,
`/tmp/rise-native-network-installed-panels.log` e
`/tmp/rise-native-network-runtime.log`.
