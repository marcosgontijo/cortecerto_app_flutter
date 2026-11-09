# testes.md: FASE 5, volta 1 (tester)

## Tipo de app e ferramentas
- **App mobile Flutter** (Flutter 3.44.2 / Dart 3.12.2): `flutter analyze`, `flutter test` (widget e unit com `mocktail`, harness de a11y com guidelines, Roboto do SDK para a grade) e `flutter test --tags contract` contra o backend real.
- **Backend Spring Boot** (Java 21 Corretto 21.0.11): JUnit 5 + Spring Boot Test + MockMvc, SQLite temporário em `target/`, Flyway real (testes de migration com `target("5")` e depois `migrate()`).
- **Segurança:** checagens estáticas do gate (segredos, log de CPF/token, Authorization fora do interceptor, cleartext), testes de 401/403/400 e de dados pessoais, busca de segredos nos arquivos novos. Não rodei auditoria de dependências (precisa de rede); o `pubspec.yaml` não mudou desde `ffeb405`.

## Revisão testada
| Repo | Branch | HEAD | Estado |
|---|---|---|---|
| App `cortecerto_flutter` | `main` | `ffeb405` | alterações da FASE 5 sem commit (developer) + `test/fase5/faturamento_tester_test.dart` (tester) |
| Backend `cortecerto-backend-loop` | `loop/mobile-migration` | `7620220` (= `.loop/backend-head-inicial.txt`) | alterações da FASE 5 sem commit + `src/test/.../fase5/Fase5TesterIntegrationTest.java` (tester) |

## O que o tester acrescentou
- `test/fase5/faturamento_tester_test.dart` (10 testes): o controller com hoje = **domingo** 15/11/2026 → Semana 09/11..15/11; quarta 11/11 → 09..15 e a anterior 02..08; Mês saindo de 31/01/2027 → fevereiro 01..28 → março 01..31; fevereiro bissexto de 2028; Dia virando o ano; **resposta atrasada e erro atrasado de um período antigo não mudam o estado do controller** (achado abaixo); resumo usa recebido/previsto da API, singular/plural e R$ 0,00; barra proporcional no Mês; Semana na tela a partir do domingo.
- `fase5/Fase5TesterIntegrationTest.java` (4 testes): reativar um CANCELADO só pelo status mantém o valor gravado mesmo com o preço novo (e volta a contar no previsto); trocar serviço e status no mesmo PUT grava o valor do novo serviço; `porDia` atravessando 29/02/2028 em ordem; `porServico` somando o mesmo serviço em dias diferentes com centavos exatos (19,99 × 3 = 59,97; 0,10 × 3 = 0,30; CANCELADO fora).
- `.loop/gate.sh` (FASE 5), descrito no fim deste arquivo.

## Critério de aceite → teste → defeito que pega → resultado
Resultados do gate (`GATE_PORTA=18080 bash .loop/gate.sh` → **exit 0**, 120 s): Flutter **519 passaram / 0 pulados / 0 falhas**; backend **265 testes / 0 falhas / 0 erros / 0 pulados**; contrato **4 de 4**.

