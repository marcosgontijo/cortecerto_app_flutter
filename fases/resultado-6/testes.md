# testes.md — FASE 6, volta 1 (exportar faturamento em CSV)

## Tipo de app e ferramentas
- App **mobile Flutter** (Flutter 3.44.2 / Dart 3.12.2). Backend Spring Boot só testado (não editável nesta fase).
- Ferramentas: `flutter test` (unidade e widget, `mocktail`, harness de a11y `test/a11y/telas_harness.dart` com
  `meetsGuideline`), `flutter analyze`, `flutter build apk --debug`; backend `./mvnw -B clean test` (Java 21) e
  testes de contrato (`flutter test --tags contract`) contra o backend real na porta 18080, com SQLite temporário em `target/`.
- Segurança: busca de segredos no diff, checagens estáticas do gate (share_plus isolado, CSV puro, manifesto sem
  permissão nova). Auditoria de vulnerabilidades de pacotes pub: **não disponível offline** (ver "Não testado").

## Revisão testada
| Repo | Branch | HEAD | Estado |
|---|---|---|---|
| App `cortecerto_flutter` | `main` | `ca97ac2` + alterações sem commit do developer (lib/, pubspec.*, android/settings.gradle.kts) + testes do tester | ver `git status` abaixo |
| Backend `cortecerto-backend-loop` | `loop/mobile-migration` | `b6d1fe0` | `git status --porcelain` vazio (antes e depois do gate) |

Arquivos que **eu** criei/alterei: `test/fase6/faturamento_csv_tester_test.dart` (8 testes),
`test/fase6/faturamento_exportar_tester_test.dart` (10 testes), `.loop/gate.sh`, este arquivo.
Nenhum código de produção alterado por mim (as mutações foram todas desfeitas, conferido com `cmp` e hash do `git diff`).

**Efeito colateral do gate (importante para o reviewer):** o `flutter pub get --offline` do gate regenerou 5 arquivos
versionados que o developer tinha deixado desatualizados: `linux/flutter/generated_plugin_registrant.cc`,
`linux/flutter/generated_plugins.cmake`, `macos/Flutter/GeneratedPluginRegistrant.swift`,
`windows/flutter/generated_plugin_registrant.cc`, `windows/flutter/generated_plugins.cmake` (entram `share_plus`/
`url_launcher_*`; `flutter_secure_storage_macos` vira `flutter_secure_storage_darwin`). São gerados pelo Flutter a partir
do pubspec e precisam ir junto na entrega (sem eles os builds desktop não teriam o plugin). O gate passou a aceitar
exatamente esses 5 nomes no escopo e confere (6.f) que estão coerentes com o pubspec.

## Resultado do gate
`GATE_PORTA=18080 bash .loop/gate.sh` → **GATE: PASSOU** (exit 0), terceira execução. Números:
- `flutter pub get --offline` ok; `flutter analyze` **No issues found!**
- `flutter test --exclude-tags contract`: **573 passaram, 0 pulados, 0 falhas** (mínimo 573 = 519 + 36 developer + 18 tester);
  fora de fase4/fase5/fase6/a11y: **285** (mín. 285); a11y 67; fase4 42/22/48; fase5 14/8/11/7/5/10;
  fase6 24/12/8/10 (todos no mínimo).
- Backend `./mvnw -B clean test`: **265, 0 falhas, 0 erros, 0 pulados**; mínimos por classe ok.
- Contrato com backend real na 18080: **4 de 4** (banco temporário, V6 aplicada, sem segredo no log); porta 18080 livre no fim.
  A 8080 (backend da IDE) não foi tocada.
- Backend: HEAD `b6d1fe0`, porcelain vazio; `data/cortecerto.db` com sha256 igual antes/depois.
- `flutter build apk --debug --no-pub`: **Built build\app\outputs\flutter-apk\app-debug.apk** (APK gerado na execução;
  manifesto mesclado com `dev.fluttercommunity.plus.share.ShareFileProvider` e sem permissão de armazenamento).

