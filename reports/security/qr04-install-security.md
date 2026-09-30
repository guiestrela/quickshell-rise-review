# QR-04-INSTALL-SEC — revisão defensiva do delta

Data: 2026-09-30T13:43:51-03:00
Alvo: `/home/guiestrela/Work/omarchy/quickshell-rise-review`; destino existente `~/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise`. Escopo: os 29 caminhos listados no manifesto `/home/guiestrela/.hermes/profiles/cto/cache/scratch/qr04-install-preflight/manifest.json` e delta `/home/guiestrela/.hermes/profiles/cto/cache/scratch/qr04-install-preflight/production.diff`. Revisão local read-only; sem tráfego externo, VPN real, wallpapers, instalação, ativação ou reinício.

## Veredito

**PASS limitado para segurança incremental do DELTA**: na evidência comparativa disponível, os comportamentos Protocol/ThreatLite e a aceitação de ações em `Unknown` já existem no baseline instalado; não foram demonstrados como regressões introduzidas pelos 29 arquivos do delta. Isto não é PASS de segurança geral, nem validação de capacidade/compatibilidade.

**Promoção continua não liberada** por pendência funcional/capacidade expressa para Protocol/ThreatLite incompatíveis localmente, a ser resolvida no trabalho corretivo e retestada, e por limitações de cobertura abaixo. Essa pendência não deve ser rotulada como vulnerabilidade incremental ou CWE sem evidência. Nenhuma ação VPN ou wallpaper foi executada; ausência de captura não aprova visual.

## Achados

### SEC-QR04-001 — Controles CLI incompatíveis ainda tentam mutação
- Status: confirmado por fluxo estático; comportamento do CLI não executado.
- Severidade: Informativa / pendência de capacidade; não classificada como vulnerabilidade incremental. Efeito de CLI não executado. Sem CVSS.
- Confiança: alta quanto à construção e encaminhamento do argv; não verificada a resposta da versão local do CLI.
- CWE/OWASP: Não atribuído: não foi demonstrada travessia de fronteira de autorização nem regressão frente ao baseline.
- Ambiente/versão: candidato QR-04, snapshot sem `.git`; commit não disponível.
- Arquivos/linhas: `versions/V1/modules/NordVpnController.qml:93-120` (especialmente 98, 110-120); `versions/V1/panels/NordVPNPanel.qml:151-160,239-242`. V2 usa wrappers compartilhando implementação: `versions/V1/variants/V2/modules/NordVpnController.qml:1-3` e painel `.../panels/NordVPNPanel.qml:1-3`.
- Pré-condições: NordVPN habilitado, painel aberto, controller habilitado, `vpnState` não igual a `Unavailable`, ação não busy.
- Evidência redigida: controller mapeia `threat-protection-lite` para `set threatprotectionlite on/off` (`:98,115-120`) e `protocol` para `set protocol TCP/UDP` (`:110-114`). O painel disponibiliza Protocol em MouseArea habilitada por estado/busy (`NordVPNPanel.qml:239-242`); Threat Protection Lite é apresentado como configuração com área clicável (`:151-160`). Não há capability gate por CLI na rota dessas ações. O contrato da tarefa proíbe tornar disponíveis opções locais incompatíveis.
- Reprodução/evidência comparativa: probe independente executado pelo CTO em Node vm com objetos inertes (resultado registrado no comentário Kanban, não execução própria) observou candidato e baseline aceitando rotas ThreatLite/Protocol em `Disconnected`; não houve Process/spawn. O NetworkPanel instalado tem `set threatprotectionlite` e `set protocol` em `NetworkPanel.qml:66-86`, sem guarda de estado. Candidato: controller `:98,110-120`; painel `NordVPNPanel.qml:151-160,239-242`. Não prova execução/efeito no CLI.
- Esperado: controles incompatíveis ficam desabilitados/indisponíveis e controller recusa suas chaves sem argv.
- Observado no código: as rotas montam argv e tentam iniciar o processo. Resultado real do CLI não observado.
- Impacto incremental demonstrado: nenhum. Resta pendência de capacidade/aceite: controles incompatíveis devem ficar indisponíveis, sem substituir proteção nem ampliar allowlist. Responsável funcional: CTO/Desktop-dev; não é achado de autorização confirmado.
- Correção recomendada: remover/recusar as rotas incompatíveis com guardas no controller e UI, sem fallback para outro controle; adicionar pares de teste stub comprovando ausência de argv para chaves incompatíveis e estado `Unknown`.
- Responsável: CTO/Backend (controller) com UI associada; sem encaminhamento por mensagem nesta execução.
- Regressão sugerida: testes unitários/harness V1 e V2 com fake Process, asserções de argv vazio para Protocol/ThreatLite e casos permitidos preservados; confirmar lint e diff dos 29 arquivos.

