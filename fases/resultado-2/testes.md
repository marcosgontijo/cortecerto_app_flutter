# testes.md — FASE 2, volta 1 (tester)

## Tipo de app e ferramentas
- **App mobile Flutter** (Android alvo) + **backend Spring Boot 3.5.7 / Java 21** (SQLite + Flyway), contrato REST com JWT.
- Flutter: `flutter_test` (unit + widget), `mocktail`, `FakeHttpAdapter` (Dio real com HTTP falso), go_router real.
  Contrato: `test/contract/` (tag `contract`, Dart + Dio contra o backend real; URL por **variável de ambiente** `API_BASE_URL`, pulado sem ela).
- Backend: JUnit 5 + Flyway sobre SQLite temporário (`target/`).
- Gate: `.loop/gate.sh` (criado nesta volta; não há `gate.frozen.sh`).

## Testes adicionados pelo tester
| Arquivo | Qtde | O que cobre |
|---|---|---|
| `test/tester/unit_extra_test.dart` | 37 | `ApiConfig` (padrão `10.0.2.2:8080/api`, sem `LogInterceptor`), JWT (exp no limite, payload inválido, `sub`, UTF-8), `SessionController` (sem exp/malformado → apaga token; relógio injetado; storage quebrado não trava), `TokenStorage` com mock do `FlutterSecureStorage` (write/read/delete **só** em `auth_token`, `verifyNoMoreInteractions`), interceptor (sem token/token vazio/storage com erro → sem header; register público; 403/500 não derrubam sessão; 401 em `/agendamento` e `/disponibilidades` sim), `ApiErrorMapper` (timeouts, connectionError, SocketException, cancel, 403/404/503/418, corpo não-JSON, `errors` com null, 409 com mensagem do backend, 401/423/429 não vazam corpo cru, `toString` sem dados), tabela completa de `redirecionarPorSessao` (sem sessão / CLIENTE / ADMIN e `admin` minúsculo), rotas nomeadas, `Formatters`, APIs reais com HTTP falso (corpo do login, cadastro com 7 campos e sem `role`, `?data=AAAA-MM-DD`, corpo do agendamento, 400/409 → `ApiException`, login 200 sem token = erro), controllers (timeout/sem conexão no login, erro genérico, limpar erro por campo, recuperação do erro em Serviços). |
| `test/tester/fluxos_app_test.dart` | 25 | **App inteiro** (`CorteCertoApp` + router real + APIs reais + 1 `ApiClient` com `onUnauthorized: session.expirar`) contra backend falso: login 401/423/429/500 **fica no Login** sem "Sessão expirada" e sem `Authorization`; login OK salva token e o `GET /servicos` seguinte leva o Bearer; ADMIN → Painel → Sair; Cadastro 400 mostra o erro **dentro do campo certo** (`descendant` de `campo-cpf`/`campo-email`) e some ao editar; 409; Login → Cadastro → sucesso → Login com "Cadastro realizado"; **401 global no meio do fluxo** (em disponibilidades e no POST de agendamento) → Login com a mensagem, token apagado e **sem exceção** (controller usado após dispose); relogar após 401 limpa o aviso; hoje → `?data=` de hoje e exatamente os horários do backend; **409 faz nova chamada a disponibilidades** (2 chamadas) e o horário some; 400 mostra a mensagem do backend; sucesso → Confirmado dd/MM/aaaa, sem timer para o Login (30 s simulados) → Voltar aos serviços; ontem desabilitado; deep links (`/agendamento` e `/agendamento/confirmado` sem extra → `/servicos`, logado em `/login` → `/servicos`, ADMIN em `/produtos`/`/servicos` → `/admin`, sem sessão em `/admin`/`/produtos`/`/agendamento`/rota inexistente → `/login`, `/cadastro` público); Produtos pelos Serviços com logout; logout no Agendamento. |
| `test/tester/codigo_fonte_test.dart` | 10 | Varredura de `lib/`: exatamente 1 `Dio(` (no `ApiClient`), `Authorization`/`Bearer` só no interceptor, nenhum `print`/`debugPrint`/`log`/`LogInterceptor`, `ApiClient(`/APIs/`TokenStorage(` só instanciados em `app.dart`, `FlutterSecureStorage` só em `token_storage.dart`/`app.dart`, sem `SharedPreferences`, sem `jwt_token` nem chave literal, sem `Navigator.push`/`MaterialPageRoute`, sem `8081`/URL fixa fora do `ApiConfig`; AndroidManifest (INTERNET no main, cleartext só no debug e só `10.0.2.2`/`localhost`/`127.0.0.1`). |
| `cortecerto-backend-loop/src/test/java/.../fase2/MigrationV5SeedServicosTest.java` | 4 | V5 num banco novo: 5 serviços, 1 de cada, com descrição e preço `0.00`; banco em V4 com `Barba` já cadastrada (descrição/preço próprios) → não duplica nem altera (total 6); rodar o SQL da V5 de novo não duplica; V1..V4 presentes. |

