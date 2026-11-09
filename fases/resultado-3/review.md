APROVADO

# Review — FASE 3, volta 3 (revisão final da fase)

Revisei o diff real dos dois repositórios: o app desde 3564d6b e o backend desde 7cb7995, mais os arquivos novos. Nesta volta, os únicos arquivos com data posterior a `feedback.md` são:
- em `lib/`: `agenda_admin_controller.dart`, `agenda_admin_page.dart`, `agendamento_form_controller.dart` e `agendamento_form_page.dart`;
- testes novos: `test/features/fase3_volta3_test.dart` e `test/tester/fase3_volta3_tester_test.dart`.

O backend não mudou nesta volta: nenhum arquivo é mais novo que o feedback. O gate congelado passou com exit 0: Flutter 285/285, backend 217/217, analyze limpo e contrato 3/3.

Não há nenhum BLOQUEANTE nem IMPORTANTE.

## Achados

[SUGESTÃO] lib/features/admin/presentation/agenda_admin_controller.dart:183-194 — **S7 resolvido só em parte.** O recálculo de "Hoje"/"Amanhã" só acontece no `carregar()`. Uma tela que fica parada da noite para o dia continua mostrando o dia anterior com o título "Hoje" até a próxima recarga, que vem de qualquer ação, de puxar a lista ou de voltar do formulário. É seguro, porque o backend recusa o passado, e a escolha foi documentada em dev.md. — Numa fase futura, se quiser: um `AppLifecycleListener` na página que chame `carregar()` no `onResume`, como já é feito em Meus Agendamentos.

[SUGESTÃO] lib/features/agendamento/presentation/agendamento_page.dart:68 — O calendário do cliente (FASE 2) ainda soma 90 dias com `add(Duration(days: 90))`. Hoje o risco é nulo, porque o Brasil não tem horário de verão. — Por consistência, usar `DateTime(h.year, h.month, h.day + 90)`.

[SUGESTÃO] lib/features/admin/presentation/agenda_admin_controller.dart:107-108 e agendamento_form_controller.dart:149-150 — Falta uma linha em branco entre o fim de um método e o bloco de getters seguinte. É só estilo.

## Conferido nesta volta (correções da volta 2)

- **F2: limites do calendário da Agenda** (`agenda_admin_controller.dart:75-97`, `agenda_admin_page.dart:52-61`). Correto e sem efeito colateral.
  - Os getters são calculados com o `_relogio` injetável:
    - `primeiroDiaCalendario` = o menor entre `dia` e hoje-365;
    - `ultimoDiaCalendario` = o maior entre `dia` e hoje+365;
    - `diaInicialCalendario` = `dia` limitado a esse intervalo.
  - A invariante `first <= initial <= last` vale por construção, e `initial == dia` sempre, porque o intervalo contém `dia`.
  - A página não tem mais `DateTime.now()` nem cálculo de data.
  - O teste "ACHADO: Agenda 'Data'…" do tester da volta 2 passa sem alteração (sha256 `eaa067f1…f0f13`, data anterior ao feedback).
- **S7.** No `carregar()`, os períodos `hoje` e `amanha` recalculam `_dia`. Se o dia mudou, a lista e o `_carregou` são zerados antes do `notifyListeners`, então nada de ontem aparece com o título "Hoje". O período `data` fica fixo.
  - O contador `_requisicao` descarta uma resposta atrasada de qualquer dia antigo, tanto no sucesso quanto no erro. O `finally` também só mexe no estado da requisição mais recente.
  - O `_acao` recarrega o novo dia depois da virada.
  - `selecionarData` compara com `hoje` e `amanha` no momento da escolha, então escolher o novo "hoje" volta o período para Hoje.
  - Não vi recursão nem chamada dupla: `_irPara` define `_dia` e o `carregar` não o altera de novo, porque o valor é igual.
- **Soma de dias por campos da data.** `DateTime(y, m, d±N)` é usado em `amanha`, nos limites da Agenda e em `ultimoDiaCalendario` do form. O Dart normaliza o transbordo de dia/mês/ano corretamente (virada de ano e 29/02 estão cobertos pelos testes).
- **`selectableDayPredicate`** (`agendamento_form_controller.dart:135-140`, `agendamento_form_page.dart:39`).
  - Na edição, aceita a data original, a `_data` selecionada e os dias a partir de hoje.
  - O `initialDate` é sempre `_data`, que está dentro do intervalo e é permitida explicitamente, então o assert do `showDatePicker` (`predicate(initialDate)`) nunca dispara. O tester verificou isso em 360 combinações e no widget real, inclusive abrindo antes e depois da meia-noite.
  - Na criação, todos os dias são aceitos e o intervalo já começa em hoje.
  - Não afrouxa nada: o backend continua com `validarNaoPassado`.

