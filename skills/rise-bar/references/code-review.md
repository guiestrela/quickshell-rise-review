# Revisão de código, lint e regressões

## Diagnosticar antes de modificar

Conte os avisos no checkout atual, sem reutilizar totais de uma sessão anterior. Use a mesma versão, imports e opções de `qmllint` antes e depois. Registre arquivos analisados, avisos, categorias e falhas; retorno zero não significa ausência de avisos.

O runner do projeto conta linhas de console iniciadas por `Warning:`. O relatório JSON também pode incluir diagnósticos que o console não mostra. Use JSON para localizar sugestões, mas não misture as duas métricas ao apresentar a redução. Não diminua a cobertura nem desative categorias para obter uma contagem menor.

### `PanelWindow` e metadados

O `PanelWindow` público pode ser resolvido pelo tooling como a interface não instanciável de `Quickshell._Window`, enquanto o runtime seleciona uma implementação da plataforma. Isso pode gerar `Type PanelWindow is not creatable. [uncreatable-type]` em código válido. A documentação do Quickshell registra limitações de resolução de `PanelWindow` no language server:

https://quickshell.org/docs/v0.3.2/guide/install-setup/

Não assuma que todo aviso dessa categoria seja falso. Confira os imports, os `.qmltypes` da versão instalada e um exemplo mínimo. Confirme no Wayland com uma janela oculta isolada, sem carregar a barra de produção. Se o exemplo carregar, os testes pertinentes passarem e os logs estiverem saudáveis, relate a limitação do tooling e preserve o componente. Não altere metadados em `/usr/lib`, troque o backend nem adicione supressões apenas para zerar o lint. Não fixe na skill uma quantidade de avisos: ela varia com código e dependências.

Em uma revisão ampla, registre quais componentes produzem os avisos e compile esses componentes no runtime. Compilar com `Qt.createComponent` não instancia os serviços do painel; isso e uma janela oculta validam resolução/carregamento, mas não comprovam interação de todos os painéis.

## Corrigir escopo sem mudar comportamento

- Qualifique referências de objetos externos com o ID correto, como `notifPanel.root`. Diferencie o ID externo `root` da propriedade `root` de um componente interno; a colisão pode apontar para o objeto errado.
- Use `pragma ComponentBehavior: Bound` quando componentes internos precisarem dos IDs do contexto de criação. Confira os delegates depois: papéis antes injetados implicitamente pelo modelo podem precisar de `required property var modelData` ou de `required property int index`.
- Para propriedades de componentes inline e delegates, use IDs locais claros. Não faça substituição global de identificadores sem conferir escopo, comentários, strings e handlers.
- Sugestões automáticas do lint ajudam a inserir prefixos, mas revise o diff. Offsets JSON são em unidades UTF-16; não os aplique como índices de bytes UTF-8. Inserir um ID em uma declaração de uma linha também exige separador válido.
- Preserve comandos, argumentos, guardas de visibilidade e timers. Capture dados antes de atualizar modelos que possam destruir o delegate.

## Contratos compartilhados, respostas e recursos

Ao extrair ou corrigir um painel compartilhado, confira o contrato dos roots V1 e V2. Uma propriedade presente apenas em V2, como `aiUsageReveal`, não pode ser exigida implicitamente em V1. Teste abertura/fechamento com ambos os roots e preserve o progresso da animação onde ele existe.

Valide a resposta completa utilizada antes de substituir o estado exibido. Capturar uma exceção depois de atualizar temperatura, localização ou outros campos pode deixar dados novos junto a uma previsão antiga. Cubra JSON válido com estrutura inválida, listas incompletas, entradas nulas e valores zero; não use truthiness como validação numérica.

Recursos empacotados devem resolver a partir do módulo, por exemplo `Qt.resolvedUrl("../quotes.txt")`, em vez de caminhos da instalação antiga em `~/.config/quickshell`. Preserve a mesma raiz de configuração e estrutura relativa na fixture: um recurso fora da raiz pode virar `qrc:/qs-blackhole` no scanner do Quickshell. Quando a fixture precisa de `FileView` real ou de plugins ligados ao executável Quickshell, use `qs`; `qmltestrunner` sozinho pode não carregar esses plugins.

Para limites de scanners, verifique o trabalho antes de materializar a coleção. Limitar o processamento depois de `list(os.scandir(...))` não limita a enumeração nem a memória. A regressão deve contar entradas consumidas, além dos resultados retornados.

## Escolher testes que realmente exercitem a mudança

