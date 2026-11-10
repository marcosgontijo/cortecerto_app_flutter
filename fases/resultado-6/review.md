APROVADO

## Revisão analisada (branch / HEAD de cada repositório)
- App `cortecerto_flutter`: branch `main`, HEAD `ca97ac2` + alterações sem commit: `M android/settings.gradle.kts`, `M lib/app.dart`,
  `M lib/features/admin/presentation/faturamento_page.dart`, `M pubspec.yaml`, `M pubspec.lock`, 5 registrants desktop
  (`linux/flutter/generated_plugin_registrant.cc`, `linux/flutter/generated_plugins.cmake`, `macos/Flutter/GeneratedPluginRegistrant.swift`,
  `windows/flutter/generated_plugin_registrant.cc`, `windows/flutter/generated_plugins.cmake`), novos `lib/core/compartilhamento/{exportador_arquivo,exportador_share_plus}.dart`,
  `lib/features/admin/domain/faturamento_csv.dart`, `test/fase6/` (4 arquivos). Documentação (`TAREFA.md`, `fases/README.md`, `fases/FASE-6.md`, `.claude/skills/`) já estava assim antes da volta.
  Nenhum arquivo de teste antigo foi alterado (`git diff ca97ac2 --stat -- test` vazio).
- Backend `cortecerto-backend-loop`: `loop/mobile-migration`, HEAD `b6d1fe0`, sem alterações (segundo o gate, conferido depois do mvnw).
- Revisei o diff e os arquivos novos antes de ler dev.md/testes.md. O que eles dizem bate com o diff.

## Achados
Nenhum BLOQUEANTE nem IMPORTANTE. Conferi especificamente:

- **Formato do CSV (DEMONSTRADO):** rodei uma sonda (`dart run` com o package_config do app) sobre `FaturamentoCsv`. Saída: bytes começam com `239,187,191`;
  `\r\n` em todas as linhas, inclusive a última; `123456789` centavos -> `1234567,89` (sem milhar), `5` -> `0,05`, `-50` -> `-0,50` (sem apóstrofo);
  `Corte "Premium"; barba` -> `"Corte ""Premium""; barba"`; `-` -> `'-`; vazio continua vazio; semana 29/12/2025 a 04/01/2026 ->
  `faturamento_2025-12-29_a_2026-01-04.csv` e `Período;29/12/2025 – 04/01/2026`. Só aritmética inteira (`~/`, `%`, `padLeft`). `porDia` é ordenado
  numa cópia, e `porServico` mantém a ordem do servidor. Ordem dos 4 blocos e linhas em branco como pede o TAREFA.
- **Habilitar a ação:** `!_exportando && !c.isLoading && c.erro == null && c.faturamento != null`. Li o controller: troca de período zera
  `_faturamento` e respostas antigas são descartadas por `_requisicao`, então `c.periodo` e `c.faturamento` não ficam dessincronizados quando a
  condição é verdadeira. O retrato do CSV é tirado no toque. Toque duplo no mesmo frame é barrado pela guarda síncrona no começo de `_exportar`.
  SnackBar via `mostrarFeedback(... erro: true)` com `mounted`. Término normal (dismissed/unavailable) não é erro.
- **DI / share_plus:** `share_plus` só é importado em `lib/core/compartilhamento/exportador_share_plus.dart`. `Provider<ExportadorArquivo>` em `lib/app.dart`,
  lido só no toque (os testes antigos sem o provider continuam passando). `mimeType` = `text/csv`, `fileNameOverrides` com o nome do período, `subject`/`title` com o rótulo.
- **Dependências/nativo:** `share_plus ^13.3.1` (permitido) e `flutter_secure_storage ^9 -> ^10.3.1` (decisão do usuário registrada no dev.md).
  O lock bate com isso: entram as transitivas do share_plus (url_launcher_*, cross_file, uuid, fixnum, ffi_leak_tracker), `win32` 5 -> 6,
  `flutter_secure_storage_macos` -> `_darwin`, sai `js`. Os 5 registrants desktop são arquivos gerados e versionados no repo (`git ls-files`). As mudanças
  são exatamente o que o `pub get` produz com esse pubspec, então são esperadas e devem ir na entrega. O do iOS é ignorado pelo `ios/.gitignore`.
  AGP 8.11.1 -> 8.12.1 é o que o README do share_plus 13.3.1 exige. O AndroidManifest do app não mudou.
