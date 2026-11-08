# Tester — FASE 1, volta 2

## Resultado
- **Gate congelado:** `bash .loop/gate.frozen.sh` (rodado da raiz do Flutter) → **código de saída 0, "GATE: PASSOU"**.
- `./mvnw -B clean test`: **164 testes, 0 falhas, 0 erros, 0 ignorados** (eram 126 depois do developer; 114 na volta 1).
- Novos nesta volta (tester), em `BE/src/test/java/br/com/ninodev/cortecerto/`:
  - `fase1/Volta2TesterIntegrationTest.java` (17 execuções): header inválido em login/register, docs, regressão das rotas protegidas,
    tentativas de burlar o `shouldNotFilter`, logins errados concorrentes e fuso UTC.
  - `fase1/LegadoV4IntegrationTest.java` (5): contexto Spring próprio. O banco é migrado até a V3, recebe clientes legados
    e o Flyway do app aplica a V4 ao subir. Tudo é exercitado depois pela API.
  - `IpRateLimitFilterDoFilterTest.java` (16): o rate limit pelo `doFilter` real.
- Não alterei `src/main/**`, o Flutter, o web nem os gates. Não fiz commit.

## Tipo de app e ferramentas
Backend REST Spring Boot 3.5.7 / Java 21 (Corretto 21.0.11), SQLite + Flyway, JWT (JJWT 0.12.6).
Ferramentas: JUnit 5, `@SpringBootTest` + MockMvc com a SecurityFilterChain real, perfil `test` (SQLite em arquivo em `target/`, migrations reais),
API do Flyway direto, `@DynamicPropertySource` para pré-migrar um banco legado, `MockHttpServletRequest` no filtro, JJWT para forjar tokens
e ExecutorService + latch para os testes de concorrência.

## Critério de aceite → teste → resultado (TODOS os critérios da FASE 1)

