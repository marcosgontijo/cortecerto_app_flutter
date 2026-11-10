# Tarefa — FASE 6: Exportar o faturamento em CSV (gerado no celular)

> Plano completo em `fases/README.md`. **Pré-requisito:** FASES 1 a 5 entregues (resultados em `fases/resultado-1..5/`).
> **Design system:** `design-system/cortecerto/MASTER.md` continua obrigatório para toda tela nova ou alterada.

## Repositórios envolvidos
| Papel | Caminho (Windows) | Pode editar? |
|---|---|---|
| App mobile (este repo) | `C:\Users\Usuario\Documents\Projetos\Dev\Projetos\cortecerto_flutter` | **Sim** |
| Backend Spring Boot (worktree, branch `loop/mobile-migration`) | `C:\Users\Usuario\Documents\Projetos\Dev\Projetos\cortecerto-backend-loop` | **Não** nesta fase (só roda os testes no gate) |
| Referência do web (Angular) | `cortecerto-backend-loop\web\cortecertoweb` | Não (somente leitura) |

## O que quero
Na tela **Faturamento** do admin, um botão para **exportar o período que está na tela** (dia, semana ou mês) como um arquivo **CSV gerado
no próprio celular**, que abre direto no **Excel em português** e pode ser compartilhado (WhatsApp, e-mail, Drive, Arquivos, abrir no Excel/Sheets).

## Decisões já tomadas
- **CSV, não `.xlsx`.** Gerado no app a partir do `Faturamento` que a tela já carregou do servidor. **Nenhuma mudança no backend.**
- **Compartilhar pela folha de compartilhamento do sistema** com o pacote `share_plus` (único pacote novo permitido; `path_provider` só se
  for realmente necessário para gravar o arquivo temporário — justificar no `.loop/dev.md`). Nada de requisição externa.
- **Formato para o Excel pt-BR:** codificação **UTF-8 com BOM**, separador **`;`**, decimal com **vírgula** e **sem separador de milhar**
  nos números (`1234,50`, para o Excel tratar como número), quebra de linha `\r\n`, datas `dd/MM/yyyy`.

## Critérios de aceite

### 1. Geração do CSV (função pura, testável sem tela)
- [ ] Uma função/classe em `lib/features/admin/` (ex.: `domain/faturamento_csv.dart`) recebe o `Faturamento` (e o período/rótulo) e devolve
      o texto do CSV. Não depende de Flutter widgets, `BuildContext` nem I/O.
- [ ] Conteúdo, nesta ordem, com uma linha em branco entre os blocos:
      1. Cabeçalho: `Faturamento CorteCerto`; `Período;<rótulo do período>` (o mesmo rótulo da tela) e `De;dd/MM/yyyy;Até;dd/MM/yyyy`.
      2. Resumo: `Indicador;Valor (R$);Atendimentos`, depois `Recebido;…;quantidadeRealizados` e `Previsto;…;quantidadePrevistos`.
      3. Por dia: `Data;Recebido (R$);Previsto (R$)` com **todos** os dias de `porDia` (inclusive zero), em ordem de data.
      4. Por serviço: `Serviço;Atendimentos;Recebido (R$)` na ordem que vier do servidor (recebido decrescente). Se a lista vier vazia,
         uma linha `Nenhum atendimento realizado neste período`.
- [ ] Valores convertidos do texto `'1234.50'` da API sem ponto flutuante (mesma abordagem segura da FASE 5) → `1234,50`; `'0.00'` → `0,00`.
- [ ] Escape CSV correto: campo com `;`, `"`, `\r` ou `\n` vai entre aspas e `"` vira `""` (ex.: serviço `Corte "Premium"; barba`).
- [ ] **Proteção contra injeção de fórmula** no Excel: campo de texto que começa com `=`, `+`, `-`, `@`, tab ou `\r` recebe um `'` na frente
      (nome de serviço vem do banco). Os números gerados pelo próprio app não são alterados.
- [ ] Sem nenhum dado pessoal de cliente (o `Faturamento` já não tem).
- [ ] Nome do arquivo derivado do período: Dia `faturamento_2026-11-09.csv`, Semana `faturamento_2026-11-09_a_2026-11-15.csv`,
      Mês `faturamento_2026-11.csv`.
- [ ] Os bytes finais começam com o BOM `EF BB BF` e o texto é UTF-8 (acentos como `Serviço` e `Período` preservados).

### 2. Tela Faturamento
- [ ] Ação **Exportar CSV** visível (ex.: `IconButton` na AppBar com ícone `file_download`/`ios_share` **e** `tooltip` "Exportar CSV", ou
      botão com ícone + texto), com área de toque ≥ 48dp.
