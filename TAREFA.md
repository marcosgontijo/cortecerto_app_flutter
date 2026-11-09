# Tarefa — FASE 3 de 3: CRUD de agendamentos do admin e visão do cliente

> Plano completo em `fases/README.md`. **Pré-requisito:** FASES 1 e 2 entregues (resultados em `fases/resultado-1/` e `fases/resultado-2/`).

## Repositórios envolvidos
| Papel | Caminho (Windows) | Pode editar? |
|---|---|---|
| App mobile (este repo) | `C:\Users\Usuario\Documents\Projetos\Dev\Projetos\cortecerto_flutter` | **Sim** |
| Backend Spring Boot (worktree, branch `loop/mobile-migration`) | `C:\Users\Usuario\Documents\Projetos\Dev\Projetos\cortecerto-backend-loop` | **Sim** (sem afrouxar nenhuma regra das FASES 1 e 2) |
| Referência do web (Angular) | `cortecerto-backend-loop\web\cortecertoweb` (ver `components/agenda-admin` e `admin-panel`) | Não (somente leitura) |

> No WSL, troque `C:\` por `/mnt/c/` e `\` por `/`.

## O que quero
Dar ao admin um CRUD completo de agendamentos (backend + Painel Admin e Agenda Admin no app, inspirados na agenda do web) e garantir
que o cliente sempre veja os dados atualizados depois das alterações do admin. Antes disso, fechar as pendências deixadas pela FASE 2.

## Contrato atual (FASES 1 e 2, não quebrar)
- Base `http://<host>:8080/api`. Login devolve `{token, id, name, role}`. Erros no formato `{status, message, errors?}`.
- `POST /agendamento` (cliente do JWT), `GET /agendamento/disponibilidades?data=`, `GET /agendamento/{id}`, `PUT /agendamento/{id}/cancelar`,
  `GET /agendamento/agenda/hoje` (ADMIN), `GET /clientes` e `/clientes/{id}` (ADMIN, CPF mascarado), `GET /servicos`.
- Status: `PENDENTE`, `CONFIRMADO`, `CANCELADO`, `REALIZADO`. O índice único (data, horario) vale para todo agendamento **não CANCELADO**.
- Regras de agenda: grade 08:00–19:30 de 30 em 30 min, nada no passado, 409 em conflito (inclusive concorrente).

## Critérios de aceite

### 0. Pendências da FASE 2 (fazer primeiro)
- [ ] Controllers não chamam `notifyListeners()` depois de descartados (guard ou mixin comum), com teste de sair da tela durante o carregamento sem exceção.
- [ ] Tela Confirmado: o Voltar do Android leva para `/servicos` (`PopScope`), sem fechar o app.
- [ ] `AuthInterceptor.isPublica` compara o path exato (não `endsWith`).
- [ ] `Validators.senha` aceita só `[A-Za-z]` como letra, igual ao backend.
- [ ] "Hoje" do calendário é recalculado (não fica velho depois da meia-noite); o teste de "ontem desabilitado" usa data fixa.
- [ ] Teste `MigrationV5SeedServicosTest.migrationsAnterioresNaoForamAlteradas` renomeado ou validando checksum de verdade; `fromObject` padronizado.

### 1. Backend: endpoints de admin (todos exigem role ADMIN; cliente → 403; sem token → 401)
- [ ] **Listar por data:** `GET /agendamento/admin?data=AAAA-MM-DD[&status=...]` → lista ordenada por horário com `id, data, horario (HH:mm), status,
      servicoId, servico, clienteId, nomeCliente, telefoneCliente` (telefone só nesta rota de admin; nenhum CPF, e-mail ou senha).
- [ ] **Criar:** `POST /agendamento/admin` `{clienteId, servicoId, data, horario, status?}` → 201 com o agendamento. Status padrão `CONFIRMADO`.
      Cliente ou serviço inexistente → 404/400; horário ocupado → 409; passado ou fora da grade → 400.
- [ ] **Atualizar:** `PUT /agendamento/admin/{id}` `{servicoId?, data?, horario?, status?}` → 200. Novo horário ocupado por **outro** agendamento → 409
      (manter o mesmo horário não é conflito). Reativar um CANCELADO num horário já ocupado → 409. id inexistente → 404.
- [ ] **Cancelar:** `PUT /agendamento/{id}/cancelar` continua funcionando para o admin (qualquer agendamento) e libera o horário.
- [ ] **Deletar:** `DELETE /agendamento/admin/{id}` → 204; id inexistente → 404. O horário fica livre.
- [ ] **Buscar clientes:** `GET /clientes?busca=` (nome parcial, sem diferenciar maiúsculas, ou dígitos do CPF) → `{id, nome, cpf mascarado, telefone}`, no máximo 20.
- [ ] Todas as regras de duplicidade, grade e passado das FASES 1 e 2 valem também para criar e atualizar pelo admin.

