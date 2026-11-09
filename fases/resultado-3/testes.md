# Testes — FASE 3, volta 3 (tester)

## Tipo de app e ferramentas
- App mobile Flutter (Android) + backend Spring Boot 3.5.7 / Java 21 / SQLite.
- App: `flutter test` (widget e unit com mocktail, relógio injetável fixo), `flutter analyze`, contrato (`@Tags(['contract'])`) contra o backend real.
- Backend: JUnit 5 + Spring Boot Test + MockMvc.
- Gate: `.loop/gate.frozen.sh` (CONGELADO, não alterado; sha256 `8ef4e3c8…ab8fa86`, idêntico ao `gate.sh`).

## 1. Meus testes das voltas 1 e 2 não foram alterados
Conclusão: **não foram alterados.**

| Arquivo | Volta | sha256 atual | Registrado | Confere |
|---|---|---|---|---|
| `test/tester/fase3_tester_test.dart` | 1 | `5e73603bd69388ff32c6e38f535eee6522769c6d851a423ab1bfb89a9e5bad3c` | `5e73603b…5bad3c` | sim |
| `test/contract/fluxo_admin_tester_contract_test.dart` | 1 | `7833fcb72dffe05de0404c016b14942952e6bf5a3292e3f8d3f996a05a241cd3` | `7833fcb7…1cd3` | sim |
| `Fase3TesterIntegrationTest.java` | 1 | `895d938faa2f8068ddf91dbed4de275eddd6e6d7decde7c4bea6544967f32367` | `895d938f…2367` | sim |
| `Fase3RelogioFixoIntegrationTest.java` | 1 | `cf5d42397c24921ec9292a5f40bdf00b0fe5371cf065dd09028f69ed738ed78c` | `cf5d4239…d78c` | sim |
| `test/tester/fase3_volta2_tester_test.dart` | 2 | `eaa067f1de1dc801d517b4109bcc32ed03e45e09f158bd5a84154a7d87bf0f13` | sem hash (ver nota) | mtime 23:17:09 |
| `Fase3TesterVolta2IntegrationTest.java` | 2 | `d26bb5f1552f64954c3bc1bd6cf35a33a326ac36475f4e4ac76b35ad093f7f29` | sem hash (ver nota) | mtime 23:13:44 |

Nota: a volta 2 não registrou o hash dos dois arquivos que ela mesma criou. Os dois têm data de modificação anterior a `.loop/volta-2/testes.md` (23:20:29) e ao `feedback.md` (23:23:33), e o dev da volta 3 trabalhou depois disso (`dev.md` 23:27:57). O teste "ACHADO: Agenda 'Data'…" continua sem alteração e agora passa. A partir desta volta, os hashes completos ficam registrados acima.

## 2. Resultado do gate
`bash .loop/gate.frozen.sh` → **código de saída 0** (`GATE: PASSOU`). Depois do gate a **porta 8080 ficou livre**: `netstat` não mostra nenhum LISTEN, só um socket cliente em TIME_WAIT.

| Etapa | Resultado |
|---|---|
| flutter pub get / analyze | ok / "No issues found!" |
| flutter test --exclude-tags contract | **285 passaram**, 0 falharam (263 de antes + 22 novos) |
| Checagens estáticas e de segurança | ok |
| ./mvnw -B clean test | BUILD SUCCESS, **217 testes**, 0 falhas |
| Contrato (backend real, admin gerado no script) | **3 de 3 passaram**, 0 pulados |
| Backend derrubado / porta 8080 | ok / livre |

## 3. Testes novos desta volta
Arquivo novo: `test/tester/fase3_volta3_tester_test.dart` (22 testes, todos passam). sha256 `8a194ff3d7cb20f18b510b288e1e7b54eb92511df1dd7e43fe7f7e1e31c7691b`.