- [ ] Habilitada só quando os dados do período estão carregados (desabilitada em carregando e em erro). No estado vazio (sem REALIZADO) continua
      habilitada se houver dados do período (o CSV sai com zeros/previsto).
- [ ] Exporta **exatamente o período e os dados mostrados** (sem nova requisição e sem cache entre períodos: se o período mudou e ainda está
      carregando, a ação fica desabilitada).
- [ ] Ao tocar: gera o arquivo e abre a folha de compartilhamento do sistema com o arquivo (`text/csv`) e um assunto/título com o período.
      Enquanto prepara, a ação não aceita toque duplo.
- [ ] Erro ao gerar/compartilhar → SnackBar clara ("Não foi possível exportar o faturamento"). Usuário fechar a folha sem compartilhar não é erro.
- [ ] O compartilhamento fica atrás de uma abstração injetada por construtor/Provider (ex.: `ExportadorArquivo`) para os testes usarem um fake;
      a implementação real usa `share_plus`. Nada de chamar `share_plus` direto da página.

### 3. Qualidade
- [ ] Testes de unidade do CSV: os 4 blocos e a ordem, BOM, `;`, vírgula decimal sem milhar, `\r\n`, dias com zero, por serviço vazio,
      escape de `;`/`"`/quebra de linha, injeção de fórmula (`=`, `+`, `-`, `@`), nomes de arquivo dos 3 períodos (inclusive semana que
      atravessa o mês/ano, ex.: 29/12/2025 a 04/01/2026), acentos em UTF-8.
- [ ] Widget tests da tela com API e exportador fakes: ação desabilitada em carregando/erro, habilitada com dados, toque chama o exportador
      com o nome e o conteúdo do período atual (inclusive depois de navegar para outro período), sem toque duplo, SnackBar no erro.
- [ ] A tela continua no harness de acessibilidade (guidelines + 360×640 com textScaler 2.0) com a ação nova.
- [ ] `flutter analyze` (zero erros e warnings), `flutter test` e `./mvnw -B clean test` passando, mais os testes de contrato.
      Nenhum teste anterior removido ou enfraquecido (os **519** testes Flutter e os **265** do backend da FASE 5 continuam passando).
- [ ] Configuração nativa que o `share_plus` exigir (ex.: Android) feita e explicada no `.loop/dev.md`; o app compila (`flutter build apk --debug`
      ou equivalente verificado pelo gate/tester).

## Gate desta fase (orientação para o tester)
Partir de `fases/resultado-5/gate.frozen.sh`:
- Manter todas as checagens do Flutter e as contagens mínimas (≥ 519 testes Flutter; ≥ 285 fora de `test/fase4`, `test/fase5`, `test/a11y` e da
  pasta nova desta fase; mínimos por arquivo das FASES 4 e 5) e acrescentar as contagens dos testes novos.
- **Backend volta a ser intocado:** HEAD igual a `b6d1fe0` e `git status --porcelain` vazio no backend. Continua rodando `./mvnw -B clean test`
  (≥ 265) e o contrato.
- Escopo de arquivos: só `lib/features/admin/**`, `lib/core/**` (se precisar de algo comum, ex.: a abstração do exportador), `lib/app.dart`
  (injeção), `pubspec.yaml`/`pubspec.lock`, configuração nativa exigida pelo `share_plus` e `test/`.
- Checagem estática: `share_plus` só importado no arquivo da implementação real do exportador.
- Porta via `GATE_PORTA` (padrão 8080; o hook usa 18080, porque o backend da IDE do usuário ocupa a 8080).

## Fora do escopo
- `.xlsx`, PDF, gráficos no arquivo, exportar vários períodos de uma vez, salvar direto em Downloads sem a folha de compartilhamento,
  endpoint de exportação no backend, exportar agendamentos com dados de clientes.

## Restrições
- Padrões das fases anteriores: app `lib/core` + `lib/features`, Provider, DI por construtor, ApiClient único, tokens do tema (nada de cor fixa,
  `fontSize` solto ou emoji em `lib/features`).
- Nenhum pacote novo além de `share_plus` (e `path_provider` se justificado no `.loop/dev.md`).
- Não fazer commit nem push no backend nem no app. **Java 21:** `export JAVA_HOME=/c/Users/Usuario/.jdks/corretto-21.0.11; export PATH="$JAVA_HOME/bin:$PATH"`.
- No Windows, `flutter pub get` pode sair com código 1 por falta do Modo de Desenvolvedor (symlink); isso não é falha do código.
