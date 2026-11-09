# Tarefa — FASE 5: Faturamento do admin + grade de horários uniforme

> Plano completo em `fases/README.md`. **Pré-requisito:** FASES 1 a 4 entregues (resultados em `fases/resultado-1..4/`).
> **Design system:** `design-system/cortecerto/MASTER.md` continua obrigatório para toda tela nova ou alterada.

## Repositórios envolvidos
| Papel | Caminho (Windows) | Pode editar? |
|---|---|---|
| App mobile (este repo) | `C:\Users\Usuario\Documents\Projetos\Dev\Projetos\cortecerto_flutter` | **Sim** |
| Backend Spring Boot (worktree, branch `loop/mobile-migration`) | `C:\Users\Usuario\Documents\Projetos\Dev\Projetos\cortecerto-backend-loop` | **Sim** (sem afrouxar nenhuma regra das FASES 1–4) |
| Referência do web (Angular) | `cortecerto-backend-loop\web\cortecertoweb` | Não (somente leitura) |

## O que quero
1. Uma nova opção **Faturamento** no Painel Admin para ver quanto a barbearia recebeu por **dia, semana e mês**.
2. A grade de horários do Agendamento do cliente com **colunas de largura igual** (hoje os chips "Livre" são mais estreitos que os
   "Indisponível" e sobra espaço vazio à direita).

## Decisões já tomadas pelo usuário
- **Recebido** = soma dos agendamentos com status **REALIZADO** no período. **Previsto** = soma dos **CONFIRMADO** e **PENDENTE** do período,
  mostrado à parte. **CANCELADO** nunca conta. (DESCONHECIDO não existe no backend.)
- **Preço guardado no agendamento:** o valor de cada agendamento é gravado no momento da criação, para que mudar o preço de um serviço
  depois não altere o faturamento passado.

## Contrato atual (FASES 1–4, não quebrar)
- Base `http://<host>:8080/api`. Login `POST /clientes/login` devolve `{token, id, name, role}`. Erros `{status, message, errors?}`.
- Todos os endpoints de agendamento, admin, clientes e serviços das FASES 1–3 continuam iguais (mesmos campos, códigos e regras).
- `servico.preco_servico` é texto no formato `'0.00'`.

## Critérios de aceite

### 1. Backend: preço no agendamento
- [ ] Migration Flyway nova (`V6__...`; V1–V5 intocadas) cria em `agendamento` uma coluna de valor **em centavos inteiros** (ex.: `valor_centavos`),
      preenche os agendamentos existentes com o preço atual do serviço de cada um e não aceita nulo depois do preenchimento
      (ou trata nulo de forma explícita e testada).
- [ ] Todo agendamento novo grava o valor do serviço no momento da criação: `POST /agendamento` (cliente) e `POST /agendamento/admin`.
- [ ] `PUT /agendamento/admin/{id}` que **troca o serviço** grava o valor do novo serviço; mudar só data, horário ou status mantém o valor.
- [ ] Mudar o preço de um serviço **não** altera o valor de agendamentos já criados (teste explícito).
- [ ] Conversão de `'35.00'` para centavos sem ponto flutuante (BigDecimal ou equivalente); preço inválido no serviço gera erro claro, não valor errado.

### 2. Backend: endpoint de faturamento (somente ADMIN; cliente → 403; sem token → 401)
- [ ] `GET /agendamento/admin/faturamento?inicio=AAAA-MM-DD&fim=AAAA-MM-DD` (intervalo fechado nas duas pontas) → 200 com:
      `inicio`, `fim`, `recebido`, `previsto` (valores em reais com 2 casas, como número decimal ou texto `'0.00'` — escolher um e documentar),
      `quantidadeRealizados`, `quantidadePrevistos`,
      `porDia`: lista de **todos** os dias do intervalo (inclusive os com zero) com `data`, `recebido`, `previsto`,
      `porServico`: lista com `servico`, `quantidade` (realizados) e `recebido`, ordenada por `recebido` decrescente.
- [ ] `inicio > fim`, data inválida ou intervalo maior que 366 dias → 400 no formato de erro padrão. Parâmetro ausente → 400.
- [ ] Nenhum dado pessoal de cliente na resposta.
- [ ] Usa o valor gravado no agendamento (não o preço atual do serviço).

### 3. App: tela Faturamento (ADMIN)
- [ ] Card **Faturamento** no Painel Admin (ícone + texto, mesmo padrão do card Agenda) que leva a `/admin/faturamento`.
      A rota segue o bloqueio de `/admin/**` (CLIENTE é redirecionado).
- [ ] Seletor de período **Dia / Semana / Mês** (`SegmentedButton` ou equivalente do tema). Semana = **segunda a domingo** que contém a data;
      Mês = mês do calendário. Setas "anterior" e "próximo" (com tooltip) e o rótulo do período (ex.: "09/11/2026", "03/11 – 09/11/2026",
      "novembro de 2026"). Abre em **Dia = hoje**.
