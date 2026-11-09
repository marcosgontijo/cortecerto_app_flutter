# dev.md — FASE 5, volta 1 (Faturamento do admin + grade de horários uniforme)

## Ponto de partida (repo / branch / HEAD)
| Repo | Branch | HEAD | Status inicial |
|---|---|---|---|
| App `cortecerto_flutter` | `main` | `ffeb405` | `M TAREFA.md`, `?? .claude/skills/` (não são meus, preservados) |
| Backend `cortecerto-backend-loop` | `loop/mobile-migration` | `7620220` | limpo |

Não havia `.loop/feedback.md` nem `.loop/historico.md` (primeira volta). Nenhum commit/push. O HEAD do backend continua `7620220`.
V1–V5 sem diff: `git diff --quiet 7620220 -- V1..V5` → código 0.

## Mudanças

### Backend
1. **Conversor de preço sem ponto flutuante** — hipótese: `'35.00'` → centavos com BigDecimal, recusando o que não for `^[0-9]{1,13}(\.[0-9]{1,2})?$`.
   Arquivo: `src/main/java/.../util/PrecoUtils.java` (`paraCentavos`, `deCentavos`, `PrecoInvalidoException`).
   Verificação: `fase5/PrecoUtilsTest` (20 casos: `'35.00'`→3500, `'0.00'`→0, `'1234.50'`→123450, `null`, `''`, `'abc'`, `'R$ 30,00'`, `'-5.00'`, `'35.123'`, `'1e3'`, `'NaN'`...). `grep -nE 'double|Double|float|Float'` no conversor e no `FaturamentoService` → nada (rc=1). **Manter.**
2. **V6** `db/migration/V6__valor_centavos_agendamento.sql` — `ADD COLUMN valor_centavos INTEGER NOT NULL DEFAULT 0 CHECK (valor_centavos >= 0)` + `UPDATE` de preenchimento só com texto (GLOB/REPLACE/CAST AS INTEGER; nada de REAL). Cabeçalho explica o porquê e traz a consulta que lista os casos com preço inválido; o README ganhou o item 6 no "Checklist de deploy" e uma seção do endpoint.
   Verificação: `fase5/MigrationV6ValorCentavosTest` (4): migra até 5, insere serviços `'35.00'`, `'55.00'`, `'1234.50'`, `'40'`, `'7.5'`, `' 12.34 '`, `'0.00'` + agendamentos com status variados (inclusive CANCELADO) → 3500/5500/123450/4000/750/1234/0; preço NULL/vazio/`R$ 30,00`/`-5.00`/`35.123`/`abc`/`1.000.00`/`35.` → 0 sem falhar; NULL explícito → erro NOT NULL (INSERT e UPDATE); negativo → CHECK; INSERT cru sem a coluna → DEFAULT 0; índice da V3 continua. `MigrationsFlywayTest` e `AgendamentoIntegrationTest` (INSERT cru da linha 79) seguem verdes sem edição. **Manter.**
3. **Entidade** `model/Agendamento.java`: campo `valorCentavos` (`@Column(name="valor_centavos", nullable=false)`); mantive o construtor de 6 argumentos (calcula o valor pelo preço atual do serviço), então os 3 testes da FASE 3 que fazem `new Agendamento(null, c, s, d, h, st)` compilam e passam sem edição. Verificação: `./mvnw -B test` logo depois → 217/217. **Manter.**
4. **Service** `AgendamentoService`: grava o valor em `salvarAgendamento` (cliente) e `criarAdmin`; em `atualizarAdmin` só quando o `servicoId` **muda** (D5); data, horário, status ou o mesmo serviço mantêm o valor. Preço inválido → `ApiException(422, "Preço do serviço inválido; ajuste o cadastro do serviço antes de agendar")` antes do `save` (nada gravado). Os DTOs das FASES 1–4 **não** mudaram (teste confere os campos exatos da resposta do admin).
   Verificação: `fase5/ValorAgendamentoIntegrationTest` (8). **Manter.**
5. **Endpoint** `GET /agendamento/admin/faturamento?inicio&fim` em `AgendamentoAdminController` → `service/FaturamentoService` → `findAllByDataBetween` + agregação em Java com `long` de centavos (`Math.addExact`) → `dto/FaturamentoDTO`, `FaturamentoDiaDTO`, `FaturamentoServicoDTO`. Segurança: já coberto pelo matcher `/agendamento/admin/**` (ADMIN). 400: `inicio > fim`, > 366 dias; ausente/data inválida pelo handler existente.
   Verificação: `fase5/FaturamentoIntegrationTest` (12): campos exatos, somas por status, CANCELADO fora, 7 dias com zeros em ordem, por serviço ordenado (e desempate), pontas do intervalo, valor gravado vs preço atual, 400 (10 casos + mensagens), 366 passa/367 não, 401/403, sem dados pessoais, fluxo pela API. **Manter.**
