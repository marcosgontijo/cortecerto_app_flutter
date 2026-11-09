APROVADO

# Review — FASE 2, volta 1 (reviewer)

## Verificação independente
- `bash .loop/gate.frozen.sh` rodado por mim: **EXIT 0 (GATE: PASSOU)**. `flutter analyze`: no issues; `flutter test --exclude-tags contract`: 128 passaram;
  checagens estáticas OK (1 `Dio(` em `api_client.dart`); backend `./mvnw -B clean test`: 168 testes, 0 falhas; contrato contra backend real: `+1` (não pulado);
  porta 8080 livre depois (conferido com `netstat`).
- Backend (`cortecerto-backend-loop`, desde `325962e`): só `V5__seed_servicos.sql` + `fase2/MigrationV5SeedServicosTest.java` (untracked). Nada em `web/`,
  nenhuma regra de segurança alterada. V5 idempotente (`INSERT ... SELECT ... WHERE NOT EXISTS`), V1..V4 intocadas.
- Critérios conferidos no código (não só nos testes):
  - Login só navega em sucesso: `LoginController.entrar` só chama `session.iniciar` após 200 com token; a navegação é feita pelo redirect.
  - Redirect: sem sessão → `/login`; `restaurar()` lê `exp` (token malformado/sem exp/expirado → apaga e vai ao Login; `tryParse` captura tudo, inclusive RangeError);
    CLIENTE em `/admin` → `/servicos`; ADMIN restrito a `/admin`; deep links para `/agendamento`/`/confirmado` sem `extra` → `/servicos`.
  - 401 global: interceptor ignora `/clientes/login|register`; `expirar()` só age se autenticada (sem loop no Login); mensagem exata do TAREFA.
  - Logout/expirar/restaurar apagam a mesma chave `auth_token` usada no `saveToken`.
  - Erros 400 por campo: chaves do backend (`nome`, `telefone`, `cpf`, `email`, `dataNascimento`, `senha`, `confirmarSenha`) = `campo` de cada `TextFormField`
    em `cadastro_page.dart`; somem ao editar.
  - 409 no agendamento: aviso + `_carregarHorarios()`; 400 → mensagem do backend.
  - Datas: `table_calendar` com `firstDay = hoje` (local); dia normalizado para `DateTime` local e enviado com `DateFormat('yyyy-MM-dd')` — sem `toIso8601String`/UTC.
    Confirmado com `dd/MM/yyyy`, sem timer para o Login.
  - DI: único `ApiClient` em `AppDependencies.criar`; APIs recebem o client por construtor; controllers criados pelo `ChangeNotifierProvider` da rota com
    `ctx.read<Api>()` (descartados pelo Provider ao sair da rota); `_router.dispose()` no `dispose` do app.
  - Segurança: JWT só no `flutter_secure_storage`; nenhum `print`/`debugPrint`/log; `ApiException.toString` sem dados; cleartext só no source set `debug` e só
    `10.0.2.2`/`localhost`/`127.0.0.1`; INTERNET no main.
  - O nome `deDioException` não é truque contra o gate: o regex do gate (`(^|[^A-Za-z0-9_])Dio\s*\(`) já não pegaria `fromDio(`; o nome segue a convenção em português.
    Não há `Dio` criado por outra forma (`Dio.new`, etc.).
  - Código morto do app antigo removido (`core/auth`, `core/domain`, `core/storage`, `register_page`, `servico_selecionado_controller`, modelos de disponibilidade).
  - Escopo: só o `/admin` provisório da FASE 3; nada de Agenda Admin/CRUD/Meus Agendamentos; web intocado.
- Testes: provam comportamento (app inteiro com router real + Dio real sobre `FakeHttpAdapter`, contrato com backend real, 401 no meio do fluxo,
  409 com 2ª chamada de disponibilidades, erro dentro do campo certo). O contrato não pode ser pulado em silêncio no gate (checa `~N` e `+N`).

## Achados

[IMPORTANTE] lib/features/servicos/presentation/servicos_controller.dart:35-36, lib/features/agendamento/presentation/agendamento_controller.dart:86-87 e :107-109, lib/features/auth/presentation/login_controller.dart:38-40, lib/features/auth/presentation/cadastro_controller.dart:48-50 — os controllers chamam `notifyListeners()` no `finally` depois de um `await` de rede sem checar se já foram descartados. Ex.: tocar em "Sair" enquanto os serviços carregam, ou voltar da tela de Agendamento enquanto os horários (ou a recarga do 409) estão em andamento → a rota sai, o Provider faz `dispose()` no controller e, quando a resposta chega, `notifyListeners()` dispara a assertion "A XController was used after being disposed" (erro não tratado em debug; em release vira no-op). O teste do tester só cobre o caso do 401, em que o descarte acontece depois. — Adicionar `bool _descartado = false;` + `@override void dispose() { _descartado = true; super.dispose(); }` e um `_notificar()` que só chama `notifyListeners()` se `!_descartado` (ou um mixin comum); incluir um widget test "logout/voltar durante o carregamento não gera exceção" (`tester.takeException()` nulo).

[SUGESTÃO] lib/features/agendamento/presentation/agendamento_page.dart:43 — `context.goNamed(confirmado)` troca a pilha inteira (Serviços → Agendamento) só pelo Confirmado; o botão Voltar do Android fecha o app em vez de voltar. — Usar `PopScope(canPop: false, onPopInvokedWithResult: ... goNamed(servicos))` no Confirmado, ou deixar Serviços na base da pilha.

[SUGESTÃO] lib/core/network/auth_interceptor.dart:22-25 — `isPublica` usa `endsWith('/clientes/login')`; uma rota futura que termine assim seria tratada como pública (sem token e sem 401 global). — Comparar o path exato (relativo à `baseUrl`) com o conjunto `rotasPublicas`.

[SUGESTÃO] lib/core/validators/validators.dart:51 — a senha aceita `À-ÿ` como letra (inclui `×`/`÷`), mas o backend exige `[A-Za-z]`; `éééé1234` passa no app e volta 400. — Usar `[A-Za-z]`, como o backend.

[SUGESTÃO] lib/features/agendamento/presentation/agendamento_page.dart:34-36 — `_hoje` é calculado só no `initState`; com a tela aberta depois da meia-noite, o dia anterior continua selecionável (o backend recusa com 400, então não quebra). — Recalcular em `build` ou validar no `selecionarDia`.

[SUGESTÃO] test/tester/fluxos_app_test.dart:341-350 — o teste "dia de ontem fica desabilitado" só verifica algo quando ontem está no mesmo mês; no dia 1 ele passa sem checar nada. — Usar `AgendamentoPage(hoje: ...)` com uma data fixa no meio do mês (o parâmetro já existe).

[SUGESTÃO] cortecerto-backend-loop/src/test/java/br/com/ninodev/cortecerto/fase2/MigrationV5SeedServicosTest.java (`migrationsAnterioresNaoForamAlteradas`) — só confere que os arquivos V1..V4 existem; o nome diz mais do que o teste prova (quem garante o checksum é o Flyway nos outros testes). — Renomear ou validar o checksum via `flyway.info()`.

[SUGESTÃO] lib/core/errors/api_exception.dart:60 — `fromObject` (inglês) ao lado de `deDioException` (português). — Padronizar o nome (ex.: `deErro`).