| Mudança da volta 3 | Testes do tester | Resultado |
|---|---|---|
| Limites da Agenda: `c.dia` nos extremos | "c.dia exatamente nos extremos (hoje-365 e hoje+365)"; "c.dia além dos extremos (hoje-366/+366): o intervalo se estende" | PASSOU |
| Limites da Agenda: virada da meia-noite | "virada exata 23:59:59.999 → 00:00:00.000" com o dia mais antigo e com o mais distante; "app aberto por dias (relógio +10 e −400 dias)"; widget "dia mais antigo e virada exata → calendário abre com initial = dia, OK mantém dia e período"; widget "escolher o NOVO hoje depois da meia-noite vira período 'Hoje'" | PASSOU |
| Invariante `first <= initial <= last` e initial = dia | grade de 8 relógios (virada de ano, 29/02 bissexto, 28/02, antigas datas de horário de verão) × 12 deltas × 4 instantes posteriores = 384 casos; também confere que first ≤ hoje-365, last ≥ hoje+365 e que não há hora nas datas | PASSOU |
| "Hoje" recalculado no carregar; lista antiga descartada | "lista às 23:59; carregar às 00:01 busca o novo dia e a lista antiga some já durante o carregamento" (Completer); "virada + falha na busca: erro, nada de ontem, contadores zerados"; "resposta atrasada de ONTEM chegando depois da nova é descartada"; "mesmo dia: recarregar não zera a lista"; "confirmar depois da meia-noite recarrega o NOVO dia"; widget "tela 'Hoje' às 23:59 → recarregar depois da meia-noite troca os dados, sem 'Horário encerrado'" | PASSOU |
| "Amanhã" recalculado; "Data" fixa | "'Amanhã' na virada do ano: 31/12 23:59 → 01/01 00:01 busca 02/01"; "'Data' no limite hoje-365 + virada: carregar não mexe no dia nem no período" | PASSOU |
| `selectableDayPredicate` da edição | original (com ou sem hora) selecionável, passados no meio e ontem não, hoje em diante sim; trocar de data mantém a original; aberta antes da meia-noite, depois dela a original e a selecionada (agora passadas) continuam selecionáveis; criação aceita tudo, mas firstDate = hoje; **invariante do assert do showDatePicker**, `predicado(initialDate) == true`, em 3 relógios × 8 originais × 5 seleções × 3 instantes = 360 casos | PASSOU |
| `selectableDayPredicate` no widget real | "edição de 05/01 com hoje 15/01: tocar 08/01 (desabilitado) + OK não muda a data nem consulta disponibilidades; tocar 20/01 muda"; "edição de HOJE aberta às 23:50, calendário aberto às 00:05 sem assert" | PASSOU |

### Varredura: `showDatePicker` / `initialDate` / `DateTime.now()` em `lib/`
| Local | Situação |
|---|---|
| `agenda_admin_page.dart:53` (`showDatePicker`) | usa os getters do controller (relógio injetável). Coberto. |
| `agendamento_form_page.dart:34` (`showDatePicker` + `selectableDayPredicate`) | usa os getters do controller (relógio injetável). Coberto. |
| `agenda_admin_controller.dart:37`, `agendamento_form_controller.dart:40`, `meus_agendamentos_controller.dart:12`, `session_controller.dart:12` | `DateTime.now` só como padrão de um relógio injetável. ok |
| `agendamento_page.dart:36` (TableCalendar do cliente) | `widget.relogio ?? DateTime.now`, injetável. `focusedDay` limitado a `[hoje, ultimoDia]`. ok |
| `agendamento_page.dart:68` | `hoje.add(Duration(days: 90))`: soma por `Duration` (INFO, ver A1). |
| `validators.dart:89` (`dataNascimento`) | `hoje ?? DateTime.now()`. O parâmetro é injetável, mas `cadastro_page.dart:161` chama sem ele (INFO, ver A2). |
| Outros `showDatePicker`, `initialDate`, `firstDate`, `lastDate` | nenhum. |

## 4. Critério → teste → resultado (todos os critérios da FASE 3)