Use fixtures já existentes e amplie-as para V1/V2 e estilos afetados. Para bindings e interação, prefira carregar o conteúdo de produção a duplicar a implementação no teste. Valide o efeito observável: valor selecionado, identidade enviada, confirmação, contagem, parada de worker e resultado tardio após fechar.

Uma fixture offscreen pode substituir a janela por um Item/Rectangle e remover propriedades de layer shell. Isso testa o conteúdo, não o backend. Quando necessário, complemente com carregamento Wayland oculto. Não inicie a barra real como probe.

Simule explicitamente Process, FileView, coletores e limites de serviço antes de instanciar painéis que consultam contas ou estado real. Estar oculto não impede `Component.onCompleted` de iniciar uma consulta. Preserve o contrato necessário dos mocks, como sinais `exited`, `started`, `streamFinished`, propriedades e métodos usados. Falha por mock incompleto não comprova defeito na produção.

Inclua efeitos secundários no isolamento. Simular pacman/sudo sem simular `notify-send` ainda pode enviar notificações reais pelo barramento herdado. Capture essas chamadas numa fixture e verifique o efeito esperado sem acessar a sessão.

Fixtures de permissões devem controlar a cadeia de confiança simulada. `/tmp` é gravável por outros usuários; diretórios reais de configuração também podem ter permissões diferentes das esperadas. Simule os metadados dos ancestrais externos à fixture, mantendo os checks reais dentro dela, inclusive a rejeição de diretórios graváveis por terceiros. Não altere permissões do usuário ou enfraqueça a validação de produção para fazer o teste passar.

Para testes headless, use runtime temporário com modo 0700, `QT_QPA_PLATFORM=offscreen`, backend software e `QT_QPA_PLATFORMTHEME=''`. Falha ao criar socket IPC sob sandbox pode ser restrição ambiental: confirme no contexto autorizado antes de modificar o código. Não ignore `ERROR` nem declare aprovação enquanto o teste estiver bloqueado.

Regressões que comparam texto exato podem exigir ajuste após qualificar referências. Preserve a intenção da asserção e mantenha validação de comportamento; não enfraqueça o teste para fazê-lo passar. Considere também diagnósticos de runtime: QtTest pode passar com `ReferenceError`, `TypeError`, `Binding loop` ou `Unable to assign` no log.

## Aplicar sem sobrescrever diferenças locais

Compare checkout, base Git e instalação. A instalação pode conter testes antigos e diferenças legítimas mesmo quando o código principal coincide. Construa patches mínimos e faça `git apply --check` no diretório da instalação, não no checkout já editado. Uma falha de contexto exige inspecionar a diferença; não copie o arquivo inteiro por conveniência.

Uma migração local pode deixar caminhos removidos no índice e arquivos novos ainda não versionados. Ao descobrir scripts para validação, considere `git ls-files --cached --others --exclude-standard` e confira se cada arquivo ainda existe. Não interprete uma diferença na contagem de QML como regressão sem comparar os arquivos. Encaminhamentos vazios antigos só devem ser removidos após conferir seus consumidores e preservar uma cópia quando houver backup.

Se um teste instalado usa o caminho antigo de um helper, corrija a fixture para uma árvore temporária que preserve os caminhos relativos de produção. Não rode o helper real para compensar um mock no lugar errado. Valide no checkout e repita na instalação os testes pertinentes que foram efetivamente atualizados.

Só reinicie depois de validar e aplicar as alterações autorizadas. Compare plugins habilitados antes/depois, consulte `omarchy-shell shell ping` e o log do PID correto. Distinga no relatório: testes simulados, carregamento nativo, saúde da sessão atual e limitações restantes. Nenhuma dessas verificações garante ausência de todo defeito futuro.

Antes de testes nativos autorizados, registre a variante e as preferências relevantes com conteúdo e hashes; guarde o snapshot fora da árvore observada. Leia o handler antes de clicar: o clique esquerdo no relógio alterna `clock12h`, não abre um calendário. Restaure mudanças feitas pelo teste e confira o estado original, preservando alterações concorrentes do usuário. Para capturas de saídas rotacionadas, prefira selecionar o output pelo nome e confira a transformação antes de usar coordenadas globais.

Em revisões com aplicação à instalação, registre arquivos alterados, backup, resultados do checkout e da instalação e saúde final da sessão. Não reutilize uma aprovação antiga da suíte como se tivesse sido executada após mudanças novas; indique quando apenas testes pertinentes foram repetidos. Mantenha a distinção entre hotplug simulado e desconexão física, sem alterar monitores reais apenas para obter evidência.
