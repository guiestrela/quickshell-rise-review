# QR04-INSTALL-RETEST — reteste independente

Data/hora: 2026-09-30T14:04:09-03:00
Alvo: `/home/guiestrela/Work/omarchy/quickshell-rise-review` (snapshot Git, HEAD `f4eacec first commit`; sem versão/tag de produto identificada). Escopo: SEC-QR04-001/002, guardas do NordVpnController compartilhado e NordVPNPanel V1/wrapper V2. Testes comportamentais autorizados somente com recording stub; não usei o binário NordVPN real para mutação, nem instalei, ativei ou reiniciei.

Identidade verificada nesta revisão: SHA-256 de `versions/V1/modules/NordVpnController.qml`: `7bfd423c5bc0c13697bdadb0b4e1d09d3f985365c6bf539745a4e8a5bde19e1c`; `versions/V1/panels/NordVPNPanel.qml`: `831aa21d28d880750fb9694f311e16bbea4e4f6491c66589847d44bc2acca876`. V2 wrappers referenciam a implementação compartilhada V1. Fonte modificada observada apenas em quatro testes; diff de produção não aparece no `git status` desta cópia. O estado instalado não foi comparado/revalidado; conclusão não autoriza promoção.

## Veredito resumido

- SEC-QR04-001 (Protocol/Threat Protection Lite incompatíveis): **PASS limitado no controller; requisito de apresentação de indisponibilidade incompleto**. Chamadas diretas são recusadas sem argv pelo harness V1, e o painel mostra Protocol desabilitado com motivo. Threat Protection Lite aparece como indisponível, mas o texto/status do motivo não foi validado por uma execução de UI bem-sucedida. Não substituir por `protection`.
- SEC-QR04-002 (estado Unknown): **FAIL para critério de aceite UI; PASS limitado para bloqueio de mutações no controller**. Controller recusa famílias testadas no estado Unknown. Entretanto, alguns MouseAreas de settings do painel usam `vpnState !== "Unavailable"` e seguem habilitados em `Unknown`; portanto UI não é fail-closed conforme requerido. Também o teste de painel legado permanece falhando.
- Ambos os itens do relatório anterior não são tratados como exploração comprovada: o delta corretivo atende a guardas backend/controller em execução stub, mas a limitação UI/estado é uma falha de aceite observada, sem evidência de comando executado por clique nesse caminho.

## SEC-QR04-001 — Protocol e Threat Protection Lite

- Status: **corrigido no controller, aguardando fechamento da verificação completa do painel**.
- Severidade/confiança: pendência funcional/capacidade, sem vulnerabilidade incremental demonstrada; confiança alta para recusa do controller.
- CWE/OWASP/CVSS: não atribuídos; sem evidência de violação de autorização ou efeito no CLI.
- Localização: `versions/V1/modules/NordVpnController.qml:96-101`; UI `versions/V1/panels/NordVPNPanel.qml:151-160,239-242`; V2 wrappers compartilham a implementação V1.
- Pré-condição: invocar diretamente `setVpnSetting("protocol")` ou `setVpnSetting("threat-protection-lite")`, com CLI stub nas suítes.
- Evidência reproduzida: `node tests/qr04n-v1-runtime.mjs` rc 0 (`QR04N_V1_RUNTIME_PASS`, `ARGV_PASS`, `UNAVAILABLE_PASS`); `node tests/qr04n-v2-runtime.mjs` rc 0 com marcadores equivalentes; `node tests/qr04n-nordvpn-contract.mjs` rc 0. Harness executa QML e recording stub, não NordVPN real. Leitura do código confirma retorno `false` antes de `_runAction`, com motivo `Not supported by NordVPN CLI 5.4.0` em `vpnActionMessage`. Não atribuo os resultados às ações reais do CLI.
- Resultado esperado: ausência de argv para ambas as capabilities incompatíveis; opções visíveis mas desabilitadas, com motivo legível; nenhuma substituição silenciosa por outra configuração.
- Observado: controller recusa. UI de Protocol é desabilitada e explicita incompatibilidade. Threat Lite tem label “unavailable (CLI 5.4.0)” e MouseArea desabilitada. O runner do painel que deveria verificar a UI falha antes de encerrar: `node tests/qr04n-panel-v1.mjs`, rc 1, `missing/disabled handler target: vpn-setting-auto-connect`. Assim o motivo/estado visual integral não foi confirmado por execução bem-sucedida.
- Correção/aceite restante: alinhar o harness com os controles reais sem apagar cobertura necessária; executar painel V1 e cobertura V2 e verificar ausência de argv e motivo visível. Responsável: CTO/Desktop-dev conforme coordenação do projeto.