| # | Critério | Teste(s) | Defeito que pega | Resultado |
|---|---|---|---|---|
| 1.1 | V6 nova; V1–V5 intocadas | gate etapa 8 (`git diff --quiet 7620220` + `--cached` nos 5 arquivos, nomes lidos do commit), gate 4d (exatamente 1 `V6__*.sql`), `MigrationsFlywayTest` (5) | editar uma migration já aplicada (controle negativo do gate abaixo) | PASSOU |
| 1.2 | coluna em centavos preenchida para os existentes | `MigrationV6ValorCentavosTest.preencheExistentesComPrecoAtualDoServico` (35.00→3500, 55.00→5500, 1234.50→123450, 40→4000, 7.5→750, CANCELADO também) | UPDATE ausente (B10), conversão errada (B9) | PASSOU |
| 1.3 | NOT NULL depois do preenchimento / inválido tratado de forma explícita | `colunaNaoAceitaNuloNemNegativo...`, `precoNuloOuInvalidoViraZero...` (D1 = 0, com a consulta de listagem do README testada) | coluna aceitando NULL, migration quebrando com preço legado ruim | PASSOU |
| 1.4 | `POST /agendamento` grava o valor | `ValorAgendamentoIntegrationTest.postDoClienteGravaOValorDoServico` (o `precoServico` enviado pelo cliente é ignorado) | gravar o preço vindo do corpo, ou não gravar | PASSOU |
| 1.5 | `POST /agendamento/admin` grava o valor | `postDoAdminGravaOValor...` (+ campos da resposta inalterados) | valor 0 (B4: 6 falhas) | PASSOU |
| 1.6 | PUT com troca de serviço grava o novo; só data/horário/status mantém | `trocarOServicoGravaOValorDoNovoEOResto`, tester `trocarServicoEStatusNoMesmoPut...`, `reativarCancelado...` | recalcular sempre pelo preço atual (B3) | PASSOU |
| 1.7 | mudar o preço não altera o passado | `mudarOPrecoDoServicoNaoAlteraAgendamentosJaCriados`, `usaOValorGravadoENaoOPrecoAtual` | faturamento usando o preço atual (B2) | PASSOU |
| 1.8 | conversão sem ponto flutuante; preço inválido → erro claro | `PrecoUtilsTest` (20), `precoInvalidoNoServicoGera422ClaroENadaEhGravado`, `trocarParaServicoComPrecoInvalidoGera422EMantemTudo`; gate 4d: sem `double/float` em `PrecoUtils` e `FaturamentoService`, sem `CAST AS REAL` na V6 (fora dos comentários) | valor errado ou 0 em vez de erro; `double` na conta | PASSOU (mutante B11 equivalente, ver abaixo) |
| 2.1 | 200 com os campos do contrato, valores em texto `"0.00"` | `respostaTemExatamenteOsCamposDoContratoComValoresEmTexto` | campo faltando/sobrando, número em vez de texto | PASSOU |
| 2.2 | recebido = REALIZADO; previsto = CONFIRMADO+PENDENTE; CANCELADO nunca | `somaRecebidoPrevistoPorStatus...`, `fluxoCompletoPelaApi...`, tester `porServicoSoma...` | CANCELADO contando (B1: 3 falhas) | PASSOU |
| 2.3 | `porDia` com todos os dias, inclusive os zerados, em ordem | `porDiaTemTodosOsDias...`, tester `porDiaAtravessaFevereiroBissexto...` | intervalo aberto no fim (B6: 8 falhas), dia faltando | PASSOU |
| 2.4 | `porServico` ordenado por recebido decrescente | `porServicoSoRealizadosOrdenado...`, `porServicoEmpateDesempataPeloNome` | ordem crescente (B7) | PASSOU |
| 2.5 | intervalo fechado nas duas pontas | `intervaloFechadoNasDuasPontas` | `<` no lugar de `<=` (B6) | PASSOU |
| 2.6 | 400: inicio > fim, data inválida, > 366 dias, parâmetro ausente | `validacoesDoIntervaloDevolvem400NoFormatoPadrao` (10 casos + mensagens), `intervaloDe366DiasPassaE367Nao` | limite deslocado em 1 dia (B5) | PASSOU |
| 2.7 | cliente → 403; sem token → 401 | `semTokenDa401EClienteDa403`; contrato (CLIENTE → 403 no backend real) | endpoint liberado para autenticado (B8) | PASSOU |
| 2.8 | sem dado pessoal | `respostaNaoTemDadosPessoaisDoCliente`; gate 4d (DTOs sem cliente/cpf/telefone/email) | DTO com nome/CPF do cliente | PASSOU |
| 2.9 | usa o valor gravado | `usaOValorGravado...`, `mudarOPreco...` (previsto 179,00 = 40+40+99) | preço atual (B2) | PASSOU |
| 3.1 | card Faturamento no Painel → `/admin/faturamento` | `faturamento_page_test` "card Faturamento...", `rota_faturamento_test` "Painel → card → voltar" | card ausente/sem rota | PASSOU |
| 3.2 | rota bloqueada para CLIENTE | `rota_faturamento_test` (redirect unitário + app inteiro como CLIENTE, `verifyNever` na API); gate 4.16 (rota tem que ser `/admin/faturamento`) | rota fora de `/admin` (F5: 5 falhas) | PASSOU |
| 3.3 | seletor Dia/Semana/Mês; abre em Dia = hoje | `faturamento_page_test` "abre em Dia = hoje" (`verify(faturamento(09/11, 09/11))`) | abrir em outro período | PASSOU |
| 3.4 | Semana seg–dom; Mês do calendário | `periodo_faturamento_test` (11; os 7 dias da semana), page test, tester (domingo, quarta, 31/01 → fevereiro, bissexto) | semana começando no domingo (F1: 13 falhas); mês sem limite do dia (F10) | PASSOU |
| 3.5 | setas com tooltip; rótulo | page test "setas com tooltip: dia ±1, semana ±7, mês ±1"; a11y 4.1 | tooltip removido (F9: 4 falhas) | PASSOU |
| 3.6 | Recebido em destaque e Previsto à parte, com quantidades | page test "Recebido em destaque..." (fontSize do Recebido > Previsto), tester "resumo... DA API" | resumo trocado/somado localmente | PASSOU |
| 3.7 | lista por dia com barra proporcional + valor em texto; por serviço | page test Semana/Mês, tester Mês (razão 3500/123450, zero sem barra, `ExcludeSemantics` na barra) | barra pelo total do período (F8) | PASSOU |
| 3.8 | carregando / vazio / erro + Tentar novamente; refresh; sem cache | page test (4 estados + resposta antiga), tester (estado do controller), gate 5.c (sem estrutura de cache) | refresh que não busca (F6), vazio nunca exibido (F7), resposta antiga gravada (F11/F12) | PASSOU |
| 3.9 | R$ pt-BR pelo Formatters | page test (`R$ 1.234,50`, `R$ 0,00`); gate 5.b (sem `NumberFormat` em lib/features; a página usa `Formatters.moeda`) | formatação própria | PASSOU |
| 3.10 | MASTER.md / tema | gate 4.11–4.15; a11y (guidelines + 360×640 a 2.0) com Faturamento e 4 estados extras | cor fixa, fontSize, emoji, IconButton sem tooltip | PASSOU |
| 4.1 | colunas iguais que preenchem a largura (360/800 dp) | `grade_horarios_test` (fonte de teste e Roboto: largura igual na linha e entre linhas, borda esquerda/direita = área do título, espaço 8, 3 colunas em 360 com Roboto, > 3 em 800) | colunas desiguais (F2: 6 falhas); chips sem preencher (F3: 6 falhas) | PASSOU |
| 4.2 | menos colunas com texto grande, sem overflow | grade test 200% (fonte de teste e Roboto); a11y 4.2 "agendamento" | colunas fixas sem medir o texto (F4: 5 falhas, inclusive a11y 4.2) | PASSOU |
| 4.3 | mantém a FASE 4 | grade test "FASE 4 preservada"; `test/fase4/*` sem edição (42/22/48 no gate) | Key fora do ChoiceChip, indisponível habilitado | PASSOU |
| 5.1 | testes de integração do backend | 48 testes em `fase5/` (mínimos por classe no gate) | | PASSOU |
| 5.2 | widget tests do app com API fake | 55 em `test/fase5/` (mínimos por arquivo no gate) | | PASSOU |
| 5.3 | Faturamento e Painel no harness de a11y | `a11y/acessibilidade_test.dart` 67 (era 57) | | PASSOU |
| 5.4 | contrato ponta a ponta | `test/contract/faturamento_contract_test.dart` (backend real na 18080, banco temporário com a V6 aplicada, conferido no log) | REALIZADO fora do recebido, CANCELADO contando, CLIENTE ≠ 403 | PASSOU (4/4) |
| 5.5 | mvnw / analyze / flutter test verdes, nenhum teste antigo some | gate: 519 ≥ 519, 285 ≥ 285 fora de fase4/fase5/a11y, por arquivo; backend 265 ≥ 265 | teste removido ou pulado | PASSOU |
| 5.6 | teste intermitente corrigido | revisão do código (`registrarComCpfSemDigitos("100")`, asserções `length == 1` mantidas e `$[0].id` novo); classe com 18 testes no gate | flakiness | PASSOU no gate (as 30 repetições são do developer: `ok=30 fail=0`; eu não repeti) |

