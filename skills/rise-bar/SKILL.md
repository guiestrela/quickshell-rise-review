---
name: rise-bar
description: Instalar, configurar, desenvolver e diagnosticar a Quickshell Rise Bar no Omarchy, incluindo variantes V1/V2, widgets e integrações. Use para pedidos sobre Rise Bar ou Quickshell Rise; não para outras barras ou configuração geral do desktop.
---

# Rise Bar

Cuide da Rise preservando a variante escolhida, as configurações salvas e os plugins do usuário. Responda no idioma do usuário.

## Localizar a instalação e o código

O plugin é `io.github.guiestrela.quickshell-rise`, do repositório
`https://github.com/guiestrela/quickshell-rise-review`.

Identifique o checkout usado na tarefa e a instalação real antes de editar. A instalação padrão é
`~/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise`.
A skill pode estar instalada separadamente; não deduza o caminho do projeto a partir da pasta desta skill.

Leia `README.md` e os arquivos envolvidos no checkout. Alguns documentos e scripts mantêm caminhos legados em `~/.config/quickshell`; confirme o modo em uso antes de seguir esses procedimentos.

## Instalar ou atualizar

Leia [references/installation.md](references/installation.md) para instalar a barra com fontes, CAVA, coletores de uso de IA e hook de recuperação. Ela contém o comando completo de instalação. Se o pedido for apenas documentação, forneça ou edite as instruções sem executar a instalação.

Para uma instalação existente, inspecione primeiro:

```bash
omarchy plugin list
omarchy plugin validate "$HOME/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise"
```

Use `omarchy plugin update io.github.guiestrela.quickshell-rise` para atualizar pelo gerenciador, respeitando modificações locais. Não substitua toda a instalação pelo checkout para aplicar uma correção pequena. Compare os arquivos, preserve as diferenças locais, faça backup fora da árvore monitorada do plugin e aplique apenas o necessário. Reinicie com `omarchy restart shell` quando a alteração autorizada precisar disso; o reload pode manter módulos QML em cache.

## Arquitetura que deve ser preservada

- `Bar.qml` é a entrada do plugin no processo existente `omarchy-shell`. Não inicie uma segunda barra com `qs -p` para testar a instalação ativa.
- `versions/V1/core/StateService.qml`, `VariantHost.qml` e `IpcRouter.qml` controlam estado, carregamento e IPC. Somente a variante selecionada deve estar instanciada.
- V1 fica em `versions/V1/`; V2 em `versions/V1/variants/V2/`. Cada `VariantRoot.qml` cria barras para as saídas válidas; `BarSlot.qml` organiza widgets. Lógica e apresentação ficam em `modules/` e `panels/`.
- Antes de corrigir V1/V2, verifique se o arquivo de V2 contém implementação própria ou apenas importa o de V1. Corrija o comportamento compartilhado sem apagar diferenças visuais intencionais.
- Serviços do Omarchy consultam `fontFamily`, `position`, `barSize` e `barHidden` na entrada da barra. Esses valores precisam continuar válidos durante carregamento e troca de variante.
- Estado e preferências vivem fora do código: `~/.local/state/quickshell-rise/active-variant`, `~/.cache/quickshell_widgets` e `~/.cache/quickshell_widgets_v2`, além de caches específicos. Não apague esses arquivos para corrigir uma falha sem investigar sua função.
- Preserve notificações, OSD, lock, idle, áudio, rede e os demais plugins habilitados. Não use `pkill quickshell`, não desabilite plugins em massa e não edite `/usr/share/omarchy/` para corrigir a Rise.

Consulte `docs/integrations.md`, `docs/usage.md` e `docs/fan-control.md` do checkout conforme a integração afetada. Não invoque serviços com contas reais para um teste que pode usar fixtures.

## Diagnosticar crash ou travamento

Distinga queda da barra, falha de um helper e queda do sistema. Colete o PID, a linha de comando e o horário com `pgrep -a quickshell`, `coredumpctl list` e `coredumpctl info <PID>`. Leia o journal pelo PID correto; o processo pode aparecer como `omarchy-shell` no journal mesmo sendo `quickshell` no executável.

Confira memória/OOM e mensagens de GPU no período relevante. Um SIGABRT em `QGuiApplicationPrivate::createPlatformIntegration` vindo de um probe em `/tmp` pode ser falha de acesso à sessão gráfica antes de carregar QML; não o atribua à barra instalada sem evidência. Avisos de lint também não comprovam crash.

Use probes isolados com helpers simulados. `offscreen` serve para componentes sem dependência de layer shell; `PanelWindow` exige Wayland acessível. Verifique o socket antes de iniciar esses testes. Para testes headless, use runtime temporário, backend software e `QT_QPA_PLATFORMTHEME=''` para evitar dependência de GTK/DBus da sessão.

No QML, procure especialmente processos/timers sobrepostos, acesso a objetos destruídos, propriedades opcionais indefinidas e bindings inválidos. Atualizar o modelo de um Repeater pode destruir seu delegate: restaure bindings e capture os argumentos antes da chamada que atualiza o modelo. Não continue usando o delegate depois dessa chamada.

## Validar uma alteração

Rode a partir do checkout os testes pertinentes. Para uma revisão ampla:

```bash
bash tests/run-plugin-checks.sh
```

O runner verifica sintaxe shell, QML, regressões de ciclo de vida/atualizações, contrato com o shell e testes JavaScript. ShellCheck é opcional e sua ausência deve ser informada. Esse comando não substitui testes de interação Wayland.

Para mudanças em monitores ou seu ciclo de vida, use os testes com controlador inerte, conforme o caso:

```bash
TMPDIR=/tmp python3 tests/test-display-integration.py
TMPDIR=/tmp python3 tests/test-display-explicit-apply-pointer.py
TMPDIR=/tmp python3 tests/test-display-pointer.py
```

Confira no teste os requisitos de sessão e as fronteiras simuladas antes de executá-lo. Não altere monitores, DNS, VPN, pareamento Bluetooth ou controles de ventoinha reais só para testar a interface. Se uma verificação estiver bloqueada pelo ambiente, relate isso sem declarar aprovação.

Após aplicar uma correção na instalação, valide o plugin, consulte `omarchy-shell shell ping`, confira os novos logs e compare os plugins habilitados. Relate o que mudou, os testes executados, o backup e os limites da evidência; não prometa ausência de crashes futuros.
