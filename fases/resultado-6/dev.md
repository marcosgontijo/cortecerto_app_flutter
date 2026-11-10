# dev.md — FASE 6, volta 1 (exportar faturamento em CSV)

## Ponto de partida (repo / branch / HEAD)
| Repo | Branch | HEAD | Estado inicial |
|---|---|---|---|
| App `cortecerto_flutter` | `main` | `ca97ac2` | `M TAREFA.md`, `M fases/README.md`, `?? fases/FASE-6.md`, `?? .claude/skills/` (não são meus, não mexi) |
| Backend `cortecerto-backend-loop` | `loop/mobile-migration` | `b6d1fe0` | limpo. **Não editado.** Conferido no fim: HEAD `b6d1fe0`, `status --porcelain` vazio |

Não havia `.loop/feedback.md` nem `.loop/historico.md` (primeira volta).

## Mudanças

### 1. CSV como função pura — MANTER
- Hipótese: o modelo `Faturamento` já guarda centavos `int`, então o CSV só formata int → `1234,50` com `~/` e `%`, sem double.
- Arquivo: `lib/features/admin/domain/faturamento_csv.dart` (`FaturamentoCsv(faturamento, periodo)` com `texto`, `bytes` (BOM + UTF-8), `nomeArquivo`, `assunto`, `mimeType = 'text/csv'`, `valor(int)` e `campoTexto(String)` estáticos).
  - 4 blocos separados por linha em branco, toda linha termina em `\r\n` (inclusive a última), `porDia` ordenado por data (cópia), `porServico` na ordem do servidor, lista vazia → `Nenhum atendimento realizado neste período`.
  - `Período` usa `periodo.rotulo` (o mesmo texto da tela); `De`/`Até` vêm do período exibido.
  - `campoTexto`: primeiro o `'` se começar com `=`,`+`,`-`,`@`,tab,`\r`; depois aspas se tiver `;`,`"`,`\r`,`\n` (com `"` → `""`). Usado em todos os textos (rótulos fixos, rótulo do período, nome do serviço). Números e datas gerados pelo app não passam por ele (`-12,50` continua sem `'`).
  - Nome: Dia `faturamento_yyyy-MM-dd.csv`, Semana `faturamento_<ini>_a_<fim>.csv`, Mês `faturamento_yyyy-MM.csv`.
  - Imports: só `dart:convert`, `dart:typed_data`, `core/formatters` (só `data`/`dataApi`) e o domínio. Grep `double|toStringAsFixed|NumberFormat|package:flutter/|BuildContext|dart:io` no arquivo → vazio.
- Verificação: `flutter test --no-pub test/fase6/faturamento_csv_test.dart` → **+24, All tests passed** (exit 0).

### 2. Abstração do exportador + implementação real — MANTER
- Arquivos:
  - `lib/core/compartilhamento/exportador_arquivo.dart`: `abstract class ExportadorArquivo { Future<void> compartilhar({nomeArquivo, bytes, mimeType, assunto, Rect? origem}); }`. Contrato: termina normalmente quando compartilha **ou** fecha a folha; lança em falha.
  - `lib/core/compartilhamento/exportador_share_plus.dart`: `ExportadorSharePlus` com `SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, mimeType:, name:)], fileNameOverrides: [nome], subject: assunto, title: assunto, sharePositionOrigin: origem))`. `ShareResult` success/dismissed/unavailable são ignorados (não é erro). **Único arquivo de `lib/` que importa `package:share_plus`** (`grep -rln package:share_plus lib` → só ele).
  - `lib/app.dart`: `AppDependencies` ganhou parâmetro **opcional** `ExportadorArquivo? exportador` (padrão `const ExportadorSharePlus()`) e `Provider<ExportadorArquivo>.value(...)` no `MultiProvider`. Opcional para não quebrar os testes que constroem `AppDependencies(...)` diretamente.
- Por que **sem `path_provider`**: com `XFile.fromData` o próprio `share_plus` grava a cópia temporária (`method_channel_share.dart` do `share_plus_platform_interface` 7.2.0 usa `getTemporaryDirectory()` internamente e aplica `fileNameOverrides`). O app não importa `path_provider`.

