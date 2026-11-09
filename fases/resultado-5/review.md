APROVADO

## Revisão analisada (branch / HEAD de cada repositório)
- App `cortecerto_flutter`: branch `main`, HEAD `ffeb405` + alterações não commitadas (M: `app_router.dart`, `rotas.dart`, `admin_agendamento_api.dart`, `admin_page.dart`, `agendamento_page.dart`, `test/a11y/acessibilidade_test.dart`, `test/a11y/telas_harness.dart`, `test/helpers/widget_helpers.dart`, `TAREFA.md`; novos: `lib/features/admin/domain/{faturamento,periodo_faturamento}.dart`, `lib/features/admin/presentation/{faturamento_controller,faturamento_page}.dart`, `test/fase5/*` (6 arquivos), `test/contract/faturamento_contract_test.dart`). `test/fase4/*` sem alteração.
- Backend `cortecerto-backend-loop`: branch `loop/mobile-migration`, HEAD `7620220` + alterações não commitadas (M: `README.md`, `AgendamentoAdminController`, `Agendamento`, `AgendamentoService`, `fase3/AgendamentoAdminIntegrationTest`; novos: `V6__valor_centavos_agendamento.sql`, `util/PrecoUtils`, `service/FaturamentoService`, `dto/Faturamento{,Dia,Servico}DTO`, `src/test/.../fase5/*` (6 arquivos)).
- V1–V5: `git diff 7620220 -- db/migration/` vazio. O `V2__...sql` tem mtime 18:38, depois da execução do gate (18:36), por causa do controle negativo do tester. Conferi que o blob é idêntico ao do commit (`git hash-object` = `28f48c3...` = `git ls-tree 7620220`). Nenhum outro arquivo de `lib/`, `test/` ou `src/` foi alterado depois do gate.
- Revisei os diffs antes de ler dev.md e testes.md. As afirmações dos dois batem com o código (D1–D8, 265 testes no backend, 519 no Flutter, 4 contratos, correção do teste intermitente). Exceção: o total de 261 citado no dev.md é anterior aos 4 testes do tester.

## Achados
Nenhum achado BLOQUEANTE ou IMPORTANTE. O que tentei derrubar e não consegui:
- **V6**: `ADD COLUMN ... NOT NULL DEFAULT 0 CHECK (>= 0)` mais um `UPDATE` só com texto/INTEGER (sem REAL). O INSERT cru da FASE 1 continua passando por causa do DEFAULT. NULL explícito é recusado no INSERT e no UPDATE (testado). Preço legado inválido ou NULL vira 0 de forma explícita, e a consulta que lista esses casos foi testada (8 de 8). O índice da V3 continua lá.
- **Caminhos que gravam o valor**: o construtor sem valor, `new Agendamento()` mais setters em `salvarAgendamento`/`criarAdmin`, e `atualizarAdmin` (só a troca real de serviço recalcula). `cancelar`/`excluir` não mexem no valor. O 422 sai antes do `save`, e o teste prova que nada é gravado. Nenhum endpoint serializa a entidade: o POST do cliente devolve `AgendamentoResponseDTO` dentro de um Map, então o `valorCentavos` não vaza para os contratos das FASES 1–4.
- **Faturamento**: somas em `long` com `addExact`. A agregação é em Java, sobre `findAllByDataBetween` (inclusiva nas duas pontas), o que evita o problema das datas em epoch-millis. Limite `DAYS+1 > 366`, 401/403 pelo matcher já existente (a autorização vem antes da validação, testado), sem PII (teste com `doesNotContainIgnoringCase("cliente")` mais o grep do gate).
- **Teste intermitente**: a busca só olha nome (escapado) e dígitos do CPF, com `role = CLIENTE` (o admin fica de fora). Com os 4 CPFs extras sem "100", a busca `"100%"` passa a ser determinística, e o teste ficou mais forte (`$[0].id`). Não repeti as 30 execuções: a análise da query sustenta a correção.
- **App**: o período usa campos de data (sem `Duration`). Semana de segunda a domingo conferida com o calendário real (09/11/2026 é segunda, então a semana é 09/11–15/11; o contexto estava errado e os testes não copiaram o erro). Respostas atrasadas são descartadas pelo contador `_requisicao`, inclusive o erro (o teste do tester pega a mutação F11). Sem cache: voltar a um período já visto chama a API de novo (`called(2)`). Rota coberta por `/admin/**`.
- **Grade**: escrevi e rodei um teste próprio em `scratchpad/rev/chip_clip_test.dart` (360/1.0, 360/2.0, 800/1.0, 412/1.3, 390/1.15, 600/1.5). Todos os textos do chip ficam dentro dele, centralizados, sem exceção. Os testes do developer medem larguras iguais, o preenchimento da largura e o espaço de 8, com a fonte de teste e com a Roboto.