## Controles negativos (mutações) — todas revertidas
Scripts: `scratchpad/mut_back.sh`, `mut_app.sh`, `mut_app2.sh`. Cada mutação: cópia do arquivo → `perl` → diff impresso (prova de que foi aplicada) → testes → cópia restaurada → `cmp` ok. No fim: sha256 de `git diff` + `git status --porcelain` (+ conteúdo dos arquivos novos no app) **igual ao do início** nos dois repos ("BACKEND: ... idênticos", "APP: ... idênticos").

| # | Quebra aplicada | Teste que falhou (trecho) | Desfeita? |
|---|---|---|---|
| B1 | `FaturamentoService`: `else if (CONFIRMADO \|\| PENDENTE)` → `else` (CANCELADO conta) | `FaturamentoIntegrationTest` 3 falhas: `previsto expected:<35.00> but was:<70.00>`; `porDia... [previsto dia 5]` | sim (cmp + sha) |
| B2 | faturamento usa `PrecoUtils.paraCentavos(servico.preco)` (preço atual) | Faturamento 3, ValorAgendamento 1 (`recebido expected:<40.00> but was:<99.00>`), Tester 1 | sim |
| B3 | `atualizarAdmin` sempre recalcula o valor | ValorAgendamento 2 (`expected: 2500L`; `Status expected:<200> but was:<422>`), Tester `reativarCancelado...` | sim |
| B4 | `criarAdmin` grava `0L` | ValorAgendamento 6 falhas (`expected: 5500L`) | sim |
| B5 | limite `DAYS + 1 > 366` → `DAYS > 366` (367 passa) | `intervaloDe366DiasPassaE367Nao`: `Status expected:<400> but was:<200>` | sim |
| B6 | `!d.isAfter(fim)` → `d.isBefore(fim)` (fim aberto) | Faturamento 7 falhas + 1 erro (`recebido expected:<35.00> but was:<0.00>`) | sim |
| B7 | `porServico` sem `.reversed()` | `porServicoSoRealizadosOrdenado...`: `expected: "Caro ..."` | sim |
| B8 | `AppConfig`: `.requestMatchers("/agendamento/admin/faturamento").authenticated()` antes do matcher ADMIN | `semTokenDa401EClienteDa403`: `Status expected:<403> but was:<200>` | sim |
| B9 | V6: reais inteiros `* 100` → `* 10` | `MigrationV6...preencheExistentes...`: `expected: 4000L` | sim |
| B10 | V6: `UPDATE ... WHERE 0` (sem preenchimento) | `preencheExistentes...`: `expected: 3500L` | sim |
| B11 | `PrecoUtils.FORMATO` aceita 3 casas | **nenhum falhou** (rc=0): mutante equivalente para os casos inválidos, porque `movePointRight(2).longValueExact()` recusa `35.123` mesmo assim. Só `"35.120"` passaria a valer 3512 (valor correto). Fica registrado | sim |
| F1 | semana `d.weekday - monday` → `d.weekday % 7` (começa no domingo) | `periodo_faturamento_test` + page + tester: `+20 -13` | sim |
| F2 | grade: `Expanded(flex: c == 0 ? 2 : 1)` (colunas desiguais) | `grade_horarios_test` 6 falhas (360, 800, 200%, Roboto ×3) | sim |
| F3 | grade: `Expanded` → `Flexible` (chips não preenchem) | grade 6 falhas | sim |
| F4 | `colunasDaGradeDeHorarios` → `return 3` (sem medir o texto) | grade 4 + `a11y 4.2 360x640 ... agendamento` | sim |
| F5 | `adminFaturamento = '/faturamento'` (fora do bloqueio de `/admin/**`) | `rota_faturamento_test` 5/5 falharam (inclusive "CLIENTE em /admin/faturamento → /servicos") | sim |
| F6 | `onRefresh: () async {}` | "pull-to-refresh busca de novo no servidor" | sim |
| F7 | `semRealizados => recebidoCentavos < 0` (vazio nunca) | "vazio: mensagem...", "fromJson tolera listas ausentes", "resposta de um período antigo" | sim |
| F8 | barra proporcional ao total do período | "Semana: 7 dias com valor em texto e barra proporcional" | sim |
| F9 | tooltip "Período anterior" removido | page "setas com tooltip" + a11y 4.1 (3 casos de faturamento) | sim |
| F10 | navegação de mês sem limitar o dia (31/01 → 03/03) | tester "Mês a partir de 31/01/2027" | sim |
| F11 | controller grava a resposta de um período antigo | **1ª rodada: nenhum teste falhou** (o teste do developer só olha a tela; sem `notifyListeners` a tela não reconstrói). Depois do teste novo do tester: "resposta atrasada de um período antigo não substitui o estado..." falhou (`+23 -1`) | sim |
| F12 | controller grava o erro de um período antigo | tester "erro atrasado de um período antigo..." (`+23 -1`) | sim |