### SEC-QR04-002 — Estado inicial Unknown não impede ações de configuração
- Status: comportamento estático observado no candidato e herdado do baseline; regressão incremental não demonstrada.
- Severidade: Informativa; consequência real não executada e não há atribuição de vulnerabilidade.
- Confiança: alta.
- CWE: Não atribuído; comparação indica comportamento preexistente, sem evidência de regressão de segurança.
- Ambiente/versão: mesmo candidato sem commit.
- Arquivo/linhas: `versions/V1/modules/NordVpnController.qml:93-125`, `:129-136`, `:173-178`; painel `versions/V1/panels/NordVPNPanel.qml:100,116,142,160,177,182,242`.
- Pré-condições: widget recém-habilitado, antes da primeira consulta de status terminar; estado inicial `Unknown` (declaração `:12`); usuário aciona controle de configuração. UI e controller barram explicitamente apenas `Unavailable` e `vpnBusy`.
- Evidência: cada ação de setting/DNS verifica `vpnState === "Unavailable" || vpnBusy`, não exige estado conhecido; timers iniciam consultas posteriormente (`:212-220`). UI habilita os controles com a mesma condição. Assim o caminho é aceito com Unknown. Não reproduzi execução stub neste caminho.
- Reprodução/evidência comparativa: teste/probe de terceiros relatado pelo CTO comparou estados e confirmou aceitação de rotas pelo candidato; NetworkPanel instalado já habilita ações sem guarda de `vpnState` (`:46-51`, `:66-86`). A execução aqui não reproduziu o probe. Não houve spawn nem efeito real.
- Esperado: nenhum comando mutável até status/serviço conhecido e capaz; indisponibilidade sempre fail-closed.
- Observado: guardas permitem ação com Unknown e configuram argv.
- Impacto incremental demonstrado: nenhum; a diferença de segurança frente ao baseline não foi estabelecida. É estado/UX fail-closed desejável, não achado incremental confirmado.
- Correção recomendada: exigir estado conhecido apropriado para cada operação; serializar/impedir consulta concorrente com mutação conforme contrato, sem bloquear desnecessariamente ações autorizadas após estado válido.
- Responsável: CTO/Backend.
- Teste de regressão: pares Unknown vs Disconnected/Connected/Unavailable para cada família de ação, afirmando ausência de argv no estado inicial.

## Verificações e escopo residual