[SUGESTÃO] Espaço da grade duplicado como constante solta
- Local: `lib/features/agendamento/presentation/agendamento_page.dart:491` (`const double _espacoGradeHorarios = 8;`), usado em `colunasDaGradeDeHorarios`. A `Row` usa `SizedBox(width: t.sm)`.
- Gatilho: mudar `AppTokens.sm`.
- Esperado x obtido: o cálculo e o layout deveriam usar o mesmo token. Hoje o cálculo usa 8 fixo e o layout usa `t.sm`.
- Evidência: DEMONSTRADO (leitura). Hoje `sm = 8`, então não há defeito atual.
- Impacto: se o token mudar, o número de colunas é calculado com um espaço diferente do real, e pode haver overflow ou uma coluna a menos.
- Menor correção segura: usar `t.sm` dentro de `colunasDaGradeDeHorarios` (o `AppTokens` já é lido ali).

[SUGESTÃO] `centavosDe` transforma valor malformado em 0 sem avisar
- Local: `lib/features/admin/domain/faturamento.dart` (`centavosDe`: regex sem match → `return 0`; também aceita sinal negativo e vírgula).
- Gatilho: o backend mandar `"abc"` ou `null` em `recebido`.
- Esperado x obtido: um erro visível era o esperado; a tela mostra `R$ 0,00`.
- Evidência: DEMONSTRADO (leitura e teste "ausente ou inválido → 0"). Hoje o backend sempre manda `"0.00"` válido.
- Impacto: baixo. Mascara uma quebra de contrato futura.
- Menor correção segura: lançar `FormatException` em `fromJson`, que o controller já converte em estado de erro.

[SUGESTÃO] Gate pode esconder linhas de erro do Maven na saída
- Local: `.loop/gate.sh:504` (`echo "$mvn_out" | grep -E 'Tests run:|ERROR|FAIL' | tail -30`).
- Gatilho: a saída do Maven tem um byte binário. Na execução atual apareceu "Binary file (standard input) matches", e o grep parou de imprimir as linhas seguintes.
- Esperado x obtido: as linhas ERROR/FAIL deveriam aparecer no log; depois desse ponto ficam ocultas.
- Evidência: DEMONSTRADO (`f5-gate-volta1.txt`).
- Impacto: só no diagnóstico. A decisão usa `mvn_rc` e o XML do surefire, então o gate não fica frouxo.
- Menor correção segura: `grep -aE` (o mesmo vale para a linha 219). Só numa fase futura, porque o gate está congelado.

[SUGESTÃO] Gate não confere que `test/fase4/*` continua sem edição
- Local: `.loop/gate.sh`, etapa de contagem por arquivo.
- Gatilho: uma volta futura edita um teste da FASE 4 mantendo a contagem.
- Esperado x obtido: a TAREFA 4.3 pede "sem edição". O gate só confere os mínimos de cada arquivo.
- Evidência: DEMONSTRADO (leitura). Hoje `git status` mostra `test/fase4` intocado.
- Impacto: um teste antigo pode ser afrouxado sem o gate perceber.
- Menor correção segura: `git diff --quiet ffeb405 -- test/fase4` no gate da próxima fase.

[SUGESTÃO] `findAllByDataBetween` carrega cliente e serviço EAGER para agregar
- Local: `FaturamentoService.calcular`.
- Gatilho: 366 dias com milhares de agendamentos e muitos clientes distintos.
- Esperado x obtido: uma consulta só; o `@ManyToOne` EAGER pode gerar N+1 por cliente e serviço distintos e carrega PII sem precisar (ela não é exposta).
- Evidência: SUSPEITA (não medi).
- Impacto: desempenho, com volume baixo hoje.
- Menor correção segura: uma projeção JPQL (`data, status, valorCentavos, servico.id, servico.tipoServico`) para quando houver volume.

## Limites da revisão
- Executei: `flutter test --no-pub test/fase5` (55 de 55 verdes) e um teste próprio de recorte dos chips fora do projeto (6 de 6 verdes), além de `git diff`/`hash-object`/`status` nos dois repositórios. Não rodei `./mvnw` nem o contrato: aceitei o gate (`f5-gate-volta1.txt`, PASSOU, 265 testes no backend, 519 no Flutter, contrato 4 de 4), depois de confirmar que nenhum arquivo relevante mudou desde aquela execução (o V2 tem conteúdo idêntico). Não subi backend e não toquei em `data/cortecerto.db`.
- Só li, sem executar: V6, `PrecoUtils`, `FaturamentoService`, os DTOs, `AgendamentoService`, a query de busca de clientes (base da análise do teste intermitente), controller, página, período, harness de a11y e o gate.
- Precisa de uma pessoa olhando a tela: a aparência dos chips sem `avatar` (ícone dentro do label, padding `t.xs/2`, conteúdo centralizado em colunas largas), o destaque visual do Recebido, as barras por dia e o contraste percebido. A grade foi medida com a fonte de teste e com a Roboto do SDK, não num aparelho real. Com a fonte de teste a grade dá menos colunas (por exemplo, 1 coluna em 412dp a 1.3), o que não representa o aparelho. As checagens técnicas não substituem a aprovação visual.
- O estado vazio esconde a lista por dia mesmo quando há previsto nos dias (decisão D7 do contexto, aceita). Se o usuário quiser ver o previsto por dia no vazio, isso é escopo de produto.