### Controle negativo do próprio gate
`V2__remove_seed_admin_e_unicidade_cliente.sql` com uma linha a mais + `lib/features/admin/data/fora_do_escopo_tmp.dart` novo → `GATE_PORTA=18080 bash .loop/gate.sh` → **exit 1**, com `GATE FALHOU [4.16 escopo de arquivos] obtido: fora da lista: lib/features/admin/data/fora_do_escopo_tmp.dart`, `GATE FALHOU [8. V1-V5] obtido: .../V2__...sql alterada` (e o `mvnw` também falhou: 1 falha). Revertido: V2 restaurada por cópia, arquivo removido; `git -C backend diff --quiet 7620220 -- src/main/resources/db/migration/` → 0; sha256 de diff+status igual nos dois repos. Saída: `scratchpad/gate-controle-negativo.txt`.

## Falhas encontradas
Nenhum teste falha no código atual. O que achei:
1. **Teste fraco do developer (MÉDIA, corrigido com teste novo):** `faturamento_page_test` "resposta de um período antigo não sobrescreve o período atual" não pegava o controller gravando a resposta antiga (F11 sobreviveu). O código está correto, mas o teste não provava isso. Os 2 testes de controller em `faturamento_tester_test.dart` cobrem agora. Reproduzir: aplicar F11 e rodar `flutter test test/fase5/faturamento_page_test.dart` (passa) e `test/fase5/faturamento_tester_test.dart` (falha).
2. **Falso positivo do meu gate (corrigido):** na 1ª execução, `GATE FALHOU [1.1 V6] obtido: CAST para ponto flutuante na V6`, porque o grep pegou o comentário `-- ... (nada de CAST AS REAL)`. Agora o gate ignora os comentários `--`. Saída guardada em `scratchpad/f5-gate-volta1-tentativa1-falso-positivo.txt`. A 2ª execução passou (exit 0) e está em `scratchpad/f5-gate-volta1.txt`.
3. **Contrato (BAIXA):** na checagem da semana em volta do dia, o teste só confere `porDia[3]`; não confere que os outros 6 dias estão zerados. Isso é coberto no backend por `porDiaTemTodosOsDias...`.

