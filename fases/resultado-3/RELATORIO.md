# Relatório — FASE 3 (última): CRUD de agendamentos do admin e Meus Agendamentos

**Status: ENTREGUE** na volta 3 do loop. Não há commit em nenhum dos repositórios: as mudanças estão no working tree do app e na worktree do backend
`cortecerto-backend-loop` (branch `loop/mobile-migration`), para você revisar. O web Angular não foi alterado.

## Resumo do projeto inteiro (FASES 1, 2 e 3)
| Fase | O que entregou | Testes no fim da fase |
|---|---|---|
| **1. Backend seguro** | Senhas em BCrypt; login por CPF devolvendo JWT `{token,id,name,role}` (8h); bloqueio de conta (423) e rate limit por IP (429); admin criado a partir de `ADMIN_*` (o seed antigo foi neutralizado); validação do cadastro; autorização por role; DTOs sem senha e com CPF mascarado; índice único parcial (data, horario) para não cancelados com 409 também em concorrência; grade 08:00–19:30; nada no passado; `disponibilidades` no formato `["HH:mm"]`; migrations V2–V4; checklist de deploy no README do backend. | backend 164 |
| **2. Base do app e telas do cliente** | `lib/core` (um único ApiClient/Dio, interceptor com Bearer e 401 global, DI em `AppDependencies`, go_router, sessão no secure storage, `ApiErrorMapper`); Login, Cadastro, Serviços, Agendamento (table_calendar), Confirmado, Produtos e admin provisório; cleartext só no debug; V5 com 5 serviços (preços provisórios). | app 128, backend 168, contrato 1 |
| **3. Admin e visão do cliente** | Pendências da FASE 2 fechadas; endpoints de admin (listar/criar/editar/excluir/buscar clientes); `/agendamento/meus`; regras de cancelamento do cliente; Painel e Agenda Admin no app (CRUD completo); Meus Agendamentos com dados sempre vindos do servidor. | app 285, backend 217, contrato 3 |

Ao fim das três fases, o app Flutter cobre todo o fluxo do cliente e a agenda do admin, consumindo um backend endurecido. O web Angular **não** acompanha o contrato novo (veja "Riscos").

## O que foi entregue (FASE 3)

**0. Pendências da FASE 2**
- Mixin `NotificadorSeguro` (`lib/core/state/notificador_seguro.dart`) em todos os controllers. Sair de uma tela durante o carregamento não gera mais exceção.
- O Voltar do Android na tela Confirmado leva a `/servicos` (`PopScope`).
- `isPublica` compara o path exato.
- `Validators.senha` aceita só `[A-Za-z]` como letra, igual ao backend.
- O "hoje" do calendário do cliente é recalculado (getter com relógio injetável), e o teste "ontem desabilitado" usa uma data fixa.
- O teste da V5 agora compara os checksums do Flyway de V1..V5, e `fromObject` passou a se chamar `deErro`.

**1–2. Backend** (sem migration nova; nenhuma regra das FASES 1 e 2 foi afrouxada)
- `GET /agendamento/admin?data=&status=`: lista ordenada por horário com `id, data, horario, status, servicoId, servico, clienteId, nomeCliente, telefoneCliente`. O telefone aparece só nas rotas de admin. Nenhuma resposta traz CPF, e-mail ou senha.
- `POST /agendamento/admin` → 201, com CONFIRMADO como status padrão. `PUT /agendamento/admin/{id}` → 200: o 409 só vale contra **outro** agendamento, e reativar um CANCELADO num horário ocupado também dá 409. `DELETE /agendamento/admin/{id}` → 204.
- `PUT /agendamento/{id}/cancelar` continua funcionando para o admin em qualquer agendamento.
- `GET /clientes?busca=` aceita nome parcial ou dígitos do CPF e devolve no máximo 20 itens `{id, nome, cpf mascarado, telefone}`. Os curingas do LIKE são escapados. Sem `busca`, a listagem da FASE 1 continua igual.
- `GET /agendamento/meus` traz só os agendamentos do cliente do JWT, os mais recentes primeiro. O cliente cancela só o próprio agendamento futuro: de outro cliente → 404, passado → 400, já cancelado ou realizado → 409.
- `AppConfig`: `/agendamento/admin` e `/agendamento/admin/**` são `hasRole("ADMIN")`.

**3. App: Painel e Agenda Admin**
- **Painel** (`/admin`): saudação, card "Agenda" e Sair. Todas as rotas `/admin/**` bloqueiam o CLIENTE.
- **Agenda** (`/admin/agenda`):
  - Períodos Hoje, Amanhã e Data (picker robusto à virada da meia-noite). Cada troca busca do servidor.
  - Grade 08:00–19:30: horário ocupado mostra cliente, serviço e status com cor; horário livre mostra "Disponível" com "+"; horário livre que já passou mostra "Horário encerrado".
  - Contadores Total + 4 status, filtro por status, busca por nome e pull-to-refresh.