Execuções anteriores do gate (falhas que vieram do próprio gate, já corrigidas):
1. `4.16 escopo` falhou com os 5 registrants gerados (ver acima) → passaram a ser permitidos por nome + checagem 6.f.
   `9. manifesto mesclado` falhou porque o Gradle não regera o manifesto num build incremental (exigi "mais novo que o
   início da etapa") → agora exige "mais novo que `pubspec.lock` e `settings.gradle.kts`".
2. `6.f` falhou para Linux (no Linux o share_plus é só Dart; o plugin nativo é o `url_launcher_linux`) → ajustado.

## Critério de aceite → teste → defeito que pega → resultado
Arquivos: `csv` = `test/fase6/faturamento_csv_test.dart` (developer), `csvT` = `test/fase6/faturamento_csv_tester_test.dart`,
`exp` = `test/fase6/faturamento_exportar_test.dart` (developer), `expT` = `test/fase6/faturamento_exportar_tester_test.dart`.

| # | Critério | Teste(s) | Defeito que pega | Resultado |
|---|---|---|---|---|
| 1.1 | CSV é função pura | gate 6.b (grep sem `package:flutter/`, `BuildContext`, `dart:io`, `dart:ui`, `double`, `NumberFormat`); testes em `test()` | CSV dependente de widget/I-O ou com ponto flutuante | PASSOU |
| 1.2 | Cabeçalho (Período = rótulo da tela, De/Até) | csv "Dia/Semana/Mês", csvT "fevereiro bissexto", "semana que cruza o mês" | rótulo diferente da tela, De/Até trocados, datas fora de dd/MM/yyyy | PASSOU |
| 1.3 | 4 blocos na ordem com linha em branco | csv "Dia: 4 blocos", csvT "estrutura fechada" (colunas por linha: 1,2,4,0,3,3,3,0,3...) | bloco faltando/fora de ordem, linha extra, coluna a mais | PASSOU |
| 1.4 | Resumo | csv "Dia", "por serviço vazio"; csvT "do JSON da API" | recebido/previsto trocados, quantidade errada | PASSOU |
| 1.5 | Por dia: todos os dias, zero incluído, ordem de data | csv "Semana" (7), "Mês" (30), "fora de ordem"; csvT "fevereiro bissexto" (29), "determinístico" | dia zerado omitido, sem ordenação, ordenação in-place que mexe na lista da tela | PASSOU |
| 1.6 | Por serviço na ordem do servidor; vazio → linha fixa | csv "mantém a ordem", "por serviço vazio" | reordenar por nome; bloco vazio sem a frase | PASSOU |
| 1.7 | Números `1234,50` sem milhar e sem float | csv "centavos → vírgula", "do texto da API"; csvT "do JSON da API", "números e datas... nunca com '.' nem apóstrofo" (até 1.234.567.890,12 → `1234567890,12`) | separador de milhar, `0,5` sem zero, `'` em número, double | PASSOU |
| 1.8 | Escape `;` `"` `\r` `\n` | csv "; e \"", "quebra de linha"; csvT "leitura de volta" (parser RFC 4180 com `;` lê 13 nomes hostis e confere 3 colunas e o texto exato) | aspas não dobradas, campo com `\r` sem aspas, coluna quebrada | PASSOU |
| 1.9 | Injeção de fórmula `=` `+` `-` `@` tab `\r` | csv (um teste por caractere + `\r` com aspas + `=1;2`); csvT "leitura de volta" (`=HYPERLINK(...)` etc.) | `'` ausente; `'` aplicado em número gerado | PASSOU |
| 1.10 | Sem dado pessoal | csvT "estrutura fechada" (contagem exata de linhas: nada além dos 4 blocos); o modelo `Faturamento` não tem campo de cliente (inspeção) | linha/coluna extra com dado não previsto | PASSOU |
| 1.11 | Nome do arquivo (3 períodos, cruza ano/mês, janeiro) | csv "Dia, Semana e Mês", "semana que cruza o ano"; csvT "semana que cruza o mês", "fevereiro bissexto" | semana com `fim` errado, mês sem zero à esquerda | PASSOU |
| 1.12 | Bytes: BOM + UTF-8, acentos | csv "bytes" (BOM, travessão `E2 80 93`, `\n` solto); csvT "BOM só uma vez" | BOM ausente/duplicado, encoding errado | PASSOU |
| 2.1 | Ação visível, tooltip, ≥ 48dp | exp "ação visível"; expT a11y 360×640 ×2.0 (principal/mês/erro): rect na tela, semântica ≥ 48×48, label/tooltip "Exportar CSV", é botão, título não fica sob a ação, `labeledTapTarget` e contraste; gate 4.15 e 6.c | ação fora da tela/sem rótulo/encolhida na escala 2.0 (o `androidTapTargetGuideline` oficial pula ações da AppBar) | PASSOU |
| 2.2 | Desabilitada carregando | exp "desabilitada enquanto carrega" | habilitar com `faturamento == null`/carregando | PASSOU |
| 2.3 | Desabilitada em erro (inclusive erro de refresh com dados antigos) | exp "desabilitada no erro", "refresh ... e no erro do refresh"; expT "Tentar novamente" | condição só `faturamento != null` | PASSOU |
| 2.4 | Desabilitada em refresh | exp "refresh do mesmo período" | idem | PASSOU |
| 2.5 | Habilitada com dados e no vazio | exp "habilitada no estado vazio" (exporta com a frase de vazio) | desabilitar no vazio | PASSOU |
| 2.6 | Exporta o que está na tela, mime, assunto, sem nova requisição | exp "toque exporta o período exibido" (bytes iguais aos do `FaturamentoCsv` do faturamento da API, `verifyNever` na API) | nova requisição, período errado, mime errado | PASSOU |
| 2.7 | Depois de navegar | exp "depois de navegar" (dia+1, semana, mês); expT "resposta atrasada do período anterior" | exportar dados/nome do período anterior | PASSOU |
| 2.8 | Período mudou e carrega → desabilitada | exp "período mudou e ainda carrega"; expT "resposta atrasada" | exportar dado velho durante a troca | PASSOU |
| 2.9 | Sem toque duplo | exp "sem toque duplo"; expT "navegar durante a exportação" (continua bloqueada mesmo com o período novo carregado; arquivo é o do toque) | duas folhas abertas; perder o retrato do toque | PASSOU |
| 2.10 | Erro → SnackBar e ação volta | exp "erro ao compartilhar", "sem exportador registrado"; expT "lança de forma síncrona", "tela fechada durante a exportação" | erro engolido, tela travada, `setState` após dispose | PASSOU |
| 2.11 | Fechar a folha não é erro | exp "sem toque duplo" (termina normal, sem snack); expT "fechar a folha" (2 exportações seguidas, nenhum SnackBar) | tratar término normal como erro | PASSOU |
| 2.12 | Abstração injetada; share_plus num único arquivo | gate 6.a (1 arquivo, fora de presentation/, implementa `ExportadorArquivo`), 6.c (`Provider<ExportadorArquivo>` em `lib/app.dart`); expT "app inteiro" (CorteCertoApp + router real + `AppDependencies(exportador: fake)` → o toque chega no fake); exp "AppDependencies usa ExportadorSharePlus por padrão" | Provider não registrado no app real (todo toque viraria SnackBar de erro em produção) | PASSOU |
| 3.3 | A11y com a ação nova | `test/a11y/acessibilidade_test.dart` 67/67 (harness monta a página real, a ação já está nela) + expT a11y (3 testes) | ação quebrando layout a 2.0 / guideline | PASSOU |
| 3.4 | Nada regrediu | gate: 573 Flutter, 285 antigos, mínimos por arquivo, 265 backend, contrato 4/4, analyze limpo | teste removido/enfraquecido | PASSOU |
| 3.5 | Nativo + build | gate 6.e (AGP 8.12.1), 6.d (manifesto do app intocado), 9 (APK gerado, ShareFileProvider mesclado, sem permissão de armazenamento) | build quebrado, permissão indevida | PASSOU |
| — | Backend intocado | gate 8 (HEAD `b6d1fe0`, porcelain vazio) | edição/commit no backend | PASSOU |
| — | Dependências | gate 5.a (dependencies = base + `share_plus ^13.3.1` + `flutter_secure_storage ^10.3.1`; dev_dependencies iguais; sem overrides/path_provider) | pacote extra ou troca não autorizada | PASSOU |
| 3.6 | Abrir no Excel pt-BR / folha real | — | — | DESCONHECIDO (não verificável aqui) |

## Controles negativos (mutação → teste que falhou → desfeito)
Script: `C:\Users\Usuario\AppData\Local\Temp\claude\9e3f5ea25985bb0e\aa4b67d2-cc1c-422a-86c6-a821ec117fd3\scratchpad\mutacoes.sh`
(log: `...\scratchpad\mutacoes.log`). Para cada mutação: aplica com `perl`, mostra o `diff`, roda `flutter test test/fase6`
(ou o arquivo indicado), restaura e confere com `cmp` contra o backup. No fim: hash de `git diff` + arquivo novo do CSV
**idêntico** ao de antes ("git diff + arquivo novo: idênticos ao estado anterior").

| # | Quebra aplicada | Testes que falharam | Restaurado |
|---|---|---|---|
| M1 | `_podeExportar` sem `!_exportando` | exp "sem toque duplo"; expT "navegar durante a exportação" | sim (cmp) |
| M2 | sem `c.erro == null` | exp "refresh ... e no erro do refresh (dados antigos)" | sim |
| M3 | sem `!c.isLoading` | exp "refresh ... e no erro do refresh" | sim |
| M4 | `if (mounted) mostrarFeedback` → `if (!mounted)` | exp "erro ao compartilhar", "sem exportador registrado"; expT "lança de forma síncrona", "tela fechada" | sim |
| M5 | `finally` sem `if (mounted)` antes do `setState` | expT "tela fechada durante a exportação" (só o teste do tester pega) | sim |
| M6 | `lib/app.dart` sem `Provider<ExportadorArquivo>.value(...)` | expT "app inteiro ... usa o exportador de AppDependencies" (só o teste do tester pega) | sim |
| M7 | fórmula sem `=` na lista | csv "começando com \"=\"", "fórmula com ;"; csvT "leitura de volta" | sim |
| M8 | `"` não vira `""` | csv "; e \""; csvT "leitura de volta" | sim |
| M9 | BOM vazio | csv "bytes"; csvT "BOM só uma vez"; exp "toque exporta o período exibido" | sim |
| M10 | ordenação in-place (`f.porDia..sort`) em vez de cópia | csvT "determinístico ... não altera a lista porDia original" (só o tester pega) | sim |
| M11 | centavos sem `padLeft(2,'0')` | 20 testes (csv, csvT, exp) | sim |
| M12 | nome da semana usa `inicio` duas vezes | csv "Dia, Semana e Mês", "semana que cruza o ano"; csvT "cruza o mês"; exp "depois de navegar" | sim |
| M13 | `\r` não força aspas | csv "começando com \\r"; csvT "leitura de volta" | sim |
| M14 | por dia com recebido/previsto trocados | csv "Dia: 4 blocos"; csvT "do JSON da API" | sim |

Trecho (M6):
```
[M6] quebra aplicada em lib/app.dart:
103d102
<         Provider<ExportadorArquivo>.value(value: deps.exportador),
app inteiro (injeção em lib/app.dart) ADMIN em /admin/faturamento: o toque usa o exportador de AppDependencies [E]
[M6] RESULTADO: testes FALHARAM (bom)
[M6] restaurado (cmp idêntico ao backup)
```

Controles negativos do próprio gate (trecho estático extraído para `...\scratchpad\estatica6.sh`, arquivos restaurados com `cmp`):
- G1 `import 'package:share_plus/share_plus.dart';` na página → `FALHA [6.a share_plus] 2 arquivo(s)`.
- G2 `import 'package:flutter/material.dart';` no CSV → `FALHA [6.b CSV puro]`.
- G3 `double`/`100.0` no CSV → `FALHA [6.b CSV puro]`.
- 5.a (função `secao` do gate, `...\scratchpad\teste5a.sh`): pubspec atual PASSA; `+ path_provider` FALHA;
  `flutter_secure_storage ^11` FALHA; `dio` removido FALHA; comentário no fim da linha PASSA.
- Gate rodado de verdade falhou nas 2 primeiras execuções por motivos reais de medição (registrants e manifesto), ou seja,
  as etapas novas (4.16, 6.f, 9) são capazes de falhar.

## Falhas
Nenhuma falha na revisão atual. Reproduzir tudo: `GATE_PORTA=18080 bash .loop/gate.sh`.
Só a FASE 6: `flutter test --no-pub -r expanded test/fase6/` → `+54: All tests passed!`.

## Achados (defeitos/riscos) e segurança
- **MÉDIA (entrega incompleta, já corrigida pelo efeito do gate):** os 5 registrants de plugin versionados de
  Linux/macOS/Windows estavam desatualizados no working tree do developer (no início desta volta, `git status -- linux
  macos windows` estava limpo; causa provável: o `pub get --offline` do developer saiu no erro de symlink antes de
  regenerá-los. Não confirmado).
  O `flutter pub get --offline` do gate os regenerou; o reviewer deve conferir que entram na entrega
  (`git diff -- linux macos windows`).
- **BAIXA (segurança, aceito pelo usuário):** `flutter_secure_storage` 9 → 10.3.1 muda as cifras no Android e passa a
  usar `resetOnError: true`: se a migração falhar num aparelho, o JWT é apagado e o usuário precisa entrar de novo.
  Não verificável sem aparelho com a versão anterior instalada.
- **BAIXA:** proteção de fórmula cobre exatamente a lista da TAREFA (`=`,`+`,`-`,`@`,tab,`\r`). Não cobre `\n` no início
  nem espaço antes de `=` (o Excel não avalia esses casos como fórmula; LibreOffice também não por padrão). Fora do pedido.
- **BAIXA:** o `'` de proteção aparece como caractere visível em alguns leitores (Google Sheets importando CSV, por exemplo).
  É o comportamento pedido pela TAREFA.
- Sem segredo no diff (busca por chaves privadas, AKIA, ghp_, secret/password/senha literais: só a string de teste
  `=HYPERLINK("http://x";...)`). share_plus isolado num arquivo; nenhuma permissão de armazenamento no manifesto mesclado;
  o arquivo vai pelo cache do app (`cache/share_plus`, FileProvider do plugin). Sem dado pessoal no CSV.
- Gate: `grep` da saída do mvnw passou a usar `-a` (antes imprimia "Binary file (standard input) matches"; cosmético).

## Mudanças no gate em relação a `fases/resultado-5/gate.frozen.sh` (origem dos limiares)
- `flutter pub get` → `flutter pub get --offline` (TAREFA: nada de requisição externa).
- Total Flutter ≥ **573** (519 da FASE 5 + 54 contados agora na volta 1); ≥ 285 fora de fase4/fase5/fase6/a11y (baseline
  contexto.md 5.1); mínimos FASE 4/5 iguais ao gate da FASE 5; FASE 6 por arquivo 24/12/8/10 (contagem da volta 1).
- 4.16: base `ca97ac2` (contexto.md); `lib/features/admin/**`, `lib/core/**`, `lib/app.dart`, `android/settings.gradle.kts`
  (TAREFA) + os 5 registrants gerados; rotas/app_router/admin_agendamento_api só acréscimos; 6.d manifesto do app intocado.
- 5.a: dependencies = base + `share_plus ^13.3.1` + `flutter_secure_storage ^10.3.1` (decisão do usuário no dev.md);
  dev_dependencies iguais; sem `dependency_overrides`, sem `path_provider`; `share_plus` no lock.
- Novas 6.a/6.b/6.c/6.e/6.f (ver cabeçalho do gate).
- 8: backend **intocado**: HEAD == `b6d1fe0` (o `.loop/backend-head-inicial.txt` tem que dizer isso) e porcelain vazio
  (substitui a checagem "HEAD + V1-V5" da FASE 5, em que o backend era editável).
- 9 (nova): `flutter build apk --debug --no-pub` + manifesto mesclado (≈ 15 s incremental; ≈ 90 s do zero).
- O gate leva cerca de 5 a 6 minutos no total.

## O que NÃO foi possível testar
- Folha de compartilhamento real (Android/iOS), WhatsApp/e-mail/Drive, abrir o arquivo no **Excel pt-BR** e no Sheets
  (reconhecimento de `;`, vírgula decimal, datas e acentos pelo BOM): exige aparelho e pessoa. Os testes só provam o
  texto/bytes e que o exportador foi chamado com eles.
- Popover no iPad (`sharePositionOrigin`): só se prova que um retângulo não nulo é passado.
- Migração do token do `flutter_secure_storage` 9 → 10 num aparelho com o app antigo instalado.
- Builds desktop (Windows/Linux/macOS) com os registrants novos: não rodados (fora do alvo da fase).
- Auditoria de vulnerabilidades dos pacotes pub (não há `pub audit` offline; requisição externa proibida).
- Se o Gradle acessou a rede no build do APK: não monitorado (terminou com tudo em cache, ≈ 12 s incremental).
- Avaliação visual (ícone `file_download_outlined` na AppBar, alinhamento com o MASTER.md, contraste percebido): só uma
  pessoa olhando a tela aprova; os testes cobrem só o guideline automático de contraste e o tamanho de toque.

## Proposta de mudança no gate
Não há `gate.frozen.sh` ainda (o orquestrador copia este `gate.sh` na primeira vez). Nada a propor.
