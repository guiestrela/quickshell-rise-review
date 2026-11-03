# Verificação do projeto — 03/11/2026

Revisão do checkout atual, sem aplicação à instalação ou alteração de serviços.

## Falhas confirmadas

1. **Fixture vertical da V1 desatualizada** — `tests/test-v1-vertical-bar.py:19`
   tenta substituir a expressão antiga `barShellStyle === "fit" ? 44 : 40`
   na fixture da V2. Ela agora contém `barShellStyle === "fit" ? 40 : 36`.
   A substituição não ocorre, a V1 simulada usa 36 px em vez dos 40 px de
   produção e a asserção `left panel gap` falha. O processo não termina e
   excede os 10 segundos. Reproduzido também com sockets locais disponíveis.
   Esta regressão do teste decorre da redução recente da largura da V2;
   não demonstra falha na geometria de produção da V1.
2. **Contrato legado NordVPN procura a âncora no wrapper** —
   `tests/qr04n-nordvpn-contract.mjs:53` exige `root.vpnBarX` no wrapper V1.
   A posição horizontal é implementada em `shared/panels/NordVPNPanel.qml:114`;
   o wrapper configura a superfície e o posicionador lateral. O teste falha
   com `VPN panel must not depend on the Network anchor` antes do runtime.
3. **Fixture legada do painel NordVPN não carrega recursos fora da raiz** —
   `tests/qml/qr04n-panel-v1.qml:66` carrega o painel por um caminho fora da
   raiz usada pelo runner `tests/qr04n-panel-v1.mjs:15`. A execução autorizada
   no Wayland retorna `qrc:/qs-blackhole: No such file or directory` e depois
   `panel did not open independently`. O controlador da fixture é simulado;
   nenhuma ação VPN real foi executada. O teste não chega às antigas falhas
   de handlers descritas no handoff de setembro.

## Validação

- Suíte geral: repetida com acesso aos sockets locais após bloqueio ambiental
  no sandbox; interrompida no teste vertical da V1, sem aprovação completa.
- Sintaxe Bash/Python, ShellCheck, imports e as verificações anteriores ao
  teste vertical V1 passaram na repetição.
- QML: 189 arquivos analisados, 15 avisos; a etapa de lint passou.
- JavaScript: 48 verificações passaram, nenhuma falhou.
- Display/rollback simulado: três testes adicionais passaram.
- Leitura NordVPN daemon: seis testes adicionais passaram.
- Seleção NordVPN: três cenários de processo passaram, com CLI/reader simulados.
- UI de seleção NordVPN V1/V2: passou com QtTest isolado, sem ações VPN reais.
- Defaults de layout V2: dois testes passaram.

Logs completos desta sessão, temporários:
`/tmp/rise-project-review-native-checks.log`, `/tmp/rise-project-review-js.log`,
`/tmp/rise-project-review-v1-detail.log`,
`/tmp/rise-project-review-nordvpn-native.log`,
`/tmp/rise-project-review-selection.log` e `/tmp/rise-project-review-vpn-ui.log`.

As etapas posteriores ao teste vertical da V1 no runner não foram concluídas
por ele nesta execução. Nenhuma correção de código foi feita nesta revisão;
os resultados não equivalem a uma auditoria exaustiva ou a interação manual
com todos os painéis e monitores.

## Correções após autorização

- A fixture V1 agora define sua largura de 40 px independentemente da
  expressão de estilos da V2, com asserção de que exatamente uma declaração
  foi substituída. O teste de layout V1 passou com sockets locais disponíveis.
- O contrato NordVPN verifica a âncora horizontal na implementação
  compartilhada e exige a âncora lateral `vpn` no wrapper V1. Passou.
- O runner do painel NordVPN monta uma árvore temporária com o painel,
  wrapper e dependências reais dentro da raiz da configuração Quickshell.
  O controlador é um QtObject simulado com registro de chamadas; nenhum
  serviço ou comando VPN real é executado.
- A fixture foi reconciliada com os controles atuais: país por seletor,
  auto-connect e país preferido, três tecnologias, UDP/TCP, três controles
  de segurança, desabilitação por capacidade, cinco durações de pausa e
  fechamento independente. O contrato antigo de texto e controles
  indisponíveis foi substituído por verificações dos argumentos atuais.
- O painel passou nas verificações estáticas e de runtime, sem os erros
  pesquisados no log. O lint da fixture QML passou sem avisos.

As alterações são restritas aos testes e a este relatório. Nenhuma alteração
foi aplicada à instalação; não foi necessário reiniciar a barra.

### Validação final após as correções

`bash tests/run-plugin-checks.sh` concluiu com **50 etapas aprovadas** e
`ALL PLUGIN CHECKS PASSED`, incluindo o layout vertical V1 anteriormente
bloqueado. QML: **189 arquivos e 15 avisos**; os avisos não foram suprimidos.
Os dois testes NordVPN corrigidos passaram separadamente; eles não fazem
parte desse runner. Log da suíte: `/tmp/rise-fix-full-checks.log`.
Logs específicos: `/tmp/rise-fix-v1-layout-native.log` e
`/tmp/rise-fix-vpn-panel.log`. O `git diff --check` também passou.
