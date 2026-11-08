# Tarefa — FASE 1 de 3: Backend seguro e agendamentos sem duplicidade

> Plano completo em `fases/README.md`. Esta fase mexe **só no backend**. O app Flutter não é alterado.

## Repositórios envolvidos
| Papel | Caminho (Windows) | Pode editar? |
|---|---|---|
| App mobile (este repo) | `C:\Users\Usuario\Documents\Projetos\Dev\Projetos\cortecerto_flutter` | Não nesta fase |
| Backend Spring Boot (worktree, branch `loop/mobile-migration`) | `C:\Users\Usuario\Documents\Projetos\Dev\Projetos\cortecerto-backend-loop` | **Sim** |
| Referência do web (Angular) | `cortecerto-backend-loop\web\cortecertoweb` | Não (somente leitura) |

> No WSL, troque `C:\` por `/mnt/c/` e `\` por `/`.

## O que quero
Deixar o backend pronto para o app: login e senha validados e guardados de forma segura, dados pessoais (PII) dos clientes
protegidos, autorização por papel (CLIENTE/ADMIN) e nenhuma possibilidade de agendamento duplicado.

## Critérios de aceite

### Autenticação e senhas
- [ ] Senhas armazenadas apenas como hash **BCrypt**. Nenhum endpoint devolve o campo `senha` nem o hash.
- [ ] O seed do admin na migration Flyway **não** tem senha em texto puro nem CPF real. Uma nova migration remove ou corrige o seed.
      O admin é criado no startup com hash, e a senha vem de variável de ambiente.
- [ ] `POST /clientes/login` (CPF + senha) devolve um **JWT** com id, nome e role do usuário.
- [ ] Credenciais erradas → 401 com mensagem genérica, igual para CPF inexistente e senha errada.
- [ ] A conta fica bloqueada por 15 min depois de 3 falhas seguidas (comportamento atual, agora com teste).
- [ ] O cadastro (`POST /clientes/register`) valida: CPF válido (dígitos verificadores), e-mail válido, senha com no mínimo 8 caracteres contendo
      letra e número, e confirmação igual à senha. Dado inválido → 400 com mensagem por campo.
- [ ] CPF e e-mail são únicos: o segundo cadastro com o mesmo CPF ou e-mail → 409.
- [ ] O role do cadastro é sempre CLIENTE, mesmo se o corpo da requisição mandar `ADMIN`.

### Autorização e proteção de dados pessoais
- [ ] Todos os endpoints, exceto login, register e docs, exigem JWT válido. Sem token ou com token inválido → 401.
- [ ] `GET /clientes`, `GET /clientes/{id}`, `DELETE /clientes/{id}` e `GET /agendamento/agenda/hoje` são só de ADMIN (cliente → 403).
- [ ] Um cliente não consegue ver nem cancelar agendamento de outro cliente (→ 403 ou 404).
- [ ] As respostas com dados de cliente usam DTO sem `senha`. O CPF aparece mascarado (`***.***.***-12`) em listagens.
- [ ] Os logs não registram senha, token nem CPF completo. `show-sql` fica desligado fora do perfil de desenvolvimento.
- [ ] CORS não usa `*` junto com credenciais.

### Agendamentos sem duplicidade
- [ ] Uma nova migration Flyway garante unicidade de (`data`, `horario`) para agendamentos **não cancelados**
      (índice único parcial, ou alternativa equivalente que funcione no SQLite).
- [ ] O cliente do agendamento vem do JWT, nunca do corpo da requisição.
- [ ] Criar agendamento em horário ocupado → **409**. Duas requisições simultâneas no mesmo horário: só uma é aceita (teste de concorrência).
- [ ] Agendar no passado ou fora do horário de atendimento (08:00–19:30, de 30 em 30 min) → 400.
- [ ] `GET /agendamento/disponibilidades?data=AAAA-MM-DD` devolve a lista de horários livres **daquele dia** (`["08:00","08:30",...]`),
      que é o contrato que o app Flutter já usa.
- [ ] Um horário cancelado volta a ficar disponível.

### Qualidade
- [ ] `./mvnw test` passando, com testes de integração (SpringBootTest + MockMvc, banco SQLite de teste) cobrindo todos os itens acima.
- [ ] Nenhum segredo no repositório: JWT secret e senha do admin ficam em variável de ambiente (`.env.example` documentado).

## Fora do escopo
- Qualquer alteração no app Flutter ou no web Angular.
- Endpoints de CRUD do admin (editar e deletar agendamento): são da FASE 3.

## Restrições
- Não fazer commit nem push no backend. As mudanças ficam na worktree para revisão humana.
- Seguir o padrão controller → service → repository + DTO + Flyway.
- **Pré-requisito:** JDK 17. Se não estiver disponível, o finalizador marca **BLOQUEADO**.
- O gate (`.loop/gate.sh`) desta fase roda `./mvnw test` dentro de `cortecerto-backend-loop`.