## SEC-QR04-002 — mutações em estado Unknown

- Status: **controller corrigido para as ações exercitadas; critério de UI não atendido**.
- Severidade/confiança: falha de aceite e UX fail-closed, não exploração confirmada; alta para observação estática e harness controller, limitada para impacto funcional real.
- CWE/OWASP/CVSS: não atribuídos. Não há CLI real nem efeito demonstrado.
- Localização: `NordVpnController.qml:20-25,45-128`; `NordVPNPanel.qml:100,116,142,160,177,182`.
- Pré-condição/evidência: estado é Unknown e controles/painel estão carregados. Harness V1 e V2 verificam recusa direta de connect/disconnect, país, pausa, settings firewall e DNS set/reset em Unknown, e ausência de mutações nos casos verificados. O runtime V1 e V2 passou com rc 0. Harness de wiring também tenta clicar toggle, go, DNS; não confirma por asserção todas as famílias de MouseArea de settings.
- Resultado esperado: todas as ações mutáveis indisponíveis na UI com explicação enquanto o estado não for conhecido, e recusadas no controller. Estados Connected/Disconnected suportados preservam ações positivas.
- Observado: `canMutate` corretamente exige enabled, estado Connected/Disconnected e não busy; funções mutáveis usam a guarda. Porém os MouseAreas de settings em `NordVPNPanel.qml:142` habilitam quando `vpnState !== "Unavailable"`, o que inclui `Unknown` (e estados transitórios). O handler ainda será recusado pelo controller, mas UI permanece acionável e não apresenta motivo de bloqueio. Teste de painel falha no alvo legado de auto-connect, não fornece controle negativo verde dessa UI.
- Recomendação: vincular todos os MouseAreas mutáveis a `controller.canMutate`; expor motivo claro para `Unknown`/busy/Unavailable; manter guardas do controller. Atualizar testes com cobertura de cada família de UI em Unknown, bem como positivos Connected/Disconnected, sem emitir argv mutável em negativas.
- Responsável: CTO/Desktop-dev.

## Verificações próprias e limites

| Comando | Resultado | Observação |
|---|---:|---|
| `node tests/qr04n-v1-runtime.mjs` | rc 0 | V1; recording stub; marcadores runtime/argv/unavailable |
| `node tests/qr04n-v2-runtime.mjs` | rc 0 | V2; recording stub; marcadores runtime/argv/unavailable |
| `node tests/qr04n-nordvpn-contract.mjs` | rc 0 | contrato widget independente |
| `node tests/qr04n-panel-v1.mjs` | rc 1 | falha `missing/disabled handler target: vpn-setting-auto-connect` |
| `qmllint -I /usr/lib/qt6/qml` em controller/painel e wrappers V2 | rc 0 | sem diagnósticos |
| `sha256sum` dos dois QML V1 | concluído | hashes acima |
| `git status --short`, `git diff --stat`, `git rev-parse` | concluído | quatro arquivos de testes modificados; relatório de handoff não rastreado; nenhum diff de produção listado |

Não realizei inspeção de captura/pixels, ownership de processos/serviços em compositor, visual wallpaper, teste integrado da barra, CLI real ou estado instalado. Nenhuma execução de wallpaper, mudança de rede, instalação, ativação ou reinício. A revisão não valida wallpaper, ownership/polling, pixels, promoção ou QR-04 completo. Relato de testes do autor no `reports/security/qr04-install-fix-handoff.md` é contextual; resultados acima são os comandos que executei nesta retestagem. O handoff documenta ausência de RED pré-patch, portanto ciclo TDD completo não foi comprovado.

## Conclusão e próximo passo

Reteste confirma mitigação controller-side com recording stub, mas não confirma fechamento dos dois requisitos de ponta a ponta: SEC-001 aguarda verificação UI completa; SEC-002 falha o critério de UI porque settings continuam enabled em Unknown. Não promover com base neste relatório. Encaminhar os dois itens e o teste legado falho ao CTO para correção/revisão; esta tarefa não implementou fonte e não declara instalação ou QR-04 concluído.