## Revisão final da FASE 3 (TAREFA, seções 0 a 5)

- **0. Pendências da FASE 2.**
  - O mixin `NotificadorSeguro` está em todos os ChangeNotifiers.
  - `PopScope` no Confirmado.
  - `isPublica` compara o path exato.
  - `Validators.senha` aceita só `[A-Za-z]`.
  - O "hoje" do calendário virou getter, e o teste "ontem desabilitado" usa data fixa (15/01/2030) e ainda verifica que hoje chama a API. É uma mudança legítima em `test/tester/fluxos_app_test.dart`, pedida pela TAREFA 0.5, e não um enfraquecimento.
  - O teste da V5 valida os checksums do Flyway, e o `fromObject`/`deErro` está padronizado.
- **1. Backend de admin.**
  - Autorização: o `AppConfig` só ganhou `.requestMatchers("/agendamento/admin", "/agendamento/admin/**").hasRole("ADMIN")`, sem remover nenhuma regra. `/clientes?busca=` continua só ADMIN.
  - Listar, criar (201, CONFIRMADO por padrão, cliente ADMIN → 404 indistinguível), atualizar (409 só contra outro agendamento, `...AndIdNot`, reativar ocupado → 409), cancelar e deletar (204/404) liberam o horário.
  - A busca com LIKE escapa os curingas e usa parâmetro vinculado.
  - Grade, passado e duplicidade reaproveitam as validações da FASE 1 (`validarGrade`, `validarNaoPassado`, índice único + `saveAndFlush`).
- **PII.** O telefone aparece só em `AgendamentoAdminResponseDTO` (admin) e em `ClienteResumoDTO` (busca do admin). O CPF sai sempre mascarado (`CpfUtils.mascarar`). Nenhuma resposta traz e-mail ou senha. `MeuAgendamentoDTO` tem só `id, data, horario, status, servico`.
- **2. Lado do cliente.** `/meus` usa o principal do JWT. O cliente cancela só o próprio agendamento futuro (outro → 404, passado → 400). Agendamento deletado some e alterado aparece atualizado, o que o contrato comprova.
- **3. Painel e Agenda Admin.**
  - O Painel tem saudação, card Agenda e logout.
  - O redirect de `/admin/**` usa `Rotas.isAdmin`, que exige path exato ou prefixo `/admin/`.
  - A Agenda tem grade 08:00–19:30, contadores, filtro, busca, pull-to-refresh e os períodos Hoje/Amanhã/Data com picker robusto.
  - Criar pelo slot ou pelo "+", sem passado. Detalhes com Editar, Confirmar, Realizado, Cancelar e Excluir. Cancelar e Excluir pedem confirmação. O 409 aparece no SnackBar e no form. A agenda sempre recarrega depois das ações.
- **4. Meus Agendamentos.** Abas Próximos e Histórico. Recarrega ao abrir, ao puxar e no `onResume`, e o listener é descartado no `dispose`. Não há cache. O cancelamento tem confirmação e trava, e a trava devolve "Aguarde".
- **5. Qualidade.**
  - O backend tem testes de integração dos endpoints novos (401/403/404/409/400 e "manter o mesmo horário").
  - O app tem widget tests e testes de rota.
  - O contrato ponta a ponta (`fluxo_admin_contract_test.dart`) executa de fato contra o backend real: admin cria → `/meus` → admin edita horário, status e serviço → cliente vê os dados novos → cancela → CANCELADO → exclui → `/meus` vazio. O teste de 403 para CLIENTE está no contrato do tester.
  - O gate falha se algum teste de contrato for pulado e se houver credencial de admin fixa no código.
- **Testes do tester intactos.** Os sha256 de `fase3_tester_test.dart` (`5e73603b…`), `fluxo_admin_tester_contract_test.dart` (`7833fcb7…`), `Fase3TesterIntegrationTest.java` (`895d938f…`), `Fase3RelogioFixoIntegrationTest.java` (`cf5d4239…`), `Fase3TesterVolta2IntegrationTest.java` (`d26bb5f1…`) e `fase3_volta3_tester_test.dart` (`8a194ff3…`) batem com `testes.md`. `gate.frozen.sh` é idêntico a `gate.sh` (`8ef4e3c8…`) e não foi modificado depois de congelado. Não encontrei teste enfraquecido.
- **Escopo.**
  - O web (`web/cortecertoweb`) está intocado (`git status` limpo nessa pasta).
  - Não há migration nova e não há commit no backend.
  - Nada vai além da FASE 3: os cards Clientes e Serviços ficaram de fora, e não há push/WebSocket.
- **Regras das FASES 1 e 2.** Nenhuma foi afrouxada. `salvarAgendamento` mantém o comportamento depois de extrair `validarNaoPassado`, e as regras do `AppConfig` estão preservadas.