Total Flutter (sem contract): **128 passaram** (56 do developer + 72 do tester). Backend: **168** (164 + 4).

## Critério de aceite → teste → resultado
| # | Critério | Teste(s) | Resultado |
|---|---|---|---|
| 1.1 | Config única da API (`API_BASE_URL` com padrão `10.0.2.2:8080`), um `ApiClient`/`Dio` com interceptor, ninguém cria Dio nem monta Authorization | `unit_extra: ApiConfig*`, `codigo_fonte: Dio(/Authorization/URL`, gate 4.2/4.3, `session_test: ApiClient/AuthInterceptor` | PASSOU |
| 1.2 | DI por construtor + Provider; nada de `AuthApi()`/`ApiClient()` em controller/widget | `codigo_fonte: ApiClient( e APIs só em app.dart`; todos os widget tests injetam mocks via Provider | PASSOU |
| 1.3 | go_router com as 7 rotas nomeadas; sem sessão → `/login`; ADMIN → `/admin` (provisório com nome e sair); CLIENTE não acessa `/admin` | `app_router_test` (5 casos), `unit_extra: redirecionarPorSessao (tabela)`, `fluxos_app: Rotas por deep link`, `cliente_pages_test: AdminPage` | PASSOU |
| 1.4 | JWT só no secure storage, chave única; abrir com token válido entra direto; expirado → Login | `unit_extra: TokenStorage (chave única)`, `SessionController (bordas)`, `session_test`, `app_router_test: token expirado`, `codigo_fonte: chave única/SharedPreferences` | PASSOU |
| 1.5 | 401 global → limpa sessão e Login com "Sessão expirada, faça login novamente" | `app_router_test: 401`, `fluxos_app: 401 global no meio do fluxo` (3), `unit_extra: interceptor 401/403/500` | PASSOU |
| 1.6 | Logout apaga a mesma chave e volta ao Login | `unit_extra: TokenStorage`, `fluxos_app: logout (Serviços/Produtos/Agendamento/Admin)`, `app_router_test: logout` | PASSOU |
| 1.7 | Classe central DioException → erro de domínio (400 por campo, 401, 409, 423, 429, timeout/sem conexão) | `api_error_mapper_test`, `unit_extra: ApiErrorMapper (bordas)` | PASSOU |
| 1.8 | Sem vazamento (print/log de token/senha/CPF) | `codigo_fonte: nenhum print...`, gate 4.1; `ApiException.toString` sem dados | PASSOU |
| 2.1 | Login: máscara, só dígitos, vazios, 401/423/429, botão desabilitado + loading, link Cadastro; **não navega em falha** | `auth_pages_test: LoginPage` (5), `fluxos_app: Login (app inteiro)` (6) | PASSOU |
| 2.2 | Cadastro: 7 campos, validação CPF/e-mail/senha/confirmação, erros 400 embaixo de cada campo, 409, sucesso → Login com "Cadastro realizado" | `validators_test`, `auth_pages_test: CadastroPage` (3), `fluxos_app: Cadastro (app inteiro)` (3) | PASSOU |
| 2.3 | Serviços: saudação, lista (nome/descrição/preço), carregando/vazio/erro com "Tentar novamente", seleciona → Agendamento | `cliente_pages_test: ServicosPage` (4), `fluxos_app` (navegação Serviços → Agendamento) | PASSOU |
| 2.4 | Agendamento: `table_calendar` sem passado; `disponibilidades?data=`; hoje = horários do backend; 409 → aviso + recarrega; 400 → mensagem do backend | `cliente_pages_test: AgendamentoPage` (4), `fluxos_app: Agendamento` (5), `unit_extra: disponibilidades ?data=` | PASSOU |
| 2.5 | Confirmado: resumo (serviço, dd/MM/aaaa, horário), "Voltar aos serviços", nunca manda ao Login | `cliente_pages_test: AgendamentoConfirmadoPage`, `fluxos_app: sucesso → Confirmado ... (30 s)` | PASSOU |
| 2.6 | Produtos: Pomada 25,00 / Shampoo 30,00 / Pente 10,00, seleção múltipla, total, acessível por Serviços, sem checkout | `cliente_pages_test: ProdutosPage`, `controllers_test: ProdutosController`, `fluxos_app: Produtos acessível pelos Serviços` | PASSOU |
| 3.1 | V5 com os 5 serviços, sem duplicar; testes da FASE 1 continuam passando | `MigrationV5SeedServicosTest` (4), `./mvnw -B clean test` (168), contrato confere os 5 nomes | PASSOU |
| 4.1 | Unitários: validadores, mapper, `exp` do JWT, controllers com APIs fake | `validators_test`, `api_error_mapper_test`, `session_test`, `controllers_test`, `unit_extra` | PASSOU |
| 4.2 | Widget tests de cada tela (render, loading, erro, feliz) | `auth_pages_test`, `cliente_pages_test`, `fluxos_app` | PASSOU |
| 4.3 | Testes de rota (sem token, expirado, CLIENTE, ADMIN, CLIENTE em /admin, 401 → /login) | `app_router_test`, `fluxos_app`, `unit_extra` | PASSOU |
| 4.4 | Contrato em `test/contract` (tag, env var, pulado sem ela): register → login → serviços → disponibilidades → agendar → 409 → 401 | `fluxo_cliente_contract_test.dart`, rodado pelo gate contra o backend real (gate falha se o teste for pulado): `+1: All tests passed!` | PASSOU |
| 4.5 | `flutter analyze` sem erros/warnings e `flutter test` passando | gate etapas 2 e 3: `No issues found!`, `+128: All tests passed!` | PASSOU |

