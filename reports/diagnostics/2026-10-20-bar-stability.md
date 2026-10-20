# Verificação de estabilidade da Rise — 20/10/2026

## Resultado

Não foi encontrada evidência de que a Rise tenha causado queda do sistema nos registros consultados. Isso não exclui travamentos sem registro nem garante estabilidade futura. A barra instalada foi corrigida, recarregada e permaneceu respondendo ao IPC, com os mesmos oito plugins habilitados.

Os dumps de Quickshell consultados (PIDs 49732 e 22206, de 19 e 20/10) vieram de probes de testes em `/tmp`, não da barra instalada. As pilhas mostram SIGABRT durante `QGuiApplicationPrivate::createPlatformIntegration`, antes do carregamento QML. Os testes usavam conexão gráfica indisponível/restrita. A memória disponível era aproximadamente 25 GiB; a consulta ao journal não revelou OOM ou falha de GPU relacionada à barra.

## Correções

- Cabeçalho da agenda em V1/V2: substituir Row por Item para permitir âncoras laterais.
- Margens de widgets em V2: usar zero quando o widget não fornece os insets opcionais.
- Arraste de monitores: restaurar bindings antes de atualizar a prévia, pois essa atualização pode destruir o delegate. O teste anterior reproduziu contexto QML inválido e TypeError.
- Integração com o shell: expor fonte, tamanho, posição e visibilidade durante carregamento e troca de variantes. A ausência de `fontFamily` gerava avisos repetidos no serviço nativo de notificações.
- Instalador: verificar se `/dev/tty` realmente pode ser aberto antes de redirecionar entrada.
- Testes: atualizar fixtures de Bluetooth, seletor externo de wallpaper, fluxo explícito de Aplicar e instalação obrigatória dos coletores. Isolar autenticação Copilot e processos do host; verificar sintaxe de cada script, não apenas o primeiro argumento de `bash -n`.
- Probes: painel de atualizações usa plataforma offscreen e runtime temporário; compilação de PanelWindow verifica acesso ao Wayland antes de iniciar Qt.

## Validação

- QML lint: 177 arquivos, sem erro fatal; 5.171 avisos ainda reportados pelo linter. Não foram tratados como prova de crash.
- JavaScript: 40 arquivos de testes aprovados.
- Python unittest: 19 suítes, 73 casos aprovados fora do sandbox, necessário para consultar proprietários reais de executáveis.
- Suíte oficial: sintaxe shell, atualizações Arch, controlador da barra, coletor Codex, ciclo de vida Quattro, atualização de temas e painel de atualizações.
- Testes adicionais: instalação dos quatro coletores, Copilot, contrato do shell durante troca de variantes, carregamento/compilação V1/V2, Hearthstone, widgets compactos, DNS com helper privado, Wi-Fi QR com backend inerte, geometria, arraste, fechamento de painel e fluxo de Aplicar/confirmar/reverter.
- Nenhum monitor ou DNS real foi alterado nos testes de interação.
- Instalação ativa validada por `omarchy plugin validate`; IPC respondeu `ok`; nenhum novo coredump encontrado desde o início da investigação.
- ShellCheck indisponível; essa etapa foi explicitamente pulada.

## Instalação e limites

Backup dos arquivos instalados alterados: `/home/guiestrela/.local/state/quickshell-rise/review-backups/20261020-170033`.

Foram aplicadas apenas as correções faltantes na instalação. Alterações existentes da V2 em mídia, layout compacto, calendário e margens foram preservadas; não foi feita cópia integral do repositório sobre o plugin. O instalador e os testes foram corrigidos no projeto.

Após reinício, desapareceram os avisos de tipos indefinidos das notificações e margens e o aviso de âncoras do calendário. Permanecem mensagens do host sobre scanner de plugins externos, registro de IPC duplicado e portal, além da tentativa de abrir backend VDPAU NVIDIA. Não houve crash associado observado; esses avisos não foram resolvidos por mudanças em arquivos de pacote do Omarchy.

A verificação foi pontual: não incluiu suspensão/reinício do computador, alterações físicas de monitores, carga prolongada de GPU nem todos os serviços opcionais com contas reais.
