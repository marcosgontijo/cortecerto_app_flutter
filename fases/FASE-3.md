# Tarefa — FASE 3 de 3: CRUD de agendamentos do admin e visão do cliente

> Plano completo em `fases/README.md`. **Pré-requisito:** FASES 1 e 2 entregues.

## Repositórios envolvidos
| Papel | Caminho (Windows) | Pode editar? |
|---|---|---|
| App mobile (este repo) | `C:\Users\Usuario\Documents\Projetos\Dev\Projetos\cortecerto_flutter` | **Sim** |
| Backend Spring Boot (worktree, branch `loop/mobile-migration`) | `C:\Users\Usuario\Documents\Projetos\Dev\Projetos\cortecerto-backend-loop` | **Sim** |
| Referência do web (Angular) | `cortecerto-backend-loop\web\cortecertoweb` | Não (somente leitura) |

## O que quero
Dar ao admin um CRUD completo de agendamentos (backend + Painel Admin e Agenda Admin no app) e garantir que o cliente
veja sempre os dados atualizados depois das alterações do admin.

## Critérios de aceite

### Backend: endpoints de admin (todos exigem role ADMIN; cliente → 403)
- [ ] **Listar** por data: `GET /agendamento/admin?data=AAAA-MM-DD` devolve id, nome do cliente, serviço, data, horário e status (sem dados pessoais além do nome).
- [ ] **Criar** para um cliente existente: `POST /agendamento/admin` (clienteId, servicoId, data, horario). Horário ocupado → 409; dado inválido → 400.
- [ ] **Atualizar**: `PUT /agendamento/admin/{id}` altera data, horário, serviço e status. Novo horário ocupado → 409; id inexistente → 404.
- [ ] **Cancelar**: `PUT /agendamento/{id}/cancelar` muda o status para CANCELADO e libera o horário.
- [ ] **Deletar**: `DELETE /agendamento/admin/{id}` → 204; id inexistente → 404.
- [ ] Busca de clientes para o admin escolher: `GET /clientes?busca=` (só ADMIN, CPF mascarado).
- [ ] Todas as regras da FASE 1 (sem duplicidade, horário de atendimento, sem datas passadas) valem também para o admin.

### Backend: lado do cliente
- [ ] `GET /agendamento/meus` devolve só os agendamentos do cliente do JWT (futuros e passados, com status).
- [ ] O cliente pode cancelar só o próprio agendamento futuro (o de outro cliente → 403/404).

### App: Painel Admin e Agenda Admin
- [ ] Depois do login, um usuário com role ADMIN vai para o **Painel Admin**. As rotas de admin bloqueiam o cliente comum (redirecionam).
- [ ] **Agenda Admin**: escolher o dia e listar os agendamentos com status; puxar para atualizar.
- [ ] Criar agendamento: escolher cliente (busca), serviço, data e horário livre.
- [ ] Editar agendamento: data, horário, serviço e status.
- [ ] Cancelar e deletar, ambos com diálogo de confirmação.
- [ ] Feedback de sucesso e erro em toda operação (inclusive o 409 de horário ocupado). A lista recarrega depois de cada operação.

### App: Meus Agendamentos (cliente)
- [ ] Tela **Meus Agendamentos** com os agendamentos do cliente (próximos e histórico) e status.
- [ ] Depois de qualquer alteração do admin, o cliente vê o dado novo ao abrir a tela ou puxar para atualizar. Nenhum cache desatualizado.
- [ ] O cliente pode cancelar o próprio agendamento futuro, com confirmação.

### Qualidade
- [ ] Backend: testes de integração para cada endpoint acima, incluindo 401, 403, 404 e 409.
- [ ] App: widget tests da Agenda Admin (listar, criar, editar, cancelar, deletar) e de Meus Agendamentos (lista, refresh, cancelar), com APIs mockadas.
- [ ] Teste do fluxo "admin altera → cliente recarrega → vê o dado novo" (pode usar API fake em memória compartilhada).
- [ ] `./mvnw test`, `flutter analyze` e `flutter test` passando.

## Fora do escopo
- Atualização em tempo real (push/WebSocket): a atualização é por recarregar ou puxar.
- CRUD de serviços, produtos e clientes pelo admin.
- Alterar o web Angular.

## Restrições
- Não fazer commit nem push no backend.
- Seguir os padrões das FASES 1 e 2.
- O gate desta fase roda `./mvnw test` + `flutter analyze` + `flutter test`.