## Gate (`.loop/gate.sh`)
1. `JAVA_HOME` = Corretto 21 (`/c/...` ou `/mnt/c/...`).
2. `flutter pub get`: se sair ≠ 0, só tolera quando a saída fala de symlink/Developer Mode **e** `.dart_tool/package_config.json` existe e é mais novo que o `pubspec.yaml` **e** não houve falha de resolução de versões.
3. `flutter analyze --fatal-warnings --no-fatal-infos`; `flutter test --no-pub --exclude-tags contract`.
4. Checagens: print/debugPrint/log com token/senha/CPF; qualquer `print(`/`LogInterceptor`; exatamente 1 `Dio(` (regex `(^|[^A-Za-z0-9_])Dio\s*\(`, ignora `DioException`) e no `api_client.dart`; `Authorization`/`Bearer` só no interceptor; `jwt_token`/`SharedPreferences`; AndroidManifest (INTERNET no main, cleartext só no debug e hosts locais); segredos versionados (app e `.env`/`.env.example` do backend).
5. `./mvnw -B clean test`.
6. `./mvnw -q -DskipTests package` e sobe `java -jar` com `SECURITY_JWT_SECRET_KEY` aleatória (openssl), `SPRING_DATASOURCE_URL=jdbc:sqlite:target/gate-contract-*.db`, `RATE_LIMIT_LIMITE=100000`, admin de teste com senha aleatória, porta 8080 (falha se a porta já estiver ocupada); espera `GET /api/api-docs` = 200 (120 s); roda `API_BASE_URL=http://localhost:8080/api flutter test --tags contract` (falha se o teste for pulado); confere que o log do backend não tem Bearer/senha.
7. `trap EXIT` derruba o backend (`taskkill /F /T` pelo winpid + `kill` + mata quem ficar escutando na 8080) e apaga o banco temporário; o gate falha se a porta continuar ocupada.