## Achados de segurança
| Severidade | Achado |
|---|---|
| — | Autorização: `/agendamento/admin/faturamento` só para ADMIN (401/403 testados, e B8 prova que o teste pega a liberação). Entrada: `LocalDate` tipado + limites 400 testados; sem SQL montado na mão (query derivada do JPA). Sem dado pessoal na resposta (teste + checagem do gate). |
| BAIXA | `centavosDe` (app) transforma valor malformado em 0 e aceita sinal negativo: se o backend mandasse um valor inválido, a tela mostraria `R$ 0,00` em vez de erro. Hoje o backend sempre manda `"0.00"` válido, então isso não acontece. |
| BAIXA | V6: preço legado só com dígitos e absurdamente grande (> 9,2·10^16) estouraria o INTEGER do SQLite na multiplicação por 100. Teórico: os preços reais têm 2 a 3 dígitos. |
| BAIXA (informativo) | `test/contract/faturamento_contract_test.dart` usa a senha fixa `Contrato123` para um cliente descartável criado no banco temporário (mesmo padrão dos contratos anteriores). As credenciais de admin vêm do ambiente (gate 4.8 confere). |
| DESCONHECIDO | Auditoria de dependências (pub/Maven) não foi rodada porque precisa de rede (proibido). Nenhum pacote novo: `pubspec.yaml` sem diff desde `ffeb405` (o gate 5.a confere) e `pom.xml` sem mudança. |
Nenhum segredo novo encontrado nos arquivos da fase (grep por secret/senha/password/token com literal ≥ 6 caracteres em lib/features/admin, test/fase5, test/contract novo e nos arquivos novos do backend).

