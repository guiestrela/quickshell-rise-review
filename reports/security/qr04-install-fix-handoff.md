# QR04-INSTALL-FIX — handoff de implementação

Data: 2026-09-30. Fonte: `/home/guiestrela/Work/omarchy/quickshell-rise-review` (snapshot sem Git). Escopo limitado a guards/capability NordVPN V1 compartilhada por V2; nenhum teste usou o binário NordVPN real para mutação.

## Delta implementado

- `versions/V1/modules/NordVpnController.qml`: nova propriedade `canMutate` exige `enabled`, estado exatamente `Connected` ou `Disconnected` e `!vpnBusy`. Todas as famílias mutáveis — connect/disconnect, país, pause, settings e DNS set/reset — verificam essa propriedade antes de montar/iniciar argv. Chaves `protocol` e `threat-protection-lite` retornam falso com motivo `Not supported by NordVPN CLI 5.4.0`; não há fallback para `protection` nem inclusão dessas chaves no allowlist.
- `versions/V1/panels/NordVPNPanel.qml`: controles mutáveis usam `canMutate`; Protocol e Threat Protection Lite permanecem visíveis, marcados indisponíveis com razão explícita e desabilitados.
- Testes: `tests/qml/qr04n-{v1,v2}-wiring.qml`, `tests/qr04n-{v1,v2}-runtime.mjs`, `tests/qr04n-nordvpn-contract.mjs` atualizados para negativas de Protocol/Threat Lite e Unknown. `tests/qml/qr04n-panel-v1.qml` foi adaptado para a nova capacidade; o runner legado ainda falha em handler que não existe no layout atual (detalhe abaixo).
- Não há alteração de V2 wrapper, BarSlot, Theme, services, ownership ou AI. Não foi feita instalação, ativação, restart, conexão/ação VPN ou wallpaper.

## Evidência real

NordVPN CLI local consultada sem mutação: `nordvpn --version` → `NordVPN Version 5.4.0`; `nordvpn set --help` lista `protection`, não `threatprotectionlite`, e não lista `protocol`.

| Comando | rc | Evidência |
|---|---:|---|
| `node /home/guiestrela/Work/omarchy/quickshell-rise-review/tests/qr04n-v1-runtime.mjs` | 0 | `QR04N_V1_RUNTIME_PASS`, `QR04N_V1_ARGV_PASS`, `QR04N_V1_UNAVAILABLE_PASS`; argv positivos registrados: connect, disconnect, país, pause 15m, firewall, kill-switch, auto-connect, technology. O fixture executa controller/painel QML reais e CLI recording stub. |
| `node /home/guiestrela/Work/omarchy/quickshell-rise-review/tests/qr04n-v2-runtime.mjs` | 0 | `QR04N_V2_RUNTIME_PASS`, `QR04N_V2_ARGV_PASS`, `QR04N_V2_UNAVAILABLE_PASS`, mesmos comandos suportados via wrappers V2. |
| DNS runtime V1 e `--v2` | 0 / 0 | `QR04N_DNS_RUNTIME_PASS` em ambas; argv exatos set servers e reset `off`. |
| DNS guards V1/V2 busy e unavailable (4 invocações) | 0 | Quatro `QR04N_DNS_GUARD_PASS`; sem argv DNS de mutação nos casos bloqueados. |
| `qr04n-extra-switches-runtime.mjs` e `--v2` | 0 / 0 | Oito handlers suportados / 16 argv stub exatos por variante. |
| `qr04n-pause-selector-runtime.mjs` | 0 | `QR04N_PAUSE_SELECTOR_RUNTIME_PASS v1/durations+busy`; cinco durações e busy guard pelo handler/controller reais, recording stub. |
| qmllint no controller/painel V1, wrappers V2 e wiring QML V1/V2 | 0 | sem saída/diagnósticos. |
| `qr04n-nordvpn-contract.mjs` | 0 | `QR04N independent widget contract PASS`. |
| `qr04n-panel-v1.mjs` | **1** | O harness legado falha `missing/disabled handler target: vpn-setting-auto-connect`. Esse alvo não está representado como handler no painel atual; não foi removida a asserção silenciosamente nem declarada a suite verde. A tentativa inicial também reportou controller double sem `canMutate`; fixture recebeu a propriedade, mas a incompatibilidade do alvo persistiu. |

Nos runtimes V1/V2, os testes de wiring exercitam controller em `Unknown`: connect/disconnect, país, pause, settings firewall e DNS set/reset são recusados; toggle, país/go e DNS UI estão desabilitados, cliques sintéticos não despacham. Também chamam Protocol e Threat Protection Lite diretamente e verificam recusa/motivo; as sentinelas de argv positivos excluem essas rotas. Os controles incompatíveis visíveis/desabilitados são cobertos no painel isolado, mas o runner `qr04n-panel-v1.mjs` não completou por sua inconsistência preexistente descrita acima.

## Limitações e revisão necessária

- RED prévio: não foi capturada execução reproduzível dos novos casos contra a fonte antes do patch; esta tentativa passou diretamente à implementação. As verificações descritas são resultados reais pós-alteração, não alegação de ciclo TDD completo. Revisão deve considerar isso.
- Não executei casos dedicados de `Connecting`/`Disconnecting` em todas as famílias. O guard usa `canMutate`, que os exclui pelo enum conhecido e também por `vpnBusy`; Unknown foi exercitado para cada família conforme fixture.
- Integração em sessão/barra completa, inspeção visual/DPI/multi-monitor não executadas. Harnesses usam Wayland real (`XDG_RUNTIME_DIR=/run/user/1000`, `WAYLAND_DISPLAY=wayland-1`) e CLI recording stub, não NordVPN real.
- O runner `qr04n-panel-v1.mjs` permanece vermelho; precisa de triagem/reconciliação de suas expectativas com os controles atuais antes de qualquer conclusão QR-04. Isto não deve ser resolvido ampliando o escopo desta fatia sem autorização.

## Próximo passo

Revisão independente do delta e da evidência, registrando explicitamente o teste legado falho e a lacuna de RED. Não promover nem instalar com base neste handoff; QR-04 permanece incompleto.