### 2. Backend: lado do cliente
- [ ] `GET /agendamento/meus` → só os agendamentos do cliente do JWT (futuros e passados, mais recentes primeiro), com `id, data, horario, status, servico`.
- [ ] O cliente pode cancelar **só** o próprio agendamento **futuro** e não cancelado (de outro cliente → 404; passado → 400).
- [ ] Um agendamento deletado pelo admin não aparece mais em `/meus`; um alterado aparece com os dados novos.

### 3. App: Painel Admin e Agenda Admin
- [ ] **Painel Admin** (`/admin`) substitui a tela provisória: saudação, card "Agenda" (leva a `/admin/agenda`) e logout. Os cards "Clientes" e
      "Serviços" do web ficam de fora (FASE futura). Rotas `/admin/**` bloqueiam CLIENTE (redirect).
- [ ] **Agenda Admin** (`/admin/agenda`): escolher Hoje, Amanhã ou uma data; grade 08:00–19:30 mostrando cada horário como ocupado (cliente,
      serviço, status com cor) ou "Disponível"; contadores por status; filtro por status e busca por nome do cliente; pull-to-refresh.
- [ ] **Criar:** tocar em um horário "Disponível" (ou no botão +) abre o formulário: buscar cliente, escolher serviço, data e horário livre
      (via `disponibilidades`), status inicial.
- [ ] **Detalhes e editar:** tocar em um agendamento abre os detalhes (cliente, telefone, serviço, data, horário, status) com as ações
      Editar (data, horário, serviço, status), Confirmar (PENDENTE → CONFIRMADO), Marcar como realizado, Cancelar e Excluir.
- [ ] Cancelar e Excluir pedem confirmação. Toda operação mostra feedback de sucesso ou erro (incluindo o 409 "horário ocupado") e a
      agenda recarrega depois.

### 4. App: Meus Agendamentos (cliente)
- [ ] Tela `/meus-agendamentos`, acessível pela tela de Serviços e pela tela Confirmado, com as abas (ou seções) Próximos e Histórico e o status de cada um.
- [ ] Os dados vêm sempre do servidor: a tela recarrega ao abrir, com pull-to-refresh e quando o app volta para o primeiro plano. Nada de cache local
      que mostre dado velho.
- [ ] O cliente pode cancelar o próprio agendamento futuro, com confirmação, e a lista atualiza.

### 5. Qualidade
- [ ] Backend: testes de integração para cada endpoint novo, incluindo 401, 403, 404, 409 e 400, e o caso "manter o mesmo horário ao editar".
- [ ] App: widget tests da Agenda Admin (grade, filtros, criar, editar, confirmar, realizar, cancelar, excluir, erro 409) e de Meus Agendamentos
      (lista, refresh, cancelar), com APIs fake. Testes de rota para `/admin/**` e `/meus-agendamentos`.
- [ ] **Contrato ponta a ponta** (`test/contract/`, contra o backend real, com um admin de teste criado por `ADMIN_CPF`/`ADMIN_SENHA` no gate):
      admin cria um agendamento para um cliente → cliente vê em `/meus` → admin edita horário e status → cliente vê os dados novos →
      admin cancela → cliente vê CANCELADO → admin exclui → o agendamento some de `/meus`. Mais: CLIENTE em rota de admin → 403.
- [ ] `./mvnw -B clean test`, `flutter analyze` (zero erros e warnings) e `flutter test` passando. Nenhum teste anterior enfraquecido.

## Gate desta fase (orientação para o tester)
Partir do gate da FASE 2 (`fases/resultado-2/gate.frozen.sh`) e acrescentar: variáveis de admin de teste ao subir o backend
(`ADMIN_CPF` com CPF de teste válido e `ADMIN_SENHA` gerados no script, nunca versionados) e os testes de contrato da FASE 3.
Manter todas as checagens estáticas da FASE 2.

## Fora do escopo
- Atualização em tempo real (push/WebSocket): a atualização é por recarregar, puxar ou voltar ao app.
- CRUD de serviços, produtos e clientes pelo admin (cards "Clientes" e "Serviços" do web).
- Pagamento, notificações e ajustes no web Angular.

## Restrições
- Seguir os padrões das FASES 1 e 2 (backend: controller → service → repository + DTO + Flyway; app: `lib/core` + `lib/features`, Provider, DI por construtor, ApiClient único).
- Não fazer commit nem push no backend.
- **Java 21:** `export JAVA_HOME=/c/Users/Usuario/.jdks/corretto-21.0.11; export PATH="$JAVA_HOME/bin:$PATH"` (no WSL: `/mnt/c/...`). O `java` do PATH é o 8.
- No Windows, `flutter pub get` pode sair com código 1 por falta do Modo de Desenvolvedor (symlink); isso não é falha do código.
