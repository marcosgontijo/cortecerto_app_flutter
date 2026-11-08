# Relatório — FASE 1: Backend seguro e agendamentos sem duplicidade

Status: **ENTREGUE** na volta 2 do loop. As mudanças estão na worktree `cortecerto-backend-loop` (branch `loop/mobile-migration`),
**sem commit**, para você revisar. O app Flutter e o web Angular não foram alterados.

## O que foi entregue
- **Senhas e login:** senhas só em BCrypt. `POST /api/clientes/login` (CPF + senha) devolve `{token, id, name, role}`, com um JWT
  em que `sub` é o id e as claims são `id`, `name` e `role` (sem CPF). Credencial errada dá 401 com a mesma mensagem genérica para
  CPF inexistente e para senha errada. A conta fica bloqueada por 15 min depois de 3 falhas seguidas (423). Um token vencido ou
  inválido no header **não** atrapalha o login nem o cadastro.
- **Admin:** a V2 neutraliza o seed antigo (`senha123`, CPF real). O admin é criado no startup a partir de `ADMIN_*`, com hash.
- **Cadastro:** valida CPF (dígitos verificadores), e-mail, senha (mínimo 8 caracteres, com letra e número) e confirmação.
  Dado inválido dá 400 com mensagem por campo. CPF ou e-mail repetido dá 409. O role é sempre CLIENTE.
- **Autorização:** tudo exige JWT, exceto login, register, docs e `/error`. Sem token ou com token inválido dá 401.
  `GET/DELETE /clientes...` e `GET /agendamento/agenda/hoje` são só de ADMIN (cliente recebe 403). Um cliente não vê nem cancela
  agendamento de outro. As respostas usam DTO sem senha e o CPF vem mascarado (`***.***.***-12`).
- **PII e logs:** os logs não registram senha, token nem CPF completo. `show-sql` só fica ligado no perfil dev. O CORS usa origens
  explícitas vindas de `CORS_ALLOWED_ORIGINS` (sem `*`).
- **Agendamentos:** a V3 cria um índice único parcial em (data, horario) para os não cancelados. O cliente vem do JWT. Horário
  ocupado dá 409, e de duas requisições simultâneas só uma passa. Passado ou fora da grade (08:00–19:30, de 30 em 30 min) dá 400.
  `GET /agendamento/disponibilidades?data=AAAA-MM-DD` devolve `["08:00","08:30",...]`. Um horário cancelado volta a ficar livre.
- **Extras da volta 2:**
  - V4 normaliza CPF (só dígitos) e e-mail (`lower(trim())`) dos clientes legados.
  - A JVM fica fixa em UTC (`main`, Dockerfile, surefire, compose).
  - Rate limit por IP que conta só as falhas (padrão 10 a cada 10 min; ao atingir o limite, 429).
  - Checklist de deploy no `README.md` do backend.

## Como testar manualmente

### 1. Variáveis de ambiente (Git Bash)
```bash
export SECURITY_JWT_SECRET_KEY="$(openssl rand -base64 48)"   # obrigatório: Base64 de pelo menos 32 bytes
export JWT_EXPIRATION_SECONDS=28800                           # opcional, padrão 8h
export ADMIN_CPF=52998224725          # CPF com dígitos verificadores válidos (este é um CPF de teste)
export ADMIN_SENHA='Admin12345'       # mínimo 8 caracteres, com letra e número
export ADMIN_EMAIL=admin@cortecerto.local
export ADMIN_NOME=Administrador
export CORS_ALLOWED_ORIGINS=http://localhost:4200,http://127.0.0.1:4200   # nunca "*"
export APP_TIMEZONE=America/Sao_Paulo   # opcional
```
Veja `cortecerto-backend-loop/.env.example` para a lista completa (`RATE_LIMIT_LIMITE`, `SERVER_FORWARD_HEADERS_STRATEGY`).

### 2. Subir o backend com Java 21
```bash
export JAVA_HOME=/c/Users/Usuario/.jdks/corretto-21.0.11; export PATH="$JAVA_HOME/bin:$PATH"
cd /c/Users/Usuario/Documents/Projetos/Dev/Projetos/cortecerto-backend-loop
java -version            # tem que mostrar 21.0.11 (o java do PATH do sistema é o 8 e não serve)
./mvnw -B clean test     # opcional: 164 testes
./mvnw spring-boot:run   # sobe em http://localhost:8080/api
```
Atenção: o banco é `data/cortecerto.db`. Para não mexer nele, faça uma cópia antes, porque as migrations V2 a V4 serão aplicadas.
O Swagger fica em `http://localhost:8080/api/swagger-ui.html`.

