STATUS: ENTREGUE

Volta 2 da FASE 1. O gate congelado (`.loop/gate.frozen.sh`) passou: `./mvnw -B clean test` com 164 testes, 0 falhas, exit 0.
O review está APROVADO (0 bloqueantes, 0 importantes, 6 sugestões). O BLOQUEANTE da volta 1 (token vencido no login/register) e os
3 IMPORTANTES (CPF/e-mail legados, fuso da JVM, rate limit) foram resolvidos e têm teste. Não há achado de segurança ALTA aberto:
todos os achados do tester estão como BAIXA. O Java 21 (Corretto 21.0.11) funcionou.

## Critérios de aceite (critério → evidência → OK/FALTA)

### Autenticação e senhas
| Critério | Evidência (teste que passou no gate) | |
|---|---|---|
| Senhas só como BCrypt; nenhum endpoint devolve `senha`/hash | `Autenticacao.senhaGravadaSomenteComoBCrypt`, `cadastroELoginNaoDevolvemSenhaNemHash`, `Autorizacao.listagemEDetalhe...SemSenha`, `Volta2.loginComQualquerHeaderInvalido...` | OK |
| Seed do admin neutralizado por migration nova; admin criado no startup com hash e senha via env | `Migrations.v1ContinuaIntactaComSeedEV2RemoveSeed`, `v2NeutralizaSeedQueJaTemAgendamento`, `Autenticacao.loginDoSeedAntigoNaoFunciona`, `Seguranca.adminInitializer*` | OK |
| `POST /clientes/login` devolve JWT com id, nome, role | `Autenticacao.loginDevolveJwtComIdNomeERole`, `TokenEmRotaPublica.loginComTokenInvalidoNoHeaderDevolve200ComToken` | OK |
| Credenciais erradas → 401 genérico igual | `Autenticacao.credenciaisErradasDevolvem401Generico...`, `Volta2.loginComHeaderInvalidoMantemOsErros401E423` | OK |
| Bloqueio de 15 min após 3 falhas seguidas | `Autenticacao.contaBloqueada15MinutosAposTresFalhasSeguidas` (+3), `Volta2.loginsErradosConcorrentesBloqueiamAContaSemPerderIncrementos` (6 simultâneas → 3×401 + 3×423) | OK |
| Cadastro valida CPF/e-mail/senha/confirmação → 400 por campo | `Cadastro.*` (33 execuções), `Volta2.registerComHeaderInvalido...` | OK |
| CPF e e-mail únicos → 409 | `Cadastro.cpfDuplicado...`, `emailDuplicadoDevolve409MesmoComMaiusculas`, `LegadoV4.cadastroComCpfOuEmailDeLegado...Devolve409` | OK |
| Role do cadastro sempre CLIENTE | `Cadastro.roleDoCorpoEhIgnoradoESempreCliente`, `Volta2.registerComHeaderInvalidoOuTokenAdmin...` | OK |

### Autorização e proteção de dados pessoais
| Critério | Evidência | |
|---|---|---|
| Tudo exige JWT, exceto login/register/docs; sem token ou token inválido → 401 | `Autorizacao.semTokenDevolve401...`, `tokenInvalidoDevolve401`, `Volta2.rotasProtegidasComBearerInvalidoContinuam401ComOMesmoCorpo` (13 rotas × 6 tokens), `docsESwaggerComTokenInvalidoNaoDevolvem401`, `tentativasDeCaminhoParecidoComRotaPublica...` | OK |
| Rotas de admin → 403 para cliente | `Autorizacao.rotasDeAdminDevolvem403ParaCliente`, `rotasDeAdminFuncionamParaAdmin` | OK |
| Cliente não vê nem cancela agendamento de outro | `Autorizacao.clienteNaoVeNemCancelaAgendamentoDeOutro` | OK |
| DTO sem senha; CPF mascarado em listagens | `Autorizacao.listagemEDetalhe...`, `LegadoV4.listagemDeAdminComDadosLegados...` | OK |
| Logs sem senha/token/CPF; show-sql desligado fora de dev | `Seguranca.logsNaoRegistram...`, `sqlNaoEhExibido...`, `showSqlDesligadoForaDoPerfilDev` | OK |
| CORS sem `*` com credenciais | `Seguranca.cors*`, `codigoDeProducaoNaoTemCrossOriginCuringa` | OK |

### Agendamentos sem duplicidade
| Critério | Evidência | |
|---|---|---|
| Migration de unicidade (data, horario) para não cancelados | `Agendamento.indiceUnicoParcial...`, `Migrations.v3...` | OK |
| Cliente vem do JWT | `Agendamento.clienteDoAgendamentoVemDoJwtENaoDoCorpo` | OK |
| Ocupado → 409; concorrência aceita só uma | `Agendamento.horarioOcupadoDevolve409...`, `concorrenciaSoUma...` (@RepeatedTest 3x, 10 threads) | OK |
| Passado ou fora da grade (08:00–19:30, 30 min) → 400 | `Agendamento.agendarNoPassado...`, `horarioForaDaGrade...` (11), `RelogioFixo.*` | OK |
| `GET /disponibilidades?data=` → `["08:00",...]` do dia | `Agendamento.disponibilidades*`, `RelogioFixo.hojeSoMostra...` | OK |
| Cancelado volta a ficar disponível | `Agendamento.horarioCanceladoVoltaAFicarDisponivel...` | OK |

### Qualidade
| Critério | Evidência | |
|---|---|---|
| `./mvnw test` passa, com integração SpringBootTest + MockMvc + SQLite | gate congelado: 164 testes, 0 falhas, exit 0 | OK |
| Nenhum segredo no repo; `.env.example` documentado | `Seguranca.segredos...`, `envExampleDocumenta...`, `chaveJwtFraca...`, checagens do gate | OK |

## Pendências para a próxima volta
Nenhuma para a FASE 1. As sugestões do review (todas opcionais ou de fase futura) estão em `.loop/RELATORIO.md`, em "Sugestões de próximos passos".

## Motivo do bloqueio
Não se aplica.
