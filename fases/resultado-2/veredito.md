STATUS: ENTREGUE

FASE 2, volta 1. O gate congelado (`.loop/gate.frozen.sh`) terminou com exit 0. Resultados: `flutter analyze` sem nenhum issue,
`flutter test` com 128 testes passando, backend com 168 testes e 0 falhas, e o contrato rodado contra o backend real (não pulado).
O review está APROVADO, com 0 bloqueantes, 1 IMPORTANTE e 7 sugestões. Não há achado de segurança ALTA ou MÉDIA; existem 3 BAIXAS.

## Critérios de aceite (critério → evidência → OK/FALTA)

| # | Critério | Evidência | Status |
|---|---|---|---|
| 1.1 | Config única da API (`API_BASE_URL`, padrão `10.0.2.2:8080/api`), um único `Dio` com interceptor, sem `Authorization` montado na mão | `lib/core/config/api_config.dart`, `lib/core/network/api_client.dart` (único `Dio(`); `unit_extra_test: ApiConfig`, `codigo_fonte_test`, gate etapa 4 | OK |
| 1.2 | DI pelo construtor + Provider, nada instanciado dentro de controller ou widget | `lib/app.dart` (`AppDependencies`); `codigo_fonte_test` (APIs/`ApiClient(` só em `app.dart`); widget tests injetam mocks | OK |
| 1.3 | go_router com as 7 rotas nomeadas, redirect sem sessão, ADMIN → `/admin` provisório, CLIENTE barrado | `lib/core/router/`; `app_router_test`, `unit_extra_test: redirecionarPorSessao`, `fluxos_app_test: deep links`, widget test da AdminPage | OK |
| 1.4 | JWT só no secure storage, numa chave; auto-login checando `exp`; expirado → Login | `TokenStorage` (chave `auth_token`), `JwtPayload`; `unit_extra_test: TokenStorage (verifyNoMoreInteractions)`, `session_test`, `app_router_test: expirado` | OK |
| 1.5 | 401 global limpa a sessão + "Sessão expirada, faça login novamente" | `auth_interceptor.dart` → `SessionController.expirar`; `app_router_test: 401`, `fluxos_app_test: 401 no meio do fluxo` (3) | OK |
| 1.6 | Logout apaga a mesma chave e volta ao Login | `unit_extra_test: TokenStorage`, `fluxos_app_test: logout` (Serviços/Produtos/Agendamento/Admin) | OK |
| 1.7 | Classe central DioException → erro de domínio (400 por campo, 401, 409, 423, 429, timeout) | `lib/core/errors/api_exception.dart`; `api_error_mapper_test`, `unit_extra_test: ApiErrorMapper` | OK |
| 1.8 | Sem vazamento de token, senha ou CPF em print/log | `codigo_fonte_test`, gate 4.1, `ApiException.toString` sem dados; review confirmou | OK |
| 2.1 | Login: máscara, só dígitos, vazios, 401/423/429, loading, link para o Cadastro | `auth_pages_test: LoginPage` (5), `fluxos_app_test: Login` (6, não navega quando falha) | OK |
| 2.2 | Cadastro: 7 campos, validações, 400 embaixo de cada campo, 409, sucesso → "Cadastro realizado" | `validators_test`, `auth_pages_test: CadastroPage`, `fluxos_app_test: Cadastro` (erro dentro do campo certo) | OK |
| 2.3 | Serviços: saudação, lista, carregando/vazio/erro com "Tentar novamente", seleção → Agendamento | `cliente_pages_test: ServicosPage` (4), `fluxos_app_test` | OK |
| 2.4 | Agendamento: `table_calendar` sem passado, `disponibilidades?data=`, 409 com aviso e recarga, 400 com a mensagem do backend | `cliente_pages_test: AgendamentoPage`, `fluxos_app_test: Agendamento` (409 → 2ª chamada), `unit_extra_test` | OK |
| 2.5 | Confirmado: resumo dd/MM/aaaa, "Voltar aos serviços", nunca vai ao Login | `cliente_pages_test: AgendamentoConfirmadoPage`, `fluxos_app_test` (30 s simulados sem redirecionar) | OK |
| 2.6 | Produtos: Pomada 25 / Shampoo 30 / Pente 10, seleção múltipla e total, acessível pelos Serviços, sem checkout | `cliente_pages_test: ProdutosPage`, `controllers_test: ProdutosController`, `fluxos_app_test` | OK |
| 3.1 | V5 com os 5 serviços, idempotente; testes da FASE 1 passando | `V5__seed_servicos.sql`, `MigrationV5SeedServicosTest` (4), `./mvnw -B clean test` = 168/0, contrato confere os 5 nomes | OK |
| 4.1 | Unitários (validadores, mapper, `exp`, controllers) | `validators_test`, `api_error_mapper_test`, `session_test`, `controllers_test`, `unit_extra_test` | OK |
| 4.2 | Widget tests das 7 telas | `auth_pages_test`, `cliente_pages_test`, `fluxos_app_test` | OK |
| 4.3 | Testes de rota (sem token, expirado, CLIENTE, ADMIN, CLIENTE em /admin, 401) | `app_router_test`, `fluxos_app_test`, `unit_extra_test` | OK |
| 4.4 | Contrato em `test/contract` (tag, variável de ambiente, skip) | `fluxo_cliente_contract_test.dart`; o gate sobe o backend real e o teste passa (`+1`); o gate falha se o teste for pulado | OK |
| 4.5 | `flutter analyze` limpo e `flutter test` passando | gate congelado: "No issues found!" e "+128: All tests passed!" | OK |

## Pendências para a próxima volta
Não há pendências que bloqueiem esta fase. Recomendo fazer o que vem abaixo no **início da FASE 3**:
1. [IMPORTANTE, do review] Os controllers (`servicos_controller.dart`, `agendamento_controller.dart`, `login_controller.dart`, `cadastro_controller.dart`)
   chamam `notifyListeners()` depois do `await` sem checar se já foram descartados. Isso dispara uma assertion em debug quando o usuário sai ou volta
   durante um carregamento; em release a chamada não tem efeito. Correção: um guard `_descartado` (ou um mixin comum) e um widget test que confirme que sair durante o carregamento não gera exceção.
2. Confirmado: o botão Voltar do Android fecha o app. Usar `PopScope`, que leva para `/servicos`.
3. `AuthInterceptor.isPublica`: comparar o path exato em vez de usar `endsWith`.
4. `Validators.senha`: aceitar só `[A-Za-z]` como letra, igual ao backend.
5. `AgendamentoPage._hoje`: recalcular depois da meia-noite.
6. Teste "ontem desabilitado": usar uma data fixa (`hoje:`), porque no dia 1 o teste passa sem checar nada.
7. `MigrationV5SeedServicosTest.migrationsAnterioresNaoForamAlteradas`: renomear o teste ou validar o checksum. Padronizar `fromObject` para `deErro`.

## Motivo do bloqueio
Não se aplica.