- `python3 tests/test_qr04w_scan.py` — rc 0, 3 testes OK. O harness usa diretórios temporários; cobre scanner básico, não prova ausência de TOCTOU.
- `node tests/qr04n-dns-guards.mjs` — rc 0, `QR04N_DNS_GUARD_PASS v1/busy: rejected; no DNS mutation argv`. Cobertura específica DNS busy; não cobre Protocol/ThreatLite ou estado Unknown.
- Tentei executar uma inspeção auxiliar por script Python via terminal; bloqueada pelo modo de aprovação da plataforma (rc -1). Nenhuma alteração/efeito ocorreu; revisão prosseguiu com leitura direcionada dos arquivos e testes existentes.
- Scanner: `wallpaper-scan.py:14-20,23-43,47-51` usa `stat(...follow_symlinks=False)`, exige raiz directory, não segue symlink dos filhos (`entry.stat(follow_symlinks=False)`), limita profundidade/contagem e opera com argv separado pelo serviço. Limitação: `abspath` não canonicaliza componentes ascendentes symlink; proteção observada não elimina corrida TOCTOU entre scan/uso. Não criei fixtures adicionais nem toquei em wallpapers reais.
- `WallpaperManagerService.qml:38-52` passa pasta configurada como argumento separado; `:95-97,111-114` passa caminho como `$1` a comando bash fixo, sem interpolar no texto de shell. `:168-219` estabelece layer Background por tela. Análise estática apenas; não executei QML/serviço nem confirmei efeitos em compositor.
- Ownership: buscas localizadas encontraram um `WallpaperManagerService` por Theme V1 e V2 (`Theme.qml:43`, V2 `:42`), e controller NordVPN em cada Theme (`Theme.qml:1225`, V2 `:1665`). V2 wrappers compartilham a implementação V1. Isso sugere um owner por Theme/variante, mas não prova exclusividade em runtime nem correção integral de polling/serviços. Diferenças herdadas entre baseline e host não foram reportadas como achado.
- O diff preflight fornecido mostra mudanças de ownership/integração e wrappers; não executei os testes de Quickshell do projeto por iniciarem QML/processos e não serem necessários para demonstrar o bloqueador. Não houve captura visual; nada aqui aprova visualmente.

## Próximo passo

### Comparação do baseline, identidade e cobertura do delta

- Baseline: cópia instalada em `/home/guiestrela/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise`; candidato CTO `.../qr04-install-preflight/candidate-20260930-134312`; staging informa comparação de 29/29 arquivos e hashes por caminho no `staging.json`. O manifesto SHA-256 lista hashes de source e instalado (arquivos novos com `installed_sha256: null`); commit indisponível, pois source é snapshot sem Git. A identidade auditada é esse staging/candidato, não a cópia futura após correção.
- Cobertura do manifesto de 29 caminhos: BarSlot V1/V2, Theme V1/V2, VariantRoot V1/V2, scanner Python, NetworkWidget V1/V2, NordVPNWidget V1/V2, NordVpnController V1/V2 (wrapper V2), NordVpnLayout JS, NordVpnStatus V1/V2, WallpaperLayout JS, WallpaperManagerService V1/V2, WallpaperProfile V1/V2, WallpaperWidget V1/V2, ControlPanel V1/V2, NetworkPanel V1/V2 e NordVPNPanel V1/V2. Inspeção estática focalizada em controller/painel, scanner/serviço e ownership Theme/VariantRoot; não foi auditoria linha-a-linha de todos os 29.
- Relato do CTO (não verificação própria): comparação 29/29 hash e compilações `Qt.createComponent` 9/9 READY; testes de wallpaper 19/19, scanner 3/3 e runtime widgets V1/V2 com doubles rc0. Nesta execução, comandos próprios foram `python3 tests/test_qr04w_scan.py` rc 0 (3/3) e `node tests/qr04n-dns-guards.mjs` rc 0 (`QR04N_DNS_GUARD_PASS v1/busy`). Tentativa de inspeção auxiliar pelo terminal bloqueada por approvals (rc -1); não houve alteração.
- Ownership: leitura estática encontrou um WallpaperManagerService por Theme/variante e controller VPN por Theme; wrappers V2 compartilham implementação. Isso sugere ownership estrutural, mas não demonstra exclusividade/polling em runtime. Não executados serviços, VPN, wallpaper, ativação, reinício nem captura visual.
- Não avaliado: exploração/runtime integrado da barra ativa, CLI NordVPN real, concorrência de serviços/polling em compositor, aplicação de wallpaper, cobertura visual/interação, todos os handlers além das áreas focalizadas, nem o candidato reconstruído após correções. O relatório não aprova essas dimensões.

**Decisão:** segurança incremental do delta examinado = **PASS limitado**; não foi demonstrada regressão de segurança bloqueadora frente ao baseline nos comportamentos registrados. Promoção/aceite QR-04 integral = **AINDA NÃO LIBERADO**, por pendência funcional/capacidade Protocol/ThreatLite já separada e por escopo de verificação limitado. Após correções, reconstruir/rehash do candidato e retestar o delta novo; não inferir autorização para instalação/ativação a partir deste parecer. Restrições: não ativar, não executar NordVPN real e não aplicar wallpapers.