| Critério (TAREFA.md) | Testes que cobrem | Resultado |
|---|---|---|
| Senhas só em BCrypt | `Autenticacao.senhaGravadaSomenteComoBCrypt`; `Seguranca.adminInitializerCriaAdminComBCrypt...` | PASSOU |
| Nenhum endpoint devolve `senha`/hash | `Autenticacao.cadastroELoginNaoDevolvemSenhaNemHash`; `Autorizacao.listagemEDetalhe...SemSenha...`; `respostasDeAgendamentoNaoExpoemDadosPessoais`; **v2** `Volta2.loginComQualquerHeaderInvalido...` e `registerComHeaderInvalido...` (`$.senha` ausente); `LegadoV4.listagemDeAdminComDadosLegados...` | PASSOU |
| Seed da V1 neutralizado por migration nova (V1 intacta) | `Migrations.v1ContinuaIntactaComSeedEV2RemoveSeed`, `v2NeutralizaSeedQueJaTemAgendamento`; `Autenticacao.loginDoSeedAntigoNaoFunciona`; gate (diff da V1, migrations sem INSERT/senha) | PASSOU |
| Admin criado no startup com hash, senha via env | `Seguranca.adminInitializer*` (cria, idempotente, recusa CPF inválido/senha fraca, não promove cliente) | PASSOU |
| `POST /clientes/login` devolve JWT com id, nome, role | `Autenticacao.loginDevolveJwtComIdNomeERole`; **v2** `TokenEmRotaPublica.loginComTokenInvalidoNoHeaderDevolve200ComToken` (dev); `Volta2.loginComQualquerHeaderInvalidoDevolve200...` (Bearer expirado, lixo, outra chave, `alg=none`, 4 segmentos, `Basic`, `Bearer ` vazio, `bearer` minúsculo, `Token`); `loginComTokenValidoDeOutroUsuario...` (devolve o usuário do corpo, não o do token) | PASSOU |
| Credenciais erradas → 401 genérico igual | `Autenticacao.credenciaisErradasDevolvem401Generico...`; **v2** `Volta2.loginComHeaderInvalidoMantemOsErros401E423`; senha errada com token ADMIN válido → 401 | PASSOU |
| Bloqueio de 15 min após 3 falhas | `Autenticacao.contaBloqueada15MinutosAposTresFalhasSeguidas`, `bloqueioExpirado...`, `falhasNaoSeguidas...`, `bloqueioDeCpfInexistente...`; **v2** `Volta2.loginsErradosConcorrentesBloqueiamAContaSemPerderIncrementos` (@RepeatedTest 3x: 6 simultâneas → exatamente 3×401 + 3×423, `bloqueadoAte` gravado, senha certa → 423); `duasFalhasEDuasConcorrentesTambemBloqueiam`; `loginsErradosConcorrentesComCpfInexistente...` (2x) | PASSOU |
| Cadastro valida CPF/e-mail/senha/confirmação → 400 por campo | `Cadastro.*` (33 execuções); **v2** `TokenEmRotaPublica.cadastroComTokenInvalido...` e `Volta2.registerComHeaderInvalido...` (`errors.confirmarSenha` continua com header inválido) | PASSOU |
| CPF/e-mail únicos → 409 | `Cadastro.cpfDuplicado...`, `emailDuplicadoDevolve409MesmoComMaiusculas`, `indiceUnico...`; **v2** `Migrations.v4NormalizaCpfEEmailLegadosEPreservaConflitos` (dev); `LegadoV4.cadastroComCpfOuEmailDeLegadoEmOutraCaixaOuFormatoDevolve409` (CPF com/sem máscara, e-mail em outra caixa/com espaços, grupo em colisão) | PASSOU |
| Role do cadastro sempre CLIENTE | `Cadastro.roleDoCorpoEhIgnoradoESempreCliente`; **v2** `Volta2.registerComHeaderInvalidoOuTokenAdmin...` (`role:"ADMIN"` no corpo + token ADMIN válido → CLIENTE) | PASSOU |
| Tudo exige JWT exceto login/register/docs; sem token/inválido → 401 | `Autorizacao.semTokenDevolve401...`, `tokenInvalidoDevolve401`; **v2** `Volta2.rotasProtegidasComBearerInvalidoContinuam401ComOMesmoCorpo` (13 rotas × 6 tokens, corpo idêntico, nada executado); `rotasProtegidasSemTokenOuComEsquemaNaoBearer...` (sem header, Basic, Token, `Bearer ` → 401 "Não autenticado"); `docsESwaggerComTokenInvalidoNaoDevolvem401` (`/api-docs`, `/api-docs/swagger-config`, `/swagger-ui/index.html`, `/swagger-ui.html`); `tentativasDeCaminhoParecidoComRotaPublica...` (`..`, `;`, PUT/DELETE em login/register → nunca 200); `tokenValidoContinuaFuncionando...` | PASSOU |
| Rotas de admin → 403 para cliente | `Autorizacao.rotasDeAdminDevolvem403ParaCliente`, `rotasDeAdminFuncionamParaAdmin`; `Volta2.tokenValidoContinuaFuncionando...` | PASSOU |
| Cliente não vê/cancela agendamento de outro | `Autorizacao.clienteNaoVeNemCancelaAgendamentoDeOutro`, `adminPodeCancelar...` | PASSOU |
| DTO sem senha, CPF mascarado | `Autorizacao.listagemEDetalhe...`; **v2** `LegadoV4.listagemDeAdminComDadosLegados...` (CPF legado com máscara/cru não aparece, só `***.***.***-09`) | PASSOU |
| Logs sem senha/token/CPF; show-sql off fora de dev | `Seguranca.logsNaoRegistram...`, `sqlNaoEhExibido...`, `showSqlDesligadoForaDoPerfilDev` | PASSOU |
| CORS sem `*` com credenciais | `Seguranca.cors*`, `codigoDeProducaoNaoTemCrossOriginCuringa`; `TokenEmRotaPublica.docsEOptions...` (preflight com token inválido → 200) | PASSOU |
| Migration de unicidade (data, horario) não cancelados | `Agendamento.indiceUnicoParcial...`; `Migrations.v3...` | PASSOU |
| Cliente do agendamento vem do JWT | `Agendamento.clienteDoAgendamentoVemDoJwtENaoDoCorpo` | PASSOU |
| Ocupado → 409; concorrência só 1 aceita | `Agendamento.horarioOcupadoDevolve409...`, `concorrenciaSoUma...` (@RepeatedTest 3x, 10 threads) | PASSOU |
| Passado / fora da grade → 400 | `Agendamento.agendarNoPassado...`, `horarioForaDaGrade...` (11), `horarioDentroDaGrade...`; `RelogioFixo.*` | PASSOU |
| `GET /disponibilidades?data=` → `["08:00",...]` | `Agendamento.disponibilidades*`; `RelogioFixo.hojeSoMostra...` | PASSOU |
| Cancelado volta a ficar disponível | `Agendamento.horarioCanceladoVoltaAFicarDisponivel...` | PASSOU |
| `./mvnw test` com integração SpringBootTest + MockMvc + SQLite | suíte inteira (164) pelo gate congelado | PASSOU |
| Nenhum segredo no repo; `.env.example` documentado | `Seguranca.segredos...`, `envExampleDocumenta...`, `chaveJwtFraca...`; gate | PASSOU |

