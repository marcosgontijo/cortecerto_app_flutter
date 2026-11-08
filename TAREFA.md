# Tarefa — FASE 2 de 3: Base do app e telas do cliente

> Plano completo em `fases/README.md`. **Pré-requisito:** FASE 1 entregue (resultado em `fases/resultado-1/`).

## Repositórios envolvidos
| Papel | Caminho (Windows) | Pode editar? |
|---|---|---|
| App mobile (este repo) | `C:\Users\Usuario\Documents\Projetos\Dev\Projetos\cortecerto_flutter` | **Sim** (foco da fase) |
| Backend Spring Boot (worktree, branch `loop/mobile-migration`) | `C:\Users\Usuario\Documents\Projetos\Dev\Projetos\cortecerto-backend-loop` | Só o que esta TAREFA cita (seed de serviços). Nada de mudar regra de segurança da FASE 1 |
| Referência do web (Angular) | `cortecerto-backend-loop\web\cortecertoweb` | Não (somente leitura) |

> No WSL, troque `C:\` por `/mnt/c/` e `\` por `/`.

## O que quero
Organizar a base do app Flutter (rotas, sessão, cliente HTTP único, injeção de dependências) e migrar as telas do **cliente**
do web, funcionando de ponta a ponta com o backend da FASE 1 e com testes.

## Contrato do backend (já entregue na FASE 1, não mudar)
- Base: `http://<host>:8080/api` (no emulador Android: `http://10.0.2.2:8080/api`). **A porta mudou de 8081 para 8080.**
- `POST /clientes/login` `{cpf, senha}` → 200 `{token, id, name, role}` · 401 (CPF/senha inválidos) · 423 (conta bloqueada) · 429 (muitas tentativas).
- `POST /clientes/register` `{nome, telefone, cpf, email, dataNascimento, senha, confirmarSenha}` → 200 · 400 `{status, message, errors:{campo: msg}}` · 409 (CPF/e-mail já cadastrado).
- `GET /servicos` → `[{id, tipoServico, descricao, precoServico}]` (exige JWT).
- `GET /agendamento/disponibilidades?data=AAAA-MM-DD` → `["08:00","08:30",...]` (exige JWT).
- `POST /agendamento` `{data, horario, servico:{tipoServico, descricao, precoServico}}` → 200 · 400 (passado/fora da grade/serviço inexistente) · 409 (horário ocupado).
- Erros sempre no formato `{status, message, errors?}`. JWT expira em 8h. Rota protegida sem token ou com token inválido → 401.

## Critérios de aceite

### 1. Base do app
- [ ] **Configuração única da API:** `baseUrl` vem de `--dart-define=API_BASE_URL=...`, com padrão `http://10.0.2.2:8080/api`. Existe um único `ApiClient`/`Dio`
      com o interceptor de auth. **Nenhuma** classe cria o próprio `Dio` nem monta o header `Authorization` na mão.
- [ ] **Injeção de dependências:** APIs, `TokenStorage` e controllers recebem as dependências pelo construtor e são registrados via Provider,
      para que os testes possam injetar fakes ou mocks. Nada de `AuthApi()`/`ApiClient()` instanciado dentro de controller ou widget.
- [ ] **Navegação:** `go_router` com rotas nomeadas (`/login`, `/cadastro`, `/servicos`, `/agendamento`, `/agendamento/confirmado`, `/produtos`, `/admin`).
      Sem sessão válida, qualquer rota protegida redireciona para `/login`. Usuário com role `ADMIN` vai para `/admin` (nesta fase, uma tela
      provisória "Painel Admin" com nome do usuário e botão de sair; o painel completo é da FASE 3). Cliente comum não acessa `/admin`.
- [ ] **Sessão:** o JWT fica **só** no `flutter_secure_storage`, numa única chave. Ao abrir o app com token salvo e não expirado
      (checar o `exp` do JWT), o usuário entra direto. Token expirado → Login.
- [ ] **401 global:** qualquer 401 numa rota protegida limpa a sessão e leva ao Login com a mensagem "Sessão expirada, faça login novamente".
- [ ] **Logout** (disponível nas telas logadas) apaga o token (a mesma chave usada para salvar; hoje o `clearToken` apaga a chave errada) e volta ao Login.
- [ ] **Erros da API:** uma classe central converte `DioException` em erro de domínio com mensagem amigável por status
      (400 com `errors` por campo, 401, 409, 423, 429, timeout/sem conexão).
- [ ] **Sem vazamento:** nenhum `print`/`debugPrint`/log de token, senha, CPF ou payload com dados pessoais (remover os `print` atuais).
      Usar `debugPrint` só para mensagens sem dados pessoais, ou não logar.

### 2. Telas do cliente (paridade com o web)
- [ ] **Login** (CPF + senha): máscara de CPF; envia só os dígitos; valida campos vazios; mostra a mensagem certa para 401, 423 e 429;
      botão desabilitado e indicador de carregamento durante a requisição; link para o Cadastro.