## Resultado do gate
`bash .loop/gate.sh` → **EXIT 0 (GATE: PASSOU)**, em 2026-11-08:
- `flutter pub get` OK (saiu 0 nesta máquina; a tolerância ao erro de symlink fica para quando ele ocorrer).
- `flutter analyze`: No issues found. `flutter test --exclude-tags contract`: 128 passaram.
- Checagens estáticas: 1 `Dio(` (api_client.dart), nenhum print/log, Authorization só no interceptor, manifests OK, sem segredos versionados.
- `./mvnw -B clean test`: 168 testes, 0 falhas (164 da FASE 1 + 4 da V5).
- Backend subiu (jar, SQLite temporário, JWT secret aleatório), `/api/api-docs` 200; contrato: 1 passou (não pulado).
- Backend derrubado: `netstat` sem LISTEN na 8080 (só um socket cliente em TIME_WAIT), nenhum `java.exe` restante, banco temporário apagado.

Primeira execução falhou por erro meu (escape inválido no teste Java novo, `illegal escape character`); corrigido e o gate foi rodado de novo do zero.

## Achados de segurança
| Severidade | Achado |
|---|---|
| — | Nenhum achado ALTO ou MÉDIO. Sem `print`/log em `lib/`; token só no `flutter_secure_storage` (`auth_token`), apagado no logout/401/expirado; `Authorization` só no interceptor e não enviado em login/register; 1 único Dio; sem `LogInterceptor`. |
| BAIXA | `AuthInterceptor.isPublica` usa `endsWith('/clientes/login')`: qualquer rota futura terminada assim seria tratada como pública (sem token e sem 401 global). Hoje não existe nenhuma. Sugestão: comparar o path exato. |
| BAIXA | `Validators.senha` aceita letras acentuadas (`À-ÿ`, que inclui `×`/`÷`) como "letra"; o backend exige `[A-Za-z]`. Ex.: `éééé1234` passa no app e volta 400 do backend (a mensagem aparece embaixo do campo, então não quebra o fluxo). Divergência de regra, não vulnerabilidade. |
| BAIXA | `fases/resultado-1/RELATORIO.md` (versionado) traz um exemplo `ADMIN_SENHA='Admin12345'` em instruções de uso. É documentação, não configuração; recomenda-se deixar claro que é só exemplo. |
| INFO | AndroidManifest: `INTERNET` no main; cleartext só no `debug` (`network_security_config` com `10.0.2.2`, `localhost`, `127.0.0.1`, sem `base-config`); release com o padrão do Android (cleartext bloqueado). O `profile` não tem cleartext (perfil de desempenho não acessa backend HTTP local — aceitável). |
| INFO | Nenhum segredo versionado no app (`.env`, keystore, `key.properties`, chaves privadas); `.env.example` do backend sem valores de segredo. Segredos de teste só existem dentro do gate (gerados na hora) e no `application-test.yml` (já existente da FASE 1, só teste). |

## Bugs procurados ativamente (todos NÃO reproduzidos)
- Login navegando em falha → não navega (401/423/429/500 no app inteiro).
- Erros 400 por campo não exibidos → aparecem dentro do campo certo e somem ao editar.
- 409 sem recarregar horários → recarrega (2ª chamada de disponibilidades confirmada).
- Datas passadas selecionáveis → desabilitadas (sem chamada à API).
- Token em log / chave inconsistente / Dio fora do ApiClient / Authorization na mão → nenhum.
- 401 durante uma ação (controller notificando após dispose) → sem exceção.
- Confirmado mandando ao Login após tempo (bug do app antigo) → não acontece.

## O que NÃO foi possível testar
- **App rodando em emulador/aparelho** e `flutter build apk` (sem emulador): `network_security_config` só verificado estaticamente; `flutter_secure_storage` real (Keystore) não exercitado — os testes usam mock/fake do plugin.
- `integration_test` em dispositivo: não há emulador; o fluxo foi coberto com widget tests do app inteiro + contrato Dart contra o backend real.
- 423/429 contra o backend real (o gate sobe com `RATE_LIMIT_LIMITE` alto para o contrato não ser bloqueado); cobertos por testes do app com HTTP falso e pelos testes da FASE 1 no backend.
- Horários "só futuros" no dia de hoje: depende do relógio do backend (fuso de São Paulo); o app só repassa a lista (testado). Já coberto no backend pela FASE 1.
- Paridade visual com o web (layout/cores): fora do alcance de testes automatizados.