6. **Teste intermitente** `fase3/AgendamentoAdminIntegrationTest.buscaDeClientesTrataPercentUnderlineEBarraComoTexto` — causa: CPFs aleatórios dos outros 4 clientes podiam conter "100" e casar a busca `"100%"` (o service extrai os dígitos e busca `cpf like '%100%'`). Correção: esses 4 clientes agora recebem CPF válido aleatório **sem "100"** (helper `registrarComCpfSemDigitos`). Nada foi afrouxado: as asserções continuam `length == 1`, e a busca `"100%"` ganhou **mais** uma asserção (`$[0].id == clienteId`).
   Verificação: o método rodado 30 vezes em loop (`./mvnw -B -q test -Dtest=AgendamentoAdminIntegrationTest#buscaDe...`) → `ok=30 fail=0`. **Manter.**

Backend final: `./mvnw -B clean test` → **exit 0, 261 testes, 0 falhas, 0 erros, 0 pulados** (217 anteriores + 44 novos em `fase5/`: Faturamento 12, MigrationV6 4, PrecoUtils 20, ValorAgendamento 8).

### App
7. **Domínio/API**: `lib/features/admin/domain/faturamento.dart` (modelo; `centavosDe` converte o texto `"1234.50"` em int sem `double`; número também é aceito), `domain/periodo_faturamento.dart` (`TipoPeriodo` Dia/Semana/Mês; semana seg–dom pela data; mês do calendário; rótulos `09/11/2026`, `09/11 – 15/11/2026`, `29/12/2025 – 04/01/2026`, `novembro de 2026`; contas por campos de data, sem `Duration`). Método `faturamento(inicio, fim)` **em `AdminAgendamentoApi`** (sem API nova, então `AppDependencies` e os 6 testes que o constroem não mudaram).
8. **Tela**: `presentation/faturamento_controller.dart` (abre em Dia = hoje, relógio injetável, sem cache, descarta resposta de período antigo) e `faturamento_page.dart` (`SegmentedButton`, setas com tooltip "Período anterior"/"Próximo período", cards `faturamento-recebido` em `headlineMedium` e `faturamento-previsto` em `titleLarge`, lista por dia com barra de widgets do tema + valor em texto (barra em `ExcludeSemantics`), lista por serviço, `EstadoCarregando`/`EstadoVazio`/`EstadoErro`, `RefreshIndicator` com `AlwaysScrollableScrollPhysics`). Rota `Rotas.adminFaturamento = '/admin/faturamento'` (`nomeAdminFaturamento`) em `app_router.dart`, coberta pelo bloqueio de `/admin/**` sem código novo no redirect. Painel: card `card-faturamento` no mesmo padrão do Agenda (extraí `_CardPainel`; a Key `card-agenda` ficou no widget do card, mesmo tamanho e mesmos descendentes).
9. **Grade uniforme** em `agendamento_page.dart` (`_Horarios`): `LayoutBuilder` → `colunasDaGradeDeHorarios` mede com `TextPainter` + `textScaler` atual o conteúdo mais largo do chip e calcula `floor((largura + 8) / (mínimo + 8))`, entre 1 e 6; linhas em `Row` com `Expanded` (sem `GridView`, sem `AnimatedSwitcher` novo). Para caber 3 colunas em 360 dp com a fonte real, o ícone saiu do `avatar` e foi para a linha do horário dentro do label, e o padding horizontal do chip ficou `t.xs / 2`. Keys continuam no próprio `ChoiceChip`; ícones `schedule`/`check_circle`/`block` e textos "Livre/Escolhido/Indisponível" mantidos.

Verificações do app:
- `flutter analyze` → **No issues found!** (exit 0).
- `flutter test --exclude-tags contract` → **509 passaram, 0 falhas, 0 pulados** (exit 0). Por arquivo: `a11y/acessibilidade_test.dart` 67 (era 57), fora de `fase4`/`a11y`/`fase5` = **285** (igual), `fase5/`: faturamento_page 14, grade_horarios 8, periodo_faturamento 11, faturamento_api 7, rota_faturamento 5.
- Contrato com backend real (jar em `target/`, banco NOVO `target/dev-contract-*.db`, porta 18081, segredos aleatórios inline, processo encerrado depois): `flutter test --tags contract test/contract` → **4/4 passaram** (3 antigos + `faturamento_contract_test.dart`).
- Checagens estáticas em `lib/features`: nenhum `Color(0x`, `Colors.x` (fora `transparent`), `fontSize` ou emoji; as 2 `IconButton` novas têm `tooltip`. Nenhum pacote novo.
- `data/cortecerto.db` (banco do usuário) **não** foi usado: lido só em modo read-only no fim → `flyway_schema_history` = 1..5 e sem a coluna `valor_centavos`.