- [ ] **Cadastro**: campos nome, telefone, CPF, e-mail, data de nascimento, senha e confirmação. Valida no app: CPF (dígitos verificadores),
      e-mail, senha (mínimo 8 caracteres, com letra e número), confirmação igual. Mostra embaixo de cada campo os erros 400 vindos do backend
      (`errors.<campo>`) e o 409. Sucesso → volta ao Login com aviso "Cadastro realizado".
- [ ] **Serviços**: saudação com o nome do usuário; lista os serviços da API (nome, descrição, preço); estados de carregamento, vazio e erro com
      "tentar novamente"; selecionar um serviço leva ao Agendamento.
- [ ] **Agendamento**: calendário (`table_calendar`) sem datas passadas; ao escolher o dia, carrega os horários livres via `disponibilidades?data=`
      (no dia de hoje, só os horários futuros vindos do backend); confirmar envia o agendamento. 409 → aviso "Horário acabou de ser reservado"
      e recarrega os horários. 400 → mostra a mensagem do backend.
- [ ] **Agendamento confirmado**: resumo (serviço, data dd/MM/aaaa e horário) e botão "Voltar aos serviços". Nada de mandar o usuário para o Login.
- [ ] **Produtos**: catálogo igual ao do web (Pomada R$ 25,00, Shampoo R$ 30,00, Pente R$ 10,00), com seleção múltipla e total. Acessível pela tela de
      Serviços. **Sem compra ou checkout** (o web também não tem).

### 3. Backend (única mudança permitida)
- [ ] Nova migration Flyway (V5 ou a próxima livre) cadastra os 5 serviços do web (Corte Simples, Corte + Barba, Barba, Sobrancelha,
      Corte Completo), com descrição e preço, sem duplicar se já existirem. Os testes da FASE 1 continuam passando.

### 4. Qualidade
- [ ] **Testes unitários:** validadores (CPF, e-mail, senha, confirmação), conversão de erros da API, leitura de `exp` do JWT, controllers
      (sucesso, erro, carregamento) com APIs fake.
- [ ] **Widget tests** de cada tela (Login, Cadastro, Serviços, Agendamento, Confirmado, Produtos, Admin provisório): renderização,
      carregamento, erro e caminho feliz, com APIs fake (pode adicionar `mocktail` em `dev_dependencies`).
- [ ] **Testes de rota:** sem token → `/login`; token expirado → `/login`; CLIENTE → `/servicos`; ADMIN → `/admin`; CLIENTE tentando `/admin` → redirecionado;
      401 numa chamada → `/login`.
- [ ] **Testes de contrato** em `test/contract/` (tag `contract`, só Dart + Dio, sem emulador): contra o backend real rodando localmente, provam
      register → login → listar serviços → disponibilidades → agendar → 409 no mesmo horário → 401 com token inválido. Leem a URL de uma
      variável de ambiente e são pulados se ela não estiver definida (assim `flutter test` comum não depende do backend).
- [ ] `flutter analyze` sem erros nem warnings e `flutter test` passando.

## Gate desta fase (orientação para o tester)
O `.loop/gate.sh` deve, sem interação:
1. `flutter pub get`, `flutter analyze` e `flutter test` (sem a tag `contract`) no app;
2. `./mvnw -B clean test` no backend (com o Java 21; veja Restrições);
3. subir o backend localmente (`./mvnw spring-boot:run` ou o jar) com variáveis de teste (JWT secret de teste, banco SQLite temporário,
   admin de teste), esperar a porta 8080 responder, rodar `flutter test --tags contract` com a URL definida, e **sempre** derrubar o backend no fim;
4. uma checagem de que não há `print(` com token/senha/CPF em `lib/` e que só existe um `Dio(` em `lib/`.

## Fora do escopo
- Telas do admin (Agenda Admin, CRUD) e "Meus Agendamentos": FASE 3.
- Tela de Pagamento: no web é só um rascunho, sem conteúdo nem rota.
- Compra de produtos, gateway de pagamento, push e WebSocket.
- Alterar o web Angular.

## Restrições
- Arquitetura `lib/core` + `lib/features/<feature>/{data,domain,presentation}`, com Provider + ChangeNotifier. Dependências novas só se
  necessárias (`mocktail` em dev, `mask_text_input_formatter` ou equivalente para máscara, `intl` para datas).
- Não fazer commit nem push no backend.
- **Java 21 para o backend:** `export JAVA_HOME=/c/Users/Usuario/.jdks/corretto-21.0.11; export PATH="$JAVA_HOME/bin:$PATH"`
  (no WSL: `/mnt/c/Users/Usuario/.jdks/corretto-21.0.11`). O `java` do PATH do sistema é o 8.
- Variáveis de ambiente do backend em `cortecerto-backend-loop/.env.example` (`SECURITY_JWT_SECRET_KEY`, `ADMIN_CPF`, `ADMIN_SENHA`, `ADMIN_EMAIL`,
  `CORS_ALLOWED_ORIGINS`). Valores de teste ficam só no gate e nos testes, nunca em arquivo versionado.