- **Formulário** (`/admin/agenda/form`): busca de cliente, serviço, data e horário livre (vindo de `disponibilidades`) e status inicial. Na edição, os dias passados ficam bloqueados, exceto a data original.
- **Detalhes** (bottom sheet): Editar, Confirmar, Marcar como realizado, Cancelar e Excluir. Cancelar e Excluir pedem confirmação. Toda ação mostra um SnackBar (o 409 aparece como "Horário indisponível") e a agenda recarrega depois.

**4. App: Meus Agendamentos** (`/meus-agendamentos`, acessível por Serviços e pela tela Confirmado)
- Abas Próximos e Histórico, com o status de cada agendamento.
- Recarrega ao abrir, ao puxar a lista e quando o app volta ao primeiro plano. Não há cache.
- O cliente cancela com confirmação e a lista recarrega.

## Como testar manualmente

### 1. Subir o backend (Git Bash, Java 21)
```bash
export JAVA_HOME=/c/Users/Usuario/.jdks/corretto-21.0.11; export PATH="$JAVA_HOME/bin:$PATH"   # o java do PATH é o 8
cd /c/Users/Usuario/Documents/Projetos/Dev/Projetos/cortecerto-backend-loop
java -version                                                   # tem que mostrar 21.0.11
export SECURITY_JWT_SECRET_KEY="$(openssl rand -base64 48)"     # obrigatória
export ADMIN_CPF=<um CPF válido seu>                            # o admin é criado no startup se o CPF ainda não existir
export ADMIN_SENHA='<mínimo 8 caracteres, com letra e número>'  # nunca versionar
export ADMIN_EMAIL=admin@cortecerto.local
export RATE_LIMIT_LIMITE=1000                                   # opcional, evita 429 nos testes manuais
export SPRING_DATASOURCE_URL="jdbc:sqlite:C:/temp/cortecerto-teste.db"   # recomendado: banco separado
./mvnw spring-boot:run                                          # http://localhost:8080/api
```
O backend está de pé quando `http://localhost:8080/api/api-docs` responde 200. O Swagger fica em `/api/swagger-ui.html`.

### 2. Rodar o app no emulador Android
```bash
cd /c/Users/Usuario/Documents/Projetos/Dev/Projetos/cortecerto_flutter
flutter pub get                    # sem o Modo de Desenvolvedor do Windows pode sair 1 (symlink); ative-o se o build falhar
flutter emulators --launch <id>
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
```

### 3. Roteiro de cliques (admin → cliente)
1. **Preparar um cliente:** no app, faça "Cadastre-se" com um CPF válido, entre e confirme que aparece "Olá, {nome}!". Toque em Sair.
2. **Admin entra:** faça login com `ADMIN_CPF`/`ADMIN_SENHA`. Deve aparecer o Painel Admin com a saudação e o card "Agenda". Toque em Agenda.
3. **Agenda:** troque entre Hoje, Amanhã e Data. Confira a grade de 08:00 a 19:30. Em "Hoje", os horários livres que já passaram aparecem como "Horário encerrado".
4. **Criar:** em Amanhã, toque num horário "Disponível" (ou no "+"). Busque o cliente pelo nome ou por dígitos do CPF, escolha serviço e horário, deixe o status PENDENTE e salve. Deve aparecer o SnackBar de sucesso, e o horário fica ocupado com a cor de pendente.
5. **Cliente vê:** saia e entre como o cliente. Em Serviços, abra "Meus Agendamentos": o agendamento aparece em Próximos como Pendente.
6. **Editar:** como admin, toque no agendamento → Editar → troque horário e serviço → salve. Tente também mover para um horário já ocupado: deve aparecer "Horário indisponível" (409). Como cliente, **puxe a lista para baixo** em Meus Agendamentos: os dados novos aparecem. Outra forma: mande o app para o segundo plano e volte.
7. **Confirmar e realizar:** como admin, use Confirmar (vira CONFIRMADO) e depois "Marcar como realizado". O cliente vê o agendamento no Histórico como Realizado.
8. **Cancelar:** crie outro agendamento e use Cancelar (pede confirmação). O horário volta a "Disponível" na grade, e o cliente vê CANCELADO no Histórico. Teste também o cliente cancelando um agendamento próprio em Próximos.
9. **Excluir:** como admin, Excluir (pede confirmação). O agendamento some da grade e, depois de um refresh, some de Meus Agendamentos.
10. **Filtros:** com vários agendamentos no dia, use o filtro por status e a busca por nome. Com filtro ativo, a tela vira lista (veja as decisões). Confira os contadores.
11. **Bloqueio:** logado como cliente, a rota `/admin/agenda` não abre (redirect). Pela API, um token de cliente em `/agendamento/admin` dá 403.