- **A11y/tokens:** `IconButton` com `tooltip` (rótulo semântico), 48dp padrão, ícone outlined, sem cor fixa nem `fontSize` no diff. O harness de a11y passa.
- **Testes não enfraquecidos:** nenhum teste antigo foi tocado. Os testes novos verificam os bytes exatos contra `FaturamentoCsv`, `verifyNever` na API, troca de
  período, toque duplo com Completer, setState depois de dispose e injeção no app inteiro. As mutações do tester (M1–M14) mostram que eles pegam defeitos.
  `.loop/gate.sh` é idêntico a `.loop/gate.frozen.sh`. O gate mantém os mínimos das fases anteriores e acrescenta 573 no total, 6.a, 6.e, 6.f e o build do APK.

[SUGESTÃO] O `catch (_)` genérico também esconde erro de programação (ex.: `ProviderNotFoundException`)
- Local: lib/features/admin/presentation/faturamento_page.dart (bloco `catch (_)` de `_exportar`)
- Gatilho: o exportador deixa de ser registrado no `MultiProvider`
- Esperado x obtido: falha visível em desenvolvimento x só o SnackBar genérico aparece (o teste "sem exportador registrado" até fixa esse comportamento)
- Evidência: DEMONSTRADO (lido no código e no teste). A regressão real já é coberta pelo teste do tester "app inteiro" (mutação M6)
- Impacto: baixo, porque o teste de injeção pega a falha
- Menor correção segura: opcional, `assert`/`debugPrint` do erro em modo debug (o projeto proíbe `print`). Não é necessário para esta fase.

[SUGESTÃO] Proteção de fórmula limitada à lista do TAREFA
- Local: lib/features/admin/domain/faturamento_csv.dart (`campoTexto`)
- Gatilho: nome de serviço `' =1+1'` ou `'\n=cmd'`
- Esperado x obtido: sai sem `'`, o que está conforme o TAREFA. O Excel não avalia esses casos como fórmula
- Evidência: DEMONSTRADO (sonda)
- Impacto: nenhum conhecido no Excel. Registro só para quem for ampliar a regra no futuro
- Menor correção segura: nenhuma agora (fora do pedido).

[SUGESTÃO] `name:` no `XFile.fromData` é redundante (o plugin usa `fileNameOverrides`). É inofensivo, e o comentário do próprio arquivo já explica.

## Limites da revisão
- **Executado por mim, na revisão atual:** `flutter analyze --no-pub` -> No issues found; `flutter test --no-pub --exclude-tags contract` -> +573, All tests passed;
  a sonda do CSV acima (arquivo temporário no scratchpad, fora do repo).
- **Observação de processo:** o `gate3.log` do tester (23:40:36) é alguns segundos MAIS ANTIGO que o mtime de `faturamento_page.dart` e `faturamento_csv.dart` (23:40:56).
  A causa provável é a restauração por cópia do script de mutação (o testes.md diz que o conteúdo foi conferido com `cmp`). Por isso reexecutei analyze e testes nesta revisão.
  O backend (`./mvnw`), o contrato e o `flutter build apk` NÃO foram reexecutados por mim. Para esses vale o log do gate do tester.
- **Só lido:** gate.frozen.sh (por amostragem das checagens 4.16, 5.a, 6.a–6.f, 8 e 9), pubspec.lock, registrants e o manifesto (pelo relato).
- **Depende de aparelho/pessoa:** folha de compartilhamento real (Android/iOS/iPad), o arquivo abrindo no Excel pt-BR/Sheets com `;`, vírgula decimal e acentos, e a
  migração do JWT do `flutter_secure_storage` 9 -> 10 num aparelho com o app antigo (pior caso: o usuário precisa entrar de novo). A aparência do ícone na
  AppBar segundo o MASTER.md precisa da aprovação visual de uma pessoa; as checagens automáticas não substituem isso.
