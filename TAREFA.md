# Tarefa — FASE 4: Redesign de UI/UX das telas do app

> Plano completo em `fases/README.md`. **Pré-requisito:** FASES 1, 2 e 3 entregues (resultados em `fases/resultado-1..3/`).
> **Design system:** `design-system/cortecerto/MASTER.md` (proposto pela skill `ui-ux-pro-max`). É a referência visual obrigatória desta fase.

## Repositórios envolvidos
| Papel | Caminho (Windows) | Pode editar? |
|---|---|---|
| App mobile (este repo) | `C:\Users\Usuario\Documents\Projetos\Dev\Projetos\cortecerto_flutter` | **Sim** (só camada visual, ver Restrições) |
| Backend Spring Boot (worktree, branch `loop/mobile-migration`) | `C:\Users\Usuario\Documents\Projetos\Dev\Projetos\cortecerto-backend-loop` | **Não** nesta fase (só roda os testes no gate) |
| Referência do web (Angular) | `cortecerto-backend-loop\web\cortecertoweb` | Não (somente leitura) |

## O que quero
Refazer o visual e a usabilidade de todas as telas já existentes (Login, Cadastro, Serviços, Produtos, Agendamento, Confirmado,
Meus Agendamentos, Painel Admin, Agenda Admin e formulário de agendamento do admin) seguindo o design system, **sem mudar regras
de negócio, contrato com o backend nem rotas**. O objetivo é o usuário entender cada tela de primeira, errar menos e ter retorno
claro de tudo o que faz.

## Critérios de aceite

### 1. Tema e tokens
- [ ] `lib/core/theme/` expõe os tokens do MASTER.md: `ColorScheme` escuro com as cores da tabela e um `ThemeExtension` (ex.: `AppStatusColors`
      ou `AppTokens`) para `success`, `warning`, `info`, `neutral`, espaçamentos e raios. `TextTheme` com a escala do MASTER.md.
- [ ] Temas de componente configurados no `ThemeData`: `FilledButton`, `OutlinedButton`, `TextButton`, `InputDecoration`, `Card`, `Chip`,
      `AppBar`, `NavigationBar`, `SnackBar` (flutuante), `Dialog`, `FloatingActionButton`.
- [ ] `StatusAgendamento` deixa de guardar `Color` fixa: a cor vem do tema; `StatusChip` mostra **ícone + texto** (ícones do MASTER.md).
- [ ] Nenhum `Color(0x…)`, `Colors.<cor>` (exceto `Colors.transparent`) nem `TextStyle(fontSize: …)` em `lib/features/**`.
      Nenhum emoji em `lib/` (inclusive comentários do tema).
- [ ] Teste de unidade que calcula o contraste WCAG dos pares do MASTER.md a partir dos tokens reais: texto ≥ 4.5:1, `outline` ≥ 3:1.

### 2. Componentes comuns (`lib/core/widgets/`)
- [ ] `EstadoCarregando`, `EstadoVazio` (ícone, título, texto, ação opcional) e `EstadoErro` (mensagem + "Tentar novamente" que chama o recarregar
      do controller). Toda tela com lista ou carregamento usa os três.
- [ ] Botão primário com estado de envio (indicador + desabilitado enquanto envia, sem toque duplo).
- [ ] Diálogo de confirmação reutilizável para ações destrutivas (botão destrutivo na cor `error`).

### 3. Telas
- [ ] **Login / Cadastro:** cabeçalho com a marca CorteCerto, rótulos visíveis, ícones nos campos, máscara de CPF/telefone mantida, erro embaixo
      do campo, mostrar/ocultar senha (com rótulo acessível), `textInputAction` next/done (o "done" do último campo envia), `autofillHints`,
      botão com estado de envio, link claro entre Login e Cadastro. Erro do servidor em SnackBar ou bloco de erro visível perto do botão.
- [ ] **Navegação do cliente:** `NavigationBar` inferior com Serviços, Meus agendamentos e Produtos, mantendo os paths atuais
      (`Rotas.servicos`, `Rotas.meusAgendamentos`, `Rotas.produtos`) e o logout acessível em todas elas. Agendamento e Confirmado ficam fora da barra.
- [ ] **Serviços:** cards com nome, preço (e duração, se a API já devolver) e ação "Agendar" clara; estados carregando/vazio/erro.
- [ ] **Produtos:** lista em cards selecionáveis; barra inferior fixa (com `SafeArea`) com quantidade e total; a lista não fica escondida atrás da barra.
- [ ] **Agendamento:** indicador de etapas (Data → Horário → Confirmar, com o serviço escolhido visível no topo); horários em grade de chips
      ≥ 48dp, ocupados desabilitados e marcados também por texto/ícone (não só cor); resumo (serviço, data, horário, preço) antes de confirmar;
      botão confirmar fixo embaixo, desabilitado até escolher horário; 409 mostra mensagem clara e recarrega os horários.