### 0. Pendências da FASE 2
| Critério | Testes | Resultado |
|---|---|---|
| 0.1 Sem notifyListeners após dispose; sair durante o carregamento | `fase3_controllers_test`, `fase3_pages_test`; tester "resposta depois do dispose", estático 0.1, "sair da tela durante o cancelamento" | PASSOU |
| 0.2 Confirmado: Voltar → /servicos (PopScope) | `fase3_pages_test`; tester estático 0.2 | PASSOU |
| 0.3 isPublica com path exato | `fase3_rotas_test`; tester estático | PASSOU |
| 0.4 Validators.senha só [A-Za-z] | `fase3_rotas_test`; tester estático | PASSOU |
| 0.5 "Hoje" recalculado; teste "ontem" com data fixa | `fase3_pages_test`, `fluxos_app_test` | PASSOU |
| 0.6 Teste da V5 com checksum; `fromObject` padronizado | `MigrationV5SeedServicosTest.checksums…`; tester 0.6 | PASSOU |

### 1. Backend: endpoints de admin
| Critério | Testes | Resultado |
|---|---|---|
| ADMIN obrigatório: sem token 401, cliente 403 | dev `rotasDeAdminExigemTokenEPapelAdmin`; tester `rotasNovasComToken…401`, `clienteNaoAlcancaRotasDeAdminPorVariacoesDeCaminho`; contrato | PASSOU |
| Listar por data (ordem, campos, filtro, telefone só no admin) | dev + tester; status desconhecido → 400 | PASSOU |
| Criar (201, CONFIRMADO, 404/400, 409, passado/grade 400) | dev + tester (corpo inválido, concorrência, relógio fixo, ADMIN como cliente → 404) | PASSOU |
| Atualizar (200, 409 só contra outro, manter horário, reativar → 409, 404) | dev + tester (concorrência, `clienteId` ignorado) | PASSOU |
| Cancelar pelo admin (qualquer um) e liberar o horário | dev + tester (concorrência cliente×admin sem 500) | PASSOU |
| Deletar (204, 404, horário livre) | dev + tester | PASSOU |
| Busca de clientes (nome parcial, CPF, máx. 20, campos) | dev + tester (curingas e `\` como texto) | PASSOU |
| Duplicidade, grade e passado também no admin | acima + `Fase3RelogioFixoIntegrationTest` | PASSOU |

### 2. Backend: lado do cliente
| Critério | Testes | Resultado |
|---|---|---|
| `/meus` só do JWT, recentes primeiro, campos certos | dev + tester `meusOrdena…` | PASSOU |
| Cancelar só o próprio futuro não cancelado (outro 404, passado 400) | dev + tester + relógio fixo + contrato + concorrência | PASSOU |
| Deletado some de `/meus`; alterado aparece com os dados novos | dev + tester + contrato | PASSOU |

### 3. App: Painel Admin e Agenda Admin
| Critério | Testes | Resultado |
|---|---|---|
| Painel `/admin`; `/admin/**` bloqueia CLIENTE | `fase3_pages_test`, `fase3_rotas_test`, `app_router_test` | PASSOU |
| Grade 08:00–19:30, ocupado/Disponível, contadores, filtro, busca, pull-to-refresh | dev + tester voltas 1 e 2 | PASSOU |
| Hoje / Amanhã / Data | dev + tester voltas 1 e 2 | PASSOU |
| Hoje / Amanhã / Data: picker "Data" depois da meia-noite (F2) | volta 2 "ACHADO: Agenda 'Data'…" (inalterado) + volta 3 (extremos, virada exata, invariante com 384 casos, widgets) | PASSOU |
| "Hoje"/"Amanhã" seguem o dia real depois da meia-noite (S7) | volta 3 (recálculo, descarte, falha, resposta atrasada, ação, virada do ano, widget) | PASSOU |
| Criar (slot ou "+"): cliente, serviço, data, horário livre, status; sem passado | dev + tester volta 2 | PASSOU |
| Detalhes + Editar/Confirmar/Realizado/Cancelar/Excluir; editar data distante | dev + tester voltas 1 e 2 | PASSOU |
| Edição: dias passados não selecionáveis (exceto original/selecionada) | volta 3 (unit + invariante com 360 casos + widget com toque em dia desabilitado) | PASSOU |
| Confirmação em Cancelar/Excluir; feedback (inclusive 409); recarrega a agenda | dev + tester voltas 1 e 2 | PASSOU |

### 4. App: Meus Agendamentos
| Critério | Testes | Resultado |
|---|---|---|
| `/meus-agendamentos` por Serviços e Confirmado; Próximos/Histórico | dev + tester | PASSOU |
| Sempre do servidor (ao abrir, ao puxar, ao voltar para o app); sem cache | dev + tester volta 1 | PASSOU |
| Cancelar o próprio futuro com confirmação; a lista atualiza | dev + tester (corrida, trava liberada, botões desabilitados) | PASSOU |

### 5. Qualidade
| Critério | Testes | Resultado |
|---|---|---|
| Backend: integração de cada endpoint novo | `fase3/*` | PASSOU |
| App: widget tests da Agenda e de Meus; rotas | `fase3_pages_test`, `fase3_rotas_test`, `fase3_volta2_test`, `fase3_volta3_test`, `fase3_tester_test`, `fase3_volta2_tester_test`, `fase3_volta3_tester_test` | PASSOU |
| Contrato ponta a ponta admin ↔ cliente + 403 | 3/3 no gate, nenhum pulado | PASSOU |
| `./mvnw -B clean test`, `flutter analyze` e `flutter test` verdes; nada enfraquecido | gate exit 0; hashes do tester conferem; gate intacto | PASSOU |

## 5. Achados
| # | Severidade | Achado |
|---|---|---|
| F2 | resolvido | Picker da Agenda depois da meia-noite: os limites agora acompanham `c.dia`. Testado nos extremos, na virada exata e em 384 combinações. |
| S7 | resolvido em parte (INFO) | "Hoje"/"Amanhã" são recalculados a cada `carregar()`. Ainda assim, uma tela parada depois da meia-noite, sem nenhuma recarga, continua mostrando o dia anterior com o título "Hoje" (todos os horários aparecem como "Horário encerrado"). O mesmo vale para uma busca iniciada antes da meia-noite que só termina depois dela. O dev documentou como suposição. É seguro: o backend recusa o passado. |
| A1 | INFO | `agendamento_page.dart:68` soma 90 dias com `Duration`, e não pelos campos da data. Pode errar por 1 dia numa transição de horário de verão. O Brasil não adota horário de verão desde 2019. É código da FASE 2. |
| A2 | INFO | `Validators.dataNascimento` usa `DateTime.now()` quando `cadastro_page` não passa `hoje`. O relógio não é injetável pela tela, mas o parâmetro existe e os testes unitários o usam. Na virada da meia-noite o impacto é nulo. |
| S1 | BAIXA (segurança) | Herdado: JWT de cliente removido continua aceito até expirar (nada vaza). |
| S3 | BAIXA | Herdado: busca mista ("Ana 1") também casa CPFs que contenham os dígitos do termo. Fora do escopo. |
| S6 | INFO | Herdado: cancelamentos concorrentes sem trava otimista. Não há 500 e o estado final é sempre CANCELADO. |
| — | ok | Nenhum segredo versionado. Telefone só nas rotas de admin. CPF mascarado. O log do backend e a saída do contrato não mostram senha nem CPF do admin (checagens do gate). Nenhum achado de segurança novo nesta volta: as mudanças são só de UI e datas no app. |

## 6. O que NÃO foi possível testar
- Emulador ou dispositivo real: a virada real da meia-noite, o Voltar físico e o `AppLifecycleListener` real foram simulados com relógio injetado e com o binding de teste.
- O picker em release (asserts desligados): só foi verificado em debug/teste, onde o assert é o que importa.
- Transição real de horário de verão: o fuso da máquina é −03 sem horário de verão, então as datas antigas de horário de verão entraram na grade só como datas comuns.
- Concorrência real entre dois aparelhos: simulada com `Completer` (app) e threads (backend).
- Auditoria de dependências (OWASP / `pub outdated`): exigiria rede externa.

## Proposta de mudança no gate
Nenhuma. O gate congelado pega `test/` inteiro, inclusive o arquivo novo desta volta (285 testes rodados).