### 3. Ação "Exportar CSV" na tela — MANTER
- Arquivo: `lib/features/admin/presentation/faturamento_page.dart`.
  - `AppBar.actions`: `IconButton` (Key `faturamento-exportar`, `tooltip: 'Exportar CSV'`, `Icons.file_download_outlined`, 48dp padrão) dentro de um `Builder` para pegar o retângulo do botão (`sharePositionOrigin` no iPad).
  - Habilitada só se `!_exportando && !c.isLoading && c.erro == null && c.faturamento != null` (cobre carregando, refresh do mesmo período com dados antigos, erro de refresh com dados antigos, troca de período em andamento e toque duplo). Não exigi `faturamento.inicio == periodo.inicio` porque o controller já descarta respostas antigas (`_requisicao`) e zera `_faturamento` ao trocar de período.
  - `_exportar`: tira o "retrato" (`FaturamentoCsv(c.faturamento!, c.periodo)`) no toque, `_exportando = true`, lê `context.read<ExportadorArquivo>()` **só no toque** (dentro do try), chama `compartilhar`; qualquer exceção → `mostrarFeedback(context, 'Não foi possível exportar o faturamento', erro: true)` (Key `snack-erro`); `finally` volta `_exportando = false`. Nenhuma nova chamada à API.
  - Ler o provider só no toque evita `ProviderNotFoundException` nos 14 testes de `test/fase5/faturamento_page_test.dart` e no harness de a11y, que não registram exportador; nenhum teste antigo foi alterado. Os testes de a11y (guidelines + 360×640 textScaler 2.0) passaram com a ação nova já na AppBar.
- Verificação: `flutter test --no-pub test/fase6/faturamento_exportar_test.dart` → **+12, All tests passed** (exit 0).
- Teste de mutação manual: trocando a condição por só `c.faturamento != null`, 2 testes falharam (refresh/erro de refresh e toque duplo); revertido (conferido com grep e com a suíte inteira depois).

### 4. Dependências — MANTER, MAS PRECISA DA SUA CONFIRMAÇÃO (ver Dúvidas)
- `pubspec.yaml`: `+ share_plus: ^13.3.1` e **`flutter_secure_storage: ^9.0.0` → `^10.3.1`**.
- Motivo do segundo: `flutter pub get --offline` só com `share_plus` falhou com conflito de versão (saída resumida):
  `flutter_secure_storage_windows 3.1.2 depends on win32 ^5.0.0 ... every version of share_plus depends on win32 ^6.0.1 ... share_plus is incompatible with flutter_secure_storage ^9.0.0. ... Try upgrading your constraint on flutter_secure_storage: flutter pub add flutter_secure_storage:^10.3.1`.
  O analista não tinha visto esse conflito. No cache local só existem `share_plus 13.3.1` e `flutter_secure_storage 9.2.4/10.3.1`. Opções que avaliei:
  1. **Subir `flutter_secure_storage` para 10.3.1 (escolhida)**: está no cache, não é pacote novo, a API usada (`const FlutterSecureStorage()`, `read/write/delete`) não mudou e o app continua compilando e passando nos testes. Efeito real no Android: a 10.x troca as cifras padrão (RSA OAEP + AES-GCM) e **migra sozinha** os dados antigos (`migrateOnAlgorithmChange: true` por padrão); `resetOnError` passa a ser true. Pior caso: o usuário precisa entrar de novo (o único dado guardado é o JWT `auth_token`). minSdk 23 (app usa 24) e iOS 12 (projeto usa 13): ok.
  2. `dependency_overrides: win32 ^6`: descartada. O changelog da 10.2.0 diz que a compatibilidade com o win32 6 só veio na `flutter_secure_storage_windows 4.2.0`, então isso quebraria o build Windows (o projeto tem pasta `windows/`). Seria uma gambiarra.
  3. Versão antiga do `share_plus` que aceite win32 5: não está no cache, precisaria baixar da internet (proibido nesta volta).
  `pubspec.lock`: entram `share_plus`, `share_plus_platform_interface`, `cross_file`, `url_launcher_*` (linux/web/windows/platform_interface), `uuid`, `fixnum`, `ffi_leak_tracker`, `flutter_secure_storage_darwin`; `win32` 5.15.0 → 6.4.0; saem `flutter_secure_storage_macos` e `js`. O `pub get --offline` saiu com o aviso de symlink do Windows (Modo de Desenvolvedor), que já é conhecido; o `package_config.json` foi gerado com `share_plus`.