### 3. Exemplos com curl
```bash
API=http://localhost:8080/api

# Cadastro (o role do corpo é ignorado e vira CLIENTE)
curl -i -X POST $API/clientes/register -H 'Content-Type: application/json' -d '{
  "nome":"Maria Teste","telefone":"11999990000","cpf":"11144477735","email":"maria@teste.com",
  "dataNascimento":"1990-05-10","senha":"Senha123","confirmarSenha":"Senha123","role":"ADMIN"}'
# Repetir o mesmo comando → 409. Senha "abc" ou CPF "12345678900" → 400 com errors por campo.

# Login → {token,id,name,role}
TOKEN=$(curl -s -X POST $API/clientes/login -H 'Content-Type: application/json' \
  -d '{"cpf":"11144477735","senha":"Senha123"}' | sed -E 's/.*"token":"([^"]+)".*/\1/')
# Senha errada 3x seguidas → 401, 401, 401 e depois 423 (bloqueio de 15 min)

# Login do admin (necessário para cadastrar um serviço, se o banco não tiver nenhum)
ADMIN=$(curl -s -X POST $API/clientes/login -H 'Content-Type: application/json' \
  -d "{\"cpf\":\"$ADMIN_CPF\",\"senha\":\"$ADMIN_SENHA\"}" | sed -E 's/.*"token":"([^"]+)".*/\1/')
curl -i -X POST $API/servicos/createService -H "Authorization: Bearer $ADMIN" -H 'Content-Type: application/json' \
  -d '{"tipoServico":"Corte","descricao":"Corte masculino","precoServico":40.0}'

# Disponibilidades do dia → ["08:00","08:30",...]
curl -s "$API/agendamento/disponibilidades?data=2026-12-01" -H "Authorization: Bearer $TOKEN"

# Agendamento (o cliente vem do token; um clienteId no corpo é ignorado)
curl -i -X POST $API/agendamento -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"data":"2026-12-01","horario":"09:00","servico":{"tipoServico":"Corte"}}'
# Repetir → 409. "horario":"09:15" ou "20:00", ou uma data passada → 400.
# Depois de agendar, 09:00 some das disponibilidades. Cancelar com PUT $API/agendamento/{id}/cancelar e ele volta.

# Autorização
curl -i $API/clientes                                    # sem token → 401
curl -i $API/clientes -H "Authorization: Bearer $TOKEN"  # cliente → 403
curl -i $API/clientes -H "Authorization: Bearer $ADMIN"  # admin → 200, CPF mascarado, sem senha
curl -i -X POST $API/clientes/login -H 'Authorization: Bearer lixo' -H 'Content-Type: application/json' \
  -d '{"cpf":"11144477735","senha":"Senha123"}'          # token inválido no header não atrapalha → 200
```

## Testes e checagens que passaram
- Gate congelado `.loop/gate.frozen.sh`: `./mvnw -B clean test` com **164 testes, 0 falhas, 0 erros** (exit 0), mais as checagens de
  segredo (V1 intacta, migrations V2+ sem INSERT nem senha, yml sem segredo, `.env.example`).
- Testes de integração SpringBootTest + MockMvc com a SecurityFilterChain real e SQLite de teste cobrindo cada critério:
  `Autenticacao`, `Cadastro`, `Autorizacao`, `Seguranca`, `Agendamento`, `RelogioFixo`, `Migrations`, `TokenEmRotaPublica`,
  `Volta2Tester`, `LegadoV4`, `RateLimit`, `IpRateLimitFilter*`, `FusoDaJvm`. A tabela critério por teste está em `.loop/veredito.md`.
- Testes de concorrência: agendamento (10 threads, só 1 aceita) e logins errados simultâneos (bloqueio sem perder incremento).
- Review da volta 2: APROVADO, sem bloqueantes.

## Riscos e limitações conhecidas

### Checklist de deploy (obrigatório, detalhado no `README.md` do backend)
1. **Backup** de `data/cortecerto.db` antes de tudo.
2. **Colisão na V4:** rode as consultas de CPF/e-mail que colidem depois da normalização **antes** do deploy e registre o resultado.
   Quando há colisão, a V4 deixa os dois registros como estão, sem falhar e sem apagar. Se nenhum dos dois já estiver normalizado,
   um terceiro cadastro com o valor normalizado passa a ser aceito. Resolva as colisões à mão (mover agendamentos, desativar a conta
   duplicada) e rode a consulta de conferência depois.
