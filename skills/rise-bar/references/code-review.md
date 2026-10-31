# Revisão de código, lint e regressões

## Diagnosticar antes de modificar

Conte os avisos no checkout atual, sem reutilizar totais de uma sessão anterior. Use a mesma versão, imports e opções de `qmllint` antes e depois. Registre arquivos analisados, avisos, categorias e falhas; retorno zero não significa ausência de avisos.

O runner do projeto conta linhas de console iniciadas por `Warning:`. O relatório JSON também pode incluir diagnósticos que o console não mostra. Use JSON para localizar sugestões, mas não misture as duas métricas ao apresentar a redução. Não diminua a cobertura nem desative categorias para obter uma contagem menor.

### `PanelWindow` e metadados

O `PanelWindow` público pode ser resolvido pelo tooling como a interface não instanciável de `Quickshell._Window`, enquanto o runtime seleciona uma implementação da plataforma. Isso pode gerar `Type PanelWindow is not creatable. [uncreatable-type]` em código válido. A documentação do Quickshell registra limitações de resolução de `PanelWindow` no language server:

https://quickshell.org/docs/v0.3.2/guide/install-setup/

Não assuma que todo aviso dessa categoria seja falso. Confira os imports, os `.qmltypes` da versão instalada e um exemplo mínimo. Confirme no Wayland com uma janela oculta isolada, sem carregar a barra de produção. Se o exemplo carregar, os testes pertinentes passarem e os logs estiverem saudáveis, relate a limitação do tooling e preserve o componente. Não altere metadados em `/usr/lib`, troque o backend nem adicione supressões apenas para zerar o lint. Não fixe na skill uma quantidade de avisos: ela varia com código e dependências.

## Corrigir escopo sem mudar comportamento

- Qualifique referências de objetos externos com o ID correto, como `notifPanel.root`. Diferencie o ID externo `root` da propriedade `root` de um componente interno; a colisão pode apontar para o objeto errado.
- Use `pragma ComponentBehavior: Bound` quando componentes internos precisarem dos IDs do contexto de criação. Confira os delegates depois: papéis antes injetados implicitamente pelo modelo podem precisar de `required property var modelData` ou de `required property int index`.
- Para propriedades de componentes inline e delegates, use IDs locais claros. Não faça substituição global de identificadores sem conferir escopo, comentários, strings e handlers.
- Sugestões automáticas do lint ajudam a inserir prefixos, mas revise o diff. Offsets JSON são em unidades UTF-16; não os aplique como índices de bytes UTF-8. Inserir um ID em uma declaração de uma linha também exige separador válido.
- Preserve comandos, argumentos, guardas de visibilidade e timers. Capture dados antes de atualizar modelos que possam destruir o delegate.

## Escolher testes que realmente exercitem a mudança

Use fixtures já existentes e amplie-as para V1/V2 e estilos afetados. Para bindings e interação, prefira carregar o conteúdo de produção a duplicar a implementação no teste. Valide o efeito observável: valor selecionado, identidade enviada, confirmação, contagem, parada de worker e resultado tardio após fechar.

Uma fixture offscreen pode substituir a janela por um Item/Rectangle e remover propriedades de layer shell. Isso testa o conteúdo, não o backend. Quando necessário, complemente com carregamento Wayland oculto. Não inicie a barra real como probe.

Simule explicitamente Process, FileView, coletores e limites de serviço antes de instanciar painéis que consultam contas ou estado real. Estar oculto não impede `Component.onCompleted` de iniciar uma consulta. Preserve o contrato necessário dos mocks, como sinais `exited`, `started`, `streamFinished`, propriedades e métodos usados. Falha por mock incompleto não comprova defeito na produção.

Para testes headless, use runtime temporário com modo 0700, `QT_QPA_PLATFORM=offscreen`, backend software e `QT_QPA_PLATFORMTHEME=''`. Falha ao criar socket IPC sob sandbox pode ser restrição ambiental: confirme no contexto autorizado antes de modificar o código. Não ignore `ERROR` nem declare aprovação enquanto o teste estiver bloqueado.

Regressões que comparam texto exato podem exigir ajuste após qualificar referências. Preserve a intenção da asserção e mantenha validação de comportamento; não enfraqueça o teste para fazê-lo passar. Considere também diagnósticos de runtime: QtTest pode passar com `ReferenceError`, `TypeError`, `Binding loop` ou `Unable to assign` no log.

## Aplicar sem sobrescrever diferenças locais

Compare checkout, base Git e instalação. A instalação pode conter testes antigos e diferenças legítimas mesmo quando o código principal coincide. Construa patches mínimos e faça `git apply --check` no diretório da instalação, não no checkout já editado. Uma falha de contexto exige inspecionar a diferença; não copie o arquivo inteiro por conveniência.

Se um teste instalado usa o caminho antigo de um helper, corrija a fixture para uma árvore temporária que preserve os caminhos relativos de produção. Não rode o helper real para compensar um mock no lugar errado. Valide no checkout e repita na instalação os testes pertinentes que foram efetivamente atualizados.

Só reinicie depois de validar e aplicar as alterações autorizadas. Compare plugins habilitados antes/depois, consulte `omarchy-shell shell ping` e o log do PID correto. Distinga no relatório: testes simulados, carregamento nativo, saúde da sessão atual e limitações restantes. Nenhuma dessas verificações garante ausência de todo defeito futuro.