### 5. Configuração nativa (Android) — MANTER
- `android/settings.gradle.kts`: AGP `8.11.1` → **`8.12.1`**. O README do share_plus 13.3.1 pede "Android Gradle Plugin >=8.12.1" e o `build.gradle.kts` do plugin usa `classpath("com.android.tools.build:gradle:8.12.1")`. O 8.12.1 já estava no cache do Gradle. Gradle wrapper 8.14, Kotlin 2.2.20 e Java 17 já atendiam.
- AndroidManifest do app **não mudou**: o manifesto do plugin entra pelo merge. Conferido no manifesto mesclado (`build/app/intermediates/merged_manifest/debug/.../AndroidManifest.xml`): `dev.fluttercommunity.plus.share.ShareFileProvider` (authority `com.example.cortecerto_flutter.flutter.share_provider`) e o receiver `SharePlusPendingIntent`. Nenhuma permissão de armazenamento. Aparece `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`, que é uma permissão interna de assinatura do androidx.core, não é de armazenamento.
- Verificação: `flutter build apk --debug --no-pub` → `√ Built build\app\outputs\flutter-apk\app-debug.apk` (92 s, exit 0). APK de 22:59, mais novo que o `pubspec.lock` (22:52). Só apareceu o aviso já existente sobre o Kotlin Gradle Plugin / Built-in Kotlin, que não tem a ver com esta fase.

### Verificação final (revisão atual)
- `flutter analyze --no-pub` → **No issues found!** (exit 0). Tive que tirar um `import 'dart:ui'` desnecessário do teste novo (era só um info).
- `flutter test --no-pub --exclude-tags contract` → **+555, All tests passed!** (519 antigos + 24 do CSV + 12 da tela). Depois da última limpeza (import e comentário), rodei de novo só `test/fase6` → +36.
- Backend: não editado. `rev-parse --short HEAD` = `b6d1fe0`, porcelain vazio. Não rodei o `./mvnw` (nada mudou lá; fica com o gate/tester).
- Contrato (`--tags contract`) não rodado por mim (precisa do backend na 18080; fica com o gate).

## Itens do feedback resolvidos e não resolvidos
Não havia feedback (volta 1). Situação dos critérios do TAREFA:
- 1 (CSV): todos implementados e testados em `test/fase6/faturamento_csv_test.dart`.
- 2 (tela): todos implementados e testados em `test/fase6/faturamento_exportar_test.dart`. Inclui um teste extra: sem exportador registrado, aparece o SnackBar de erro em vez de a tela quebrar. Também testei que `AppDependencies.criar()` usa `ExportadorSharePlus` por padrão.
- 3 (qualidade): analyze limpo, 555 testes, a11y continua passando com a ação, build do APK ok. O gate e a contagem por arquivo ficam com o tester.

## Tentativas que falharam (para ninguém repetir)
- `flutter pub get --offline` com `share_plus ^13.3.1` e `flutter_secure_storage ^9.0.0`: conflito de `win32` (5 contra 6). Não tem saída offline sem mexer no `flutter_secure_storage` ou forçar o `win32` (ver item 4).
- Escrever o arquivo de teste por heredoc no bash falhou (`unexpected EOF while looking for matching "'"` por causa das aspas no Dart). Usei a ferramenta Write.

## Dúvidas, suposições e o que ficou sem verificar
- **Decisão que precisa da sua confirmação:** a subida de `flutter_secure_storage` 9 → 10.3.1 não estava prevista em nenhuma autorização. Só um pacote novo foi adicionado (`share_plus`), mas a dependência existente mudou de versão maior, e isso mexe em como o JWT é guardado no Android (com migração automática). Se o gate 5.a do tester exigir "dependencies só acrescentam share_plus", essa linha vai falhar. Quem decide se aceita ou se marca BLOQUEADO é o reviewer/finalizador/usuário. Para desfazer, as alternativas são: baixar uma versão antiga do share_plus compatível com win32 5 (precisa de rede) ou desistir da FASE 6 nesta forma.
- Não verificado (fora do alcance do loop): a folha de compartilhamento real no aparelho, o arquivo abrindo no Excel pt-BR, WhatsApp/Drive, o comportamento no iPad e a migração real do token do `flutter_secure_storage` 10 num aparelho que já tinha o app 9.x instalado.
- Não sei se o build Gradle acessou a rede: terminou sem erro e tudo o que era necessário estava no cache, mas não monitorei a rede.
- O assunto/título da folha é `Faturamento CorteCerto - <rótulo do período>`, com hífen simples entre os dois e o travessão do próprio rótulo na semana.
- Escolhi o ícone `Icons.file_download_outlined` (outlined, como pede o MASTER.md para ícones fora da navegação).

## Decisão do usuário (registrada pelo orquestrador, 2026-11-09)
O usuário **aceitou** a troca `flutter_secure_storage ^9.0.0 → ^10.3.1` (necessária para resolver o conflito de `win32` com o `share_plus`).
O gate deve permitir em `dependencies` exatamente: `share_plus` acrescentado e `flutter_secure_storage` em `^10.3.1`; nada mais.