3. **V3 cancela duplicidades legadas:** se já houver dois agendamentos não cancelados no mesmo (data, horario), a V3 mantém o mais
   antigo e marca os outros como `CANCELADO` **sem avisar o cliente**. Rode a consulta de duplicados antes e avise os afetados.
4. **`sub` do JWT mudou de CPF para id:** o app Flutter lê `id/name/role` do corpo e não é afetado. Tokens antigos ainda carregam as
   claims `id/role`. Confira se algum outro consumidor (web Angular, integrações) lia o CPF do `sub`.
5. **Expiração do token agora é 8h** (`JWT_EXPIRATION_SECONDS=28800`, antes eram cerca de 41 dias). Os usuários vão precisar refazer
   login com frequência, então o app tem que tratar o 401 (ver abaixo).
6. **CORS via env:** defina `CORS_ALLOWED_ORIGINS` com as origens reais do web em produção. Sem isso, só valem as de localhost e o
   web publicado é bloqueado. `*` não é aceito.
7. Outros pontos do checklist: seed antigo do admin (a V2 só neutraliza se a senha ainda for `senha123`), `ADMIN_SENHA` só vale na
   criação do admin, a JVM roda em UTC (não defina outro `TZ`), e só use `SERVER_FORWARD_HEADERS_STRATEGY=native` atrás de proxy confiável.

### Impacto no app Flutter e no web (tratar na FASE 2)
- **Porta:** o Flutter usa `http://10.0.2.2:8081/api`, mas o backend sobe na 8080.
- **Sessão de 8h:** o app tem que tratar 401 nas rotas protegidas (limpar o token e mandar para o login). Hoje o logout não apaga o
  token certo: apaga `jwt_token`, mas o token fica em `auth_token`. O login não quebra mais com token vencido, porque o backend
  ignora o header nas rotas públicas, mas a experiência continua ruim.
- **Cadastro mais rígido:** o app precisa validar antes (CPF com dígitos verificadores, senha com 8+ caracteres e letra e número) e
  mostrar os erros 400 por campo (`errors.<campo>`), o 409 (CPF/e-mail já cadastrado), o 423 (conta bloqueada) e o 429 (muitas tentativas).
- **Logs do app:** o `servicos_api.dart` faz `print` do token. Remover.
- **Serviços:** criar serviço (`POST /servicos/**`) agora é só de ADMIN, e `POST /clientes` foi removido.
- **Web Angular (fora do escopo, só leitura):** `disponibilidades` mudou de formato (antes era a lista do mês, agora é
  `["HH:mm"]` do dia). O `clienteId` que o web manda é ignorado, e o web precisa da sua origem em `CORS_ALLOWED_ORIGINS`.
  O web vai quebrar nesses pontos até ser ajustado.

### Limitações (todas de severidade BAIXA)
- JWT (B1): o algoritmo depende do tamanho da chave e uma assinatura com caractere extra é aceita. Foi adiado por exigir um plano de rotação.
- Rate limit: tem uma janela de corrida em rajadas simultâneas do mesmo IP, e o mapa cresce com muitos IPs distintos. O bloqueio por
  conta continua valendo.
- Login com `@Transactional` + IMMEDIATE segura o lock de escrita do SQLite durante o BCrypt. Aceitável no volume de uma barbearia.
- O comentário de `hibernate.jdbc.time_zone` no `application.yml` engana: a proteção real do fuso é o UTC fixo da JVM.
- Não verificado: CVEs das dependências (sem acesso à NVD), proxy real, fuso dentro do container, concorrência entre processos.
- Swagger público em produção, JWT sem consulta ao banco (conta removida continua com token válido até expirar), `dataNascimento` sem validação.

## Sugestões de próximos passos
1. Revisar o diff da worktree, rodar o checklist de deploy num backup do banco de produção e então fazer o commit.
2. FASE 2 (Flutter): porta, tratamento de 401/400/409/423/429, logout limpando o token certo, validação do cadastro e remoção do `print` do token.
3. Corrigir o comentário de `hibernate.jdbc.time_zone` (ou remover a propriedade).
4. Rate limit: reservar a tentativa de forma atômica antes da chain, limitar o tamanho do mapa e comparar os caminhos exatos de login/register.
5. JWT: fixar o algoritmo (HS256 ou HS384) e rejeitar assinatura não canônica, junto com um plano de rotação de chave.
6. SQLite: fazer o BCrypt fora da transação com incremento atômico, ou usar WAL. Bloquear o cadastro quando houver colisão legada pendente.
7. Ajustar o web Angular ao novo contrato (disponibilidades, CORS) antes de publicar o backend, se o web continuar em uso.