### 4. Testes automatizados
```bash
flutter analyze && flutter test                  # 285 (o contrato é pulado sem API_BASE_URL)
bash .loop/gate.sh                               # app + backend + contrato contra o backend real, com admin gerado no script
```

## Testes e checagens que passaram
- Gate congelado `.loop/gate.frozen.sh` com **exit 0**. Ele é idêntico a `gate.sh` (sha256 `8ef4e3c8…ab8fa86`) e a porta 8080 ficou livre depois.
- `flutter analyze`: No issues found. `flutter test --exclude-tags contract`: **285/285**.
- `./mvnw -B clean test`: **217 testes, 0 falhas**. Inclui o pacote `fase3` com 401/403/404/409/400, "manter o mesmo horário", relógio fixo e concorrência.
- **Contrato contra o backend real: 3/3, nenhum pulado** (FASE 2 + fluxo admin↔cliente + 403 do tester). O fluxo testado foi: admin cria → cliente vê em `/meus` → admin edita horário, status e serviço → cliente vê os dados novos → admin cancela → cliente vê CANCELADO → admin exclui → o agendamento some.
- Checagens estáticas: um único `Dio(`; APIs instanciadas só em `lib/app.dart`; nenhum print; nenhuma credencial de admin fixa no código; nenhum segredo no `.env.example`; o log não mostra senha nem CPF.
- Review da volta 3: **APROVADO** (0 bloqueantes, 0 importantes). Os hashes dos testes do tester conferem e nenhum teste foi enfraquecido.
- Histórico: na volta 1, o date picker do formulário quebrava com data acima de hoje+365. Na volta 2, quebrava o picker da Agenda depois da meia-noite. As duas falhas foram corrigidas e cobertas por testes de invariante (384 e 360 combinações).

### Decisões tomadas sem o humano (voltas 1 a 3)
1. **Decisão do humano:** na edição pelo admin, as regras de grade e de passado só valem quando **data ou horário mudam**. Isso permite marcar REALIZADO, ou mudar status ou serviço, depois do horário. Reenviar a mesma data e horário não conta como mudança.
2. Cliente cancelando um agendamento **já cancelado ou realizado → 409** (o TAREFA não definia; o passado continua dando 400).
3. O admin **não pode criar** um agendamento já com status CANCELADO (400). O form também não oferece essa opção.
4. Criar ou editar pelo admin com cliente ou serviço inexistente → **404**.
5. `criarAdmin` com um id que **não é CLIENTE** (ex.: o próprio admin) → **404 "Cliente não encontrado"**, indistinguível de inexistente.
6. `GET /clientes?busca=` devolve **só role CLIENTE**, ordenado por nome. Com `busca` vazia, devolve os 20 primeiros.
7. A busca ignora maiúsculas **só em ASCII**: o `LOWER` do SQLite não trata acentos, então "JOSÉ" não casa com "josé". Ela também não ignora acentos ("Jose" não acha "José").
8. Busca mista ("Ana 1") também casa CPFs que contenham os dígitos do termo (S3, BAIXA).
9. O admin continua podendo cancelar qualquer agendamento, inclusive passado ou já cancelado (idempotente). Mudar o status para CANCELADO pelo PUT tem o mesmo efeito do `/cancelar`.
10. Na Agenda, **com filtro ou busca ativos, a grade vira uma lista** só com os agendamentos que batem. Assim um horário ocupado por um agendamento escondido pelo filtro não aparece como "Disponível".
11. Num horário que tem um agendamento ativo e outros cancelados, o slot mostra o ativo. Um horário só com cancelados aparece como "Disponível", com a nota "N cancelado(s)".
12. Um horário livre que já passou aparece como **"Horário encerrado"**, desabilitado e sem "+". Na criação, uma data passada vira hoje e os horários que já passaram saem da lista.
13. Status desconhecido vindo da API vira `desconhecido` ("Desconhecido", cinza). Ele conta como ocupado, não oferece Confirmar nem Realizado e cai no Histórico do cliente.
14. Um segundo cancelamento em Meus Agendamentos enquanto outro está em andamento mostra "Aguarde o cancelamento em andamento." e não chama a API.
15. Próximos = futuros PENDENTE/CONFIRMADO, do mais próximo ao mais distante. Histórico = passados, cancelados e realizados, mais recentes primeiro.
16. Telefone ausente (o admin não tem telefone) aparece como "Não informado".
17. Os períodos "Hoje" e "Amanhã" da Agenda são recalculados a cada `carregar()`, e não por um listener de ciclo de vida (veja os riscos). O período "Data" fica fixo.
18. Na edição, o calendário bloqueia dias passados, exceto a data original e a data selecionada.