## Decisões D1–D8 (recomendações do contexto adotadas)
- **D1** Agendamento legado com preço NULL/inválido → `valor_centavos = 0`, sem falhar a V6; documentado no cabeçalho da V6 e no README (consulta para listar antes do deploy); testado.
- **D2** Valores do faturamento em **texto `"0.00"`** (Javadoc do `FaturamentoDTO`); o app converte para centavos inteiros e só divide por 100 para exibir.
- **D3** Limite contando as duas pontas: `DAYS.between + 1 > 366` → 400. 366 passa (2028 inteiro), 367 dá 400 (testado).
- **D4** `ADD COLUMN ... NOT NULL DEFAULT 0` (+ `CHECK >= 0`) e preenchimento; sem reconstruir a tabela. NULL explícito recusado (testado). `AgendamentoIntegrationTest:79` não precisou de ajuste.
- **D5** `PUT` com o mesmo `servicoId` não é troca: valor mantido (testado, inclusive com o preço alterado no meio).
- **D6** `porServico` agrupado por `servico.id`, exibe `tipoServico`, só serviços com ≥ 1 REALIZADO, ordem por recebido desc e desempate pelo nome (sem diferenciar maiúsculas).
- **D7** Vazio (`quantidadeRealizados == 0`): cards de resumo continuam (Recebido R$ 0,00 e o Previsto) e a mensagem "Nenhum atendimento realizado neste período" substitui as listas.
- **D8** Preço inválido ao criar/trocar → **422** `{status, message}` com mensagem clara; nada gravado (testado no POST do cliente, POST admin e PUT de troca).

## Ajustes em testes/infra de teste existentes (intencionais, mesma verificação)
- `fase3/AgendamentoAdminIntegrationTest`: correção do intermitente (acima). Mesmas asserções + 1 asserção nova.
- `test/a11y/telas_harness.dart`: `TelaF4.faturamento` (entra sozinha nos grupos 4.1 e 4.2 que percorrem `TelaF4.values`), `EstadoF4.semana`/`mes` e `faturamentoFake`. Nenhum caso antigo mudou.
- `test/a11y/acessibilidade_test.dart`: só acrescentei 4 estados extras do Faturamento (vazio, erro, semana, mês) nas listas de 4.1 e 4.2.
- `test/helpers/widget_helpers.dart`: rota stub `TELA faturamento` no `comRouter` (só acréscimo).
- Nenhum teste removido; nenhum `expect` antigo alterado.

## Itens do feedback resolvidos e não resolvidos
Não havia feedback (volta 1). Todos os critérios de aceite 1–5 foram implementados e têm teste; ver números acima.

## Tentativas que falharam (para ninguém repetir)
- **Heredoc do Bash tool come barra invertida**: `\\` dentro de heredoc (mesmo com `'EOF'`) chegou como `\`. Resultado: regex Java `"\d..."` quebrou a compilação e scripts Python com `'\\'` falharam. Use a ferramenta Write/Edit para arquivos com barra invertida (ou `chr(92)`).
- Arquivos Java do backend são CRLF; replace via Python com `\n` não casa. Ler com newline universal e gravar com `newline='\r\n'`, ou usar Edit.
- Grade: com o chip antigo (ícone no `avatar`, padding `t.xs` + `labelPadding` padrão) só cabia **1 coluna** em 360 dp na fonte de teste e ~2 na Roboto. Por isso o ícone foi para dentro do label e o padding foi reduzido.

## Dúvidas, suposições e o que ficou sem verificar
- **09/11/2026 é segunda-feira**, não domingo como diz o `contexto.md` (tabela 3.4). O rótulo de exemplo da TAREFA ("03/11 – 09/11/2026") é só de formato. Os testes usam o calendário real: hoje = 09/11/2026 → Semana `09/11 – 15/11/2026`; quarta 05/11 → `02/11 – 08/11/2026`. O tester não deve copiar o "03..09/11" do contexto.
- **Colunas da grade na fonte de teste**: o flutter_test usa glifos quadrados (bem mais largos). Lá dá **2 colunas em 360 dp** e 4 em 800 dp; a 200% em 360, 1 coluna. Com a **Roboto** (carregada do SDK, `FLUTTER_ROOT/bin/cache/artifacts/material_fonts`) o teste confirma **3 colunas em 360 dp**, mais de 3 em 800 e menos de 3 a 200%. Se `FLUTTER_ROOT` não existir no ambiente, os 3 testes "Roboto" falham com mensagem clara (o `flutter test` define essa variável).
- Navegação entre tipos: trocar Dia/Semana/Mês mantém uma "data de referência" (ex.: Dia 10/11 → Semana 09/11–15/11); as setas deslocam essa referência (mês com o dia limitado ao último dia do mês).
- Resposta do faturamento não tem limite inferior/superior de data além dos 366 dias (não pedido).
- Não testei em aparelho real (só fonte de teste e Roboto no flutter_test).
- O gate (`.loop/gate.sh`) é do tester: ele precisa trocar "backend intocado" por "HEAD == 7620220" + "V1–V5 sem diff", rever a lista 4.16 (arquivos novos em `lib/features/admin/{domain,presentation}` e `rotas.dart`/`app_router.dart` alterados) e acrescentar `test/fase5` e as contagens novas.