- [ ] **Confirmado:** ícone de sucesso, resumo do agendamento, CTA primário "Ver meus agendamentos" e secundário "Voltar aos serviços".
      O Voltar do Android continua indo para `/servicos`.
- [ ] **Meus Agendamentos:** abas Próximos/Histórico mantidas, cards com data/horário em destaque e `StatusChip`; estado vazio por aba com ação
      "Agendar um horário"; cancelar com o diálogo de confirmação e SnackBar de resultado.
- [ ] **Painel Admin:** saudação e cards grandes com ícone (Agenda) seguindo o tema.
- [ ] **Agenda Admin:** seletor Hoje/Amanhã/Data com `SegmentedButton` ou chips; contadores por status viram chips de filtro; grade com horários
      livres claramente tocáveis ("Disponível" + ícone de adicionar) e ocupados com cliente, serviço e `StatusChip`; FAB "Novo agendamento";
      detalhes em bottom sheet ou tela com ações agrupadas (destrutivas separadas e em `error`).
- [ ] **Formulário de agendamento (admin):** mesmas regras de campo do Login/Cadastro; busca de cliente com estado vazio/carregando.

### 4. Acessibilidade e usabilidade (verificado por teste)
- [ ] Para cada tela acima, widget test com APIs fake que passa em `androidTapTargetGuideline`, `labeledTapTargetGuideline` e
      `textContrastGuideline` (`expect(tester, meetsGuideline(...))`).
- [ ] Para cada tela, widget test em 360×640 com `textScaler` 2.0 sem overflow nem exceção.
- [ ] Botões só com ícone têm `tooltip` ou `Semantics(label:)`.
- [ ] Com `disableAnimations: true` não há animação de transição de etapa/estado (teste em pelo menos uma tela que anima).

### 5. Sem regressão
- [ ] Todos os testes das FASES 1–3 continuam passando. Nenhum teste removido ou enfraquecido; se um texto/estrutura mudar de propósito, o teste
      é atualizado para o novo texto com a **mesma** verificação de comportamento. `Key`s usadas pelos testes atuais são mantidas.
- [ ] Controllers, APIs, `ApiClient`, sessão, rotas (paths e redirects por papel) e contrato com o backend sem mudança de comportamento.
- [ ] `flutter analyze` com zero erros e warnings, `flutter test` e `./mvnw -B clean test` (backend intocado) passando, mais os testes de contrato.

## Gate desta fase (orientação para o tester)
Partir de `fases/resultado-3/gate.frozen.sh` (backend + Flutter + contrato) e acrescentar checagens estáticas:
`grep` sem `Color(0x`, `Colors\.` (exceto `transparent`) e `TextStyle(` com `fontSize` em `lib/features/`; sem emojis em `lib/`;
`git -C <backend> status --porcelain` igual ao do início da fase (backend não editado). Manter todas as checagens das fases anteriores.

## Fora do escopo
- Fontes personalizadas (a skill sugeriu Cormorant + Montserrat ou DM Sans): exigem baixar arquivos ou `google_fonts` (rede em tempo de execução).
  Fica para quando os arquivos de fonte forem adicionados ao repo manualmente.
- Tema claro (os tokens devem permitir isso depois, mas nesta fase só o escuro).
- Telas novas, CRUD de serviços/produtos/clientes, logo/ilustrações novas, mudanças no backend ou no web.

## Restrições
- Mexer só em `lib/core/theme/`, `lib/core/widgets/`, `lib/features/**/presentation/*_page.dart` (e widgets de apresentação novos ao lado delas),
  `status_agendamento.dart` (só a parte visual), `app.dart`/`app_router.dart` **apenas** para o tema e a `NavigationBar` (ShellRoute permitido,
  sem mudar paths nem redirects) e `test/`.
- Nenhum pacote novo no `pubspec.yaml` sem justificar no `.loop/dev.md`; nada que faça requisição de rede em tempo de execução além da API do app.
- Padrões das fases anteriores: `lib/core` + `lib/features`, Provider, DI por construtor, ApiClient único.
- Não fazer commit nem push no backend. **Java 21:** `export JAVA_HOME=/c/Users/Usuario/.jdks/corretto-21.0.11; export PATH="$JAVA_HOME/bin:$PATH"`.
- No Windows, `flutter pub get` pode sair com código 1 por falta do Modo de Desenvolvedor (symlink); isso não é falha do código.