## Riscos e limitações conhecidas
- **Sugestões do review (não aplicadas):**
  1. Uma Agenda parada de um dia para o outro, sem nenhuma recarga, continua mostrando o dia anterior com o título "Hoje" até a próxima ação ou pull-to-refresh. É seguro, porque o backend recusa o passado. A solução é um `AppLifecycleListener` com `carregar()` no `onResume`.
  2. `agendamento_page.dart:68` (calendário do cliente, FASE 2) soma 90 dias com `Duration`. O risco é nulo enquanto o Brasil não tiver horário de verão.
  3. Faltam linhas em branco entre métodos e getters em `agenda_admin_controller.dart` e `agendamento_form_controller.dart` (só estilo).
- **Preços da V5 são PROVISÓRIOS:** Corte Simples 35,00, Corte + Barba 55,00, Barba 25,00, Sobrancelha 15,00 e Corte Completo 65,00. O CRUD de serviços pelo admin ficou fora do escopo, então os preços reais exigem uma **migration nova** (V6), porque a V5 não pode ser editada.
- **Não testado** (sem emulador nesta máquina):
  - o app rodando em emulador ou aparelho real;
  - `flutter build apk`;
  - o `flutter_secure_storage` real (Keystore);
  - o `network_security_config` (conferido só de forma estática);
  - a virada real da meia-noite e o `AppLifecycleListener` real (simulados com relógio injetado);
  - concorrência real entre dois aparelhos (simulada);
  - 423/429 contra o backend real;
  - auditoria de dependências (CVE).
- **O web Angular continua quebrado com o backend novo** e não foi alterado. Os motivos são `disponibilidades` no formato `["HH:mm"]`, a porta 8080, o CORS por variável de ambiente e o `clienteId` ignorado. Ele também chama um `agendamentos/data` que não existe. É preciso ajustá-lo ou aposentá-lo antes de publicar o backend.
- **Checklist de deploy do backend** (`cortecerto-backend-loop/README.md`, seção "Checklist de deploy (FASE 1)"), obrigatório:
  1. backup de `data/cortecerto.db`;
  2. conferir colisões de CPF/e-mail da V4;
  3. avisar os clientes cujos agendamentos duplicados a V3 vai cancelar;
  4. o `sub` do JWT agora é o id (antes era o CPF);
  5. a sessão agora dura 8h;
  6. definir `CORS_ALLOWED_ORIGINS` reais;
  7. definir `SECURITY_JWT_SECRET_KEY` e `ADMIN_*` só por variável de ambiente;
  8. a JVM roda em UTC.
  A FASE 3 não adicionou migration.
- **Segurança, só BAIXA (herdado):** um JWT de cliente removido continua válido até expirar (S1); a busca mista casa dígitos do CPF (S3); cancelamentos concorrentes não têm trava otimista (S6), mas não geram 500 e o estado final é sempre CANCELADO; Swagger público. Mais as limitações BAIXA da FASE 1 (algoritmo do JWT, janela do rate limit, BCrypt dentro da transação do SQLite).
- `Validators.dataNascimento` usa `DateTime.now()` quando a tela de cadastro não passa `hoje` (INFO).
- Não há atualização em tempo real (fora do escopo): o cliente vê as mudanças ao abrir a tela, ao puxar a lista ou ao voltar ao app.

## Sugestões de próximos passos
1. Revisar os diffs e rodar o roteiro acima num emulador. Rodar `flutter build apk` (com o Modo de Desenvolvedor do Windows ativo). Depois, fazer o commit nos dois repositórios: o app está em `main`, então crie um branch antes.
2. Rodar o checklist de deploy num backup do banco de produção antes de publicar o backend.
3. Definir os preços reais com uma V6, ou fazer o CRUD de Serviços no Painel (card "Serviços").
4. Próxima fase sugerida: cards "Clientes" e "Serviços" do Painel Admin.
5. Aplicar as três sugestões do review (o `onResume` na Agenda é o mais útil).
6. Busca de clientes insensível a acentos (normalizar em Java ou criar uma coluna normalizada).
7. Ajustar o web Angular ao contrato novo ou aposentá-lo.
8. Pendências BAIXA de segurança: fixar o algoritmo do JWT com plano de rotação, checar a conta no banco a cada request (S1) e proteger o Swagger em produção.