## O que NÃO foi possível testar
- **Aparelho/emulador real:** a grade foi medida na fonte de teste e com a Roboto carregada do SDK, não num Android de verdade (a fonte do fabricante pode ser outra).
- **Só uma pessoa olhando a tela pode aprovar:** se a barra e os cards estão bonitos e alinhados, o destaque visual do Recebido, a aparência dos chips sem o `avatar` (ícone agora dentro do label, padding `t.xs/2`) e o contraste percebido (o `textContrastGuideline` cobre só o mínimo automático).
- **Repetição do teste intermitente:** não rodei as 30 repetições (o developer registrou `ok=30 fail=0`). No gate ele passou 2 vezes nas execuções limpas.
- **Volume:** 366 dias com muitos agendamentos (desempenho do `findAllByDataBetween` + agregação em Java) não foi medido.
- **Exemplo do contexto:** o `contexto.md` diz que 09/11/2026 é domingo. É **segunda**. Os testes usam o calendário real (Semana de 09/11/2026 = 09/11 – 15/11/2026) e o domingo 15/11 está coberto pelo tester.
- **Critério 4.2:** o contexto sugeria acrescentar a checagem de colunas no próprio harness de a11y 4.2. O developer colocou essa checagem em `grade_horarios_test` (360 a 200%, fonte de teste e Roboto), e o a11y 4.2 continua checando que não há overflow. A cobertura é equivalente (a mutação F4 derruba os dois).

## Gate (`.loop/gate.sh`)
Parte de `fases/resultado-4/gate.sh`, o gate final da FASE 4. É ele que tem os mínimos 454/285/57/48 citados na TAREFA; o `gate.frozen.sh` de lá ainda tem os mínimos da volta 1 (285/43/33). Todas as etapas foram mantidas. Mudanças da FASE 5:
- **Flutter:** total ≥ **519**; ≥ 285 fora de `test/fase4`, `test/fase5` e `test/a11y`; mínimos por arquivo: a11y 67, fase4 42/22/48, fase5 page 14 / grade 8 / período 11 / api 7 / rota 5 / tester 10. Todos vêm das contagens da volta 1 (origem anotada no script) e só podem crescer. Se algum arquivo de teste sumir, o gate falha.
- **4.16 revista:** diff contra a base fixa `ffeb405`, para continuar valendo depois de um commit do loop. Lista permitida: faturamento*/periodo_faturamento, admin_page, admin_agendamento_api, agendamento_page, rotas.dart, app_router.dart. `rotas.dart`, `app_router.dart` e `admin_agendamento_api.dart` só podem ter linhas acrescentadas, e a rota tem que ser `/admin/faturamento`. A D1 da FASE 4 saiu, porque `agenda_admin_controller` agora está fora da lista. Mantive as entradas do enum de status.
- **Checagens novas no app:** `pubspec.yaml` sem diff e sem pacote de gráfico; nenhum `NumberFormat` em lib/features; a página usa `Formatters.moeda`; nada de cache no controller.
- **Checagens novas no backend:** exatamente 1 V6; sem `double/float` no conversor e no service; sem `CAST AS REAL` na V6; DTOs sem campos de cliente. Contagem pelo surefire XML: ≥ **265**, 0 falhas/erros/pulados, mais mínimos por classe (fase5 ×5, `AgendamentoAdminIntegrationTest` 18, `MigrationsFlywayTest` 5).
- **Contrato:** ≥ 4 arquivos e ≥ 4 testes, todos passando, e o do faturamento tem que aparecer na saída. Banco temporário `target/gate-contract-*.db`, que precisa existir; o log tem que mostrar `Migrating ... to version 6`. O **sha256 de `data/cortecerto.db`** é conferido no início e no fim (resultado: intocado). Porta `GATE_PORTA` (18080); a 8080 (PID 25104, IDE) continuou no ar depois do gate.
- **Etapa 8 trocada:** HEAD do backend tem que ser igual a `.loop/backend-head-inicial.txt` (7620220), e V1–V5 (nomes lidos do commit inicial) sem diff contra ele, nem staged nem no working tree.

Comando: `GATE_PORTA=18080 bash .loop/gate.sh` → **GATE: PASSOU, exit 0** (saída completa em `C:\Users\Usuario\AppData\Local\Temp\claude\9e3f5ea25985bb0e\aa4b67d2-cc1c-422a-86c6-a821ec117fd3\scratchpad\f5-gate-volta1.txt`).