### Itens do veredito da volta 1 (pendências do tester)
| Pedido | Teste | Resultado |
|---|---|---|
| 1. Login/register com Bearer expirado/lixo/outra chave/Basic → 200 e 400/409 mantidos | `TokenEmRotaPublica.*` (dev) + `Volta2.login*`, `registerComHeaderInvalido...` | PASSOU |
| 2. Docs com token inválido ≠ 401 | `Volta2.docsESwaggerComTokenInvalidoNaoDevolvem401` | PASSOU |
| 3. Regressão: protegidas com token inválido → 401 mesmo corpo; sem token → 401 | `Volta2.rotasProtegidas*`, `tentativasDeCaminho...` | PASSOU |
| 4. V4 com legados (máscara, maiúsculas/espaços, colisão) + login E2E pela API | `Migrations.v4...` (dev, só Flyway) + `LegadoV4.*` (5, ponta a ponta: V4 aplicada pelo app, login com/sem máscara, token do legado acessa rota protegida, 409 em outra caixa/formato, colisão: registros crus, login acha o já normalizado, o cru recebe 401 genérico sem 500) | PASSOU |
| 5. Rate limit (só falhas contam, limite, limpeza) | `IpRateLimitFilterDoFilterTest` (400/401/409/423 contam; 200/201/204/403/404/500 não contam; 429 não conta nem estende a janela; requisição bloqueada não chega à app; sucessos intercalados; rotas/métodos não monitorados; limpeza seletiva; 1000 IPs limpos; 499+1 falhas concorrentes contadas sem perda); `RateLimitIntegrationTest` (2); `IpRateLimitFilterTest` (8) | PASSOU |
| 6. Fuso UTC | `FusoDaJvmTest` (dev); `Volta2.dataEHorarioSaoGravadosEmUtcELidosDeVoltaIguais` (valor bruto no SQLite = meia-noite UTC / segundos do dia × 1000; leitura pela API igual); `fusoExternoDiferenteEhDesfeitoPeloMain...` (JVM em America/Sao_Paulo → o código do main volta para UTC → 09:00 continua ocupado, 409 e leitura iguais) | PASSOU |
| 7. Logins errados concorrentes → conta bloqueada | `Volta2.loginsErradosConcorrentes*` (3 testes, 6 execuções) | PASSOU |

### `IpRateLimitFilterTest` adaptado pelo developer: ficou mais fraco? (conferido com `git diff`)
**Conclusão: não ficou mais fraco.** Os 4 cenários originais continuam: IP liberado no início, bloqueio na 6ª com limite 5,
URI não monitorada e GET liberados. A única mudança semântica é a esperada pelo novo contrato: em vez de 5 *chamadas*, o teste
registra 5 *falhas* (`registrarFalha`) antes de exigir o bloqueio. O limite 5 virou explícito no construtor porque o padrão passou a ser 10.
O teste de bloqueio ganhou asserções (register no mesmo limite, outro IP livre) e entraram 4 testes novos (sucessos não bloqueiam,
a janela vence, limpeza e padrão = 10). Ponto fraco que sobrou: ele não passa pelo `doFilter` (não prova quais status contam). Por isso
escrevi `IpRateLimitFilterDoFilterTest`.

