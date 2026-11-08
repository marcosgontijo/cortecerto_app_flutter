# Tarefa — FASE 2 de 3: Base do app e telas do cliente

> Plano completo em `fases/README.md`. **Pré-requisito:** FASE 1 entregue (backend com JWT, validações e disponibilidade por dia).

## Repositórios envolvidos
| Papel | Caminho (Windows) | Pode editar? |
|---|---|---|
| App mobile (este repo) | `C:\Users\Usuario\Documents\Projetos\Dev\Projetos\cortecerto_flutter` | **Sim** |
| Backend Spring Boot (worktree, branch `loop/mobile-migration`) | `C:\Users\Usuario\Documents\Projetos\Dev\Projetos\cortecerto-backend-loop` | Só ajustes pequenos de contrato, justificados no `dev.md` |
| Referência do web (Angular) | `cortecerto-backend-loop\web\cortecertoweb` | Não (somente leitura) |

## O que quero
Organizar a base do app Flutter (rotas, sessão, cliente HTTP único) e migrar todas as telas do **cliente** do web,
funcionando de ponta a ponta com o backend da FASE 1 e com testes.

## Critérios de aceite

### Base do app
- [ ] A navegação usa `go_router` com rotas nomeadas. Sem sessão válida, qualquer rota protegida redireciona para o Login.
- [ ] A URL base da API fica num único lugar (config com `--dart-define`, padrão `http://10.0.2.2:8081/api`).
      Todas as APIs usam o mesmo `ApiClient`/`Dio` com o interceptor de auth. Nenhuma API cria o próprio `Dio`.
- [ ] O JWT fica só no `flutter_secure_storage`. Uma resposta 401 limpa a sessão e leva ao Login.
- [ ] Logout limpa o token e volta ao Login.
- [ ] Nenhum `print` ou log de token, senha, CPF ou payload com dados pessoais.

### Telas do cliente (paridade com o web)
- [ ] **Login** (CPF + senha): valida os campos, mostra a mensagem do backend em caso de erro/bloqueio e guarda o JWT.
- [ ] **Cadastro**: valida no app CPF (dígitos verificadores), e-mail, senha (mínimo 8 caracteres, com letra e número) e confirmação.
      Mostra os erros do backend (400 por campo, 409 para CPF ou e-mail já cadastrado).
- [ ] **Serviços**: lista os serviços vindos da API e permite escolher um.
- [ ] **Agendamento**: calendário (sem datas passadas) e horários livres do dia via `/agendamento/disponibilidades?data=`.
      Se o horário for tomado na hora (409), mostra o aviso e recarrega os horários.
- [ ] **Agendamento confirmado**: mostra o resumo (serviço, data e horário).
- [ ] **Produtos** e **Pagamento**: replicam o web (o pagamento é só visual, sem gateway).

### Qualidade
- [ ] Cada tela acima tem widget tests de renderização, carregamento, erro e caminho feliz, com APIs mockadas.
- [ ] Testes unitários das validações (CPF, e-mail, senha) e dos controllers.
- [ ] `flutter analyze` sem erros e `flutter test` passando.

## Fora do escopo
- Telas do admin e "Meus Agendamentos" (FASE 3).
- Pagamento real, push e WebSocket.
- Alterar o web Angular.

## Restrições
- Seguir a arquitetura `lib/core` + `lib/features/<feature>/{data,domain,presentation}` com Provider + ChangeNotifier.
- Não fazer commit nem push no backend.
- O gate desta fase roda `flutter analyze` + `flutter test` (e `./mvnw test`, se o backend for alterado).