- [ ] Cards de resumo: **Recebido** em destaque (valor grande em R$) e **Previsto** à parte, com a quantidade de atendimentos de cada um.
- [ ] Na Semana e no Mês: lista **por dia** com uma barra horizontal proporcional ao recebido (barra feita com widgets do tema, sem pacote de
      gráfico) e o valor em texto (a informação nunca depende só da barra). Em todos os períodos: lista **por serviço**.
- [ ] Estados carregando, vazio ("Nenhum atendimento realizado neste período") e erro com "Tentar novamente"; pull-to-refresh;
      os dados são sempre buscados no servidor (sem cache).
- [ ] Valores formatados em pt-BR (`R$ 1.234,50`) com o `Formatters` existente.

### 4. App: grade de horários uniforme (tela Agendamento do cliente)
- [ ] Os horários ficam numa grade de **colunas de largura igual** que preenche a largura disponível (ex.: 3 colunas em 360–599dp, mais colunas
      em telas largas, menos colunas quando o texto estiver grande para não estourar). Todos os chips da mesma linha têm a mesma largura.
- [ ] Mantém tudo da FASE 4: Keys `horario-HH:mm` e `horario-indisponivel-HH:mm`, "Livre/Escolhido/Indisponível" com ícone e texto,
      indisponível desabilitado, área de toque ≥ 48dp, sem overflow com texto a 200% em 360×640.

### 5. Qualidade
- [ ] Backend: testes de integração da migration (preenchimento dos existentes), do valor gravado na criação/troca de serviço, da independência
      da mudança de preço e do endpoint de faturamento (somas por status, CANCELADO fora, dias com zero, por serviço, limites do intervalo,
      401, 403, 400).
- [ ] App: widget tests da tela Faturamento (dia/semana/mês, navegação de período com cálculo de segunda a domingo, resumo, listas, 3 estados,
      refresh) com API fake; teste de rota de `/admin/faturamento` (CLIENTE bloqueado); teste da grade uniforme (larguras iguais na linha e
      preenchimento da largura em 360 e 800dp); a tela Faturamento e o Painel entram no harness de acessibilidade
      (guidelines + 360×640 com textScaler 2.0).
- [ ] **Contrato ponta a ponta** (`test/contract/`, backend real): admin cria agendamento → marca REALIZADO → faturamento do dia mostra o valor
      em `recebido`; outro agendamento CONFIRMADO aparece em `previsto`; um CANCELADO não aparece; CLIENTE no endpoint de faturamento → 403.
- [ ] `./mvnw -B clean test`, `flutter analyze` (zero erros e warnings) e `flutter test` passando. Nenhum teste anterior removido ou enfraquecido
      (os 454 testes Flutter e os 217 do backend da FASE 4 continuam passando; ajustes intencionais com a mesma verificação, registrados no dev.md).

## Gate desta fase (orientação para o tester)
Partir de `fases/resultado-4/gate.frozen.sh`:
- Manter todas as checagens do Flutter e as contagens mínimas (≥ 454 testes Flutter passando, ≥ 285 fora de `test/fase4`, `test/a11y` e da pasta
  nova desta fase; mínimos por arquivo da FASE 4) e acrescentar as contagens dos testes novos.
- **Backend agora é editável:** trocar a checagem "backend intocado" por "backend sem commit novo" (HEAD igual a `7620220`) e
  "V1–V5 sem alteração" (checksum ou diff vazio nesses arquivos).
- Porta via `GATE_PORTA` (padrão 8080; o hook usa 18080, porque o backend da IDE do usuário ocupa a 8080).
- O teste `AgendamentoAdminIntegrationTest.buscaDeClientesTrataPercentUnderlineEBarraComoTexto` é **intermitente** (CPF aleatório contendo
  "100", ~3–4%). Como o backend agora é editável, **corrigir o teste** (ex.: conferir o id esperado em vez da quantidade ou fixar os CPFs),
  sem afrouxar o que ele verifica.

## Fora do escopo
- Faturamento de produtos (a compra de produtos é feita na barbearia, fora do app), formas de pagamento, comissões, despesas, exportação
  (PDF/CSV), gráficos com pacote externo, edição de preço de serviço pelo app.
- Tema claro, telas novas para o cliente, mudanças no web Angular.

## Restrições
- Padrões das fases anteriores: backend controller → service → repository + DTO + Flyway; app `lib/core` + `lib/features`, Provider,
  DI por construtor, ApiClient único, tokens do tema (nada de cor fixa, `fontSize` solto ou emoji em `lib/features`).
- Nenhum pacote novo sem justificar no `.loop/dev.md`.
- Não fazer commit nem push no backend. **Java 21:** `export JAVA_HOME=/c/Users/Usuario/.jdks/corretto-21.0.11; export PATH="$JAVA_HOME/bin:$PATH"`.
- No Windows, `flutter pub get` pode sair com código 1 por falta do Modo de Desenvolvedor (symlink); isso não é falha do código.