## Falhas
Nenhuma na suíte final. Durante a escrita, 1 teste falhou e revelou um achado (B2 abaixo): com o fuso padrão da JVM trocado em runtime
para `America/Sao_Paulo`, `disponibilidades` passou a mostrar `09:00` como livre embora já estivesse agendado
(`[09:00 continua ocupado] Expecting [...,"09:00",...] not to contain "09:00"`). O teste foi reescrito para provar a proteção que
de fato existe (o main força UTC antes do Spring subir), e o comportamento ficou registrado como achado.

## Achados de segurança / robustez
| Sev. | Achado | Evidência / sugestão |
|---|---|---|
| BAIXA | **B2**: `spring.jpa.properties.hibernate.jdbc.time_zone: UTC` não protege `LocalDate`/`LocalTime` no SQLite. A gravação e a leitura seguem o fuso padrão da JVM, e o comentário do `application.yml` ("Fuso FIXO usado pelo Hibernate ao gravar/ler datas") engana. A proteção real é `CorteCertoApplication.fixarFusoDaJvm()` + `-Duser.timezone=UTC` no Dockerfile + surefire, e ela funciona. O risco só volta se algum código chamar `TimeZone.setDefault` em runtime ou se o app subir por outro ponto de entrada. | Observado no 1º run de `Volta2.fusoExterno...`. Sugestão: corrigir o comentário. Numa fase futura, gravar como texto ISO. |
| BAIXA | **V4, colisão sem registro normalizado**: se dois legados colidem e **nenhum** já está normalizado (ex.: `111.444.777-35` e `111 444 777 35`, ou `A@x.com` e `a@x.com `), os dois ficam crus. Assim, `existsByCpf/existsByEmail` (valor normalizado) e o índice único (coluna crua) não barram um **terceiro** cadastro com o valor normalizado, que passa a ser a conta encontrada no login. | Análise da V4 (não há teste que falhe; está dentro do "resolução manual" documentado). O checklist do README precisa ser rodado ANTES do deploy. Opcional: bloquear o cadastro quando houver colisão pendente. |
| BAIXA | Rate limit: entre a checagem (`isRequestAllowed`) e o registro da falha (depois da chain) há uma janela, então N requisições simultâneas de um IP no limite passam todas. Aceitável: o bloqueio por conta (3 falhas, transacional) continua valendo. | `IpRateLimitFilter.doFilter`. |
| BAIXA | B1 (volta 1) continua: assinatura com caractere extra é aceita e o algoritmo depende do tamanho da chave (o dev registrou como não feito). | `JwtService`. |
| BAIXA | Os achados BAIXA da volta 1 continuam: Spring Boot 3.5.x sem checagem de CVE, JWT sem consulta ao banco, swagger público em produção, `dataNascimento` livre. | Ver `.loop/volta-1/testes.md`. |

Busca de segredos: o gate congelado passou (yml, migrations V2+, V1 intacta, arquivos sensíveis, `.env.example`). Nenhum segredo novo nos arquivos da volta 2.

## O que NÃO foi possível testar e por quê
- **CVEs das dependências:** sem acesso externo (o dependency-check precisa baixar a NVD).
- **Proxy/CGNAT reais e `forward-headers-strategy=native`:** só simulados com `setRemoteAddr`. Não há proxy no ambiente local.
- **Fuso no container Docker:** não subi o container. Conferi o Dockerfile por leitura (teste do dev) e o efeito do main por teste.
- **Timing igual entre CPF inexistente e conta bloqueada (BCrypt fictício):** não medido, porque a medida é instável em teste.
- **Concorrência entre processos:** os testes usam threads num único processo e no mesmo SQLite.

## Proposta de mudança no gate
Nenhuma. O gate congelado já roda `./mvnw -B clean test` (inclui os testes novos) e as checagens de segredo.
