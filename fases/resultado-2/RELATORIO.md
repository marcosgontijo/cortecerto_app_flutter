# Relatório — FASE 2: base do app e telas do cliente

**Status: ENTREGUE** (volta 1). Não fiz commit em nenhum dos dois repositórios: as mudanças estão no working tree para você revisar.

## O que foi entregue

**Base do app (`lib/core`)**
- A URL da API vem de `--dart-define=API_BASE_URL=...` e o padrão é `http://10.0.2.2:8080/api`. O app tem um único `ApiClient`, com um único `Dio`,
  e um interceptor que coloca o `Bearer` e trata o 401 global.
- Injeção de dependências: o `AppDependencies` em `lib/app.dart` monta TokenStorage → Session → ApiClient → APIs. Os controllers são criados por rota
  com Provider, então nada é instanciado dentro de widget ou controller.
- Navegação com go_router e rotas nomeadas: `/login`, `/cadastro`, `/servicos`, `/agendamento`, `/agendamento/confirmado`, `/produtos`, `/admin`.
  Sem sessão, o app vai para `/login`. ADMIN vai para `/admin` (painel provisório) e o CLIENTE não consegue abrir `/admin`.
- Sessão: o JWT fica só no `flutter_secure_storage`, na chave `auth_token`. Ao abrir, o app lê o `exp`: com token válido entra direto, com token expirado vai ao Login.
  O logout e o 401 apagam essa mesma chave. Com isso o bug antigo do `jwt_token` foi corrigido.
- Um 401 em rota protegida limpa a sessão e leva ao Login com a mensagem "Sessão expirada, faça login novamente".
- O `ApiErrorMapper` é o ponto central que transforma erros da API em mensagens amigáveis (400 por campo, 401, 409, 423, 429, timeout, sem conexão).
- Todos os `print` foram removidos. Não há log de token, senha ou CPF.

**Telas do cliente**
- **Login:** máscara de CPF e envio só dos dígitos. Mostra as mensagens de 401/423/429 e um spinner com o botão desabilitado durante a requisição. Só navega quando o login dá certo.
- **Cadastro:** 7 campos, com validação de CPF (dígitos verificadores), e-mail, senha (8+ caracteres, com letra e número) e confirmação.
  O erro 400 do backend aparece embaixo do campo certo e o 409 também é tratado. Depois do sucesso, volta ao Login com o aviso "Cadastro realizado".
- **Serviços:** "Olá, {nome}!", lista com descrição e preço em R$ e estados de carregando/vazio/erro com "Tentar novamente". Tem acesso a Produtos e botão de logout.
- **Agendamento:** `table_calendar` em pt_BR sem datas passadas e horários do dia vindos do backend. No 409 aparece o aviso "Horário acabou de ser
  reservado" e a lista é recarregada. No 400 aparece a mensagem do backend.
- **Confirmado:** mostra serviço, data dd/MM/aaaa e horário, com o botão "Voltar aos serviços". Não manda mais o usuário para o Login.
- **Produtos:** Pomada R$ 25,00, Shampoo R$ 30,00 e Pente R$ 10,00, com seleção múltipla e total. Não tem checkout.
- **Admin provisório:** mostra "Painel Admin", o nome do usuário e o botão "Sair".

**Android:** a permissão `INTERNET` foi adicionada no manifest principal. HTTP sem TLS (cleartext) só é permitido no build **debug** e só para `10.0.2.2`, `localhost` e `127.0.0.1`.

**Backend:** a única mudança é a `V5__seed_servicos.sql`, que cadastra de forma idempotente os 5 serviços: Corte Simples, Corte + Barba, Barba, Sobrancelha e Corte Completo.
Também entrou o teste `fase2/MigrationV5SeedServicosTest.java`. Nenhuma regra de segurança da FASE 1 foi alterada.

## Como testar manualmente

### 1. Subir o backend (Git Bash)
```bash
export JAVA_HOME=/c/Users/Usuario/.jdks/corretto-21.0.11; export PATH="$JAVA_HOME/bin:$PATH"   # o java do PATH é o 8
cd /c/Users/Usuario/Documents/Projetos/Dev/Projetos/cortecerto-backend-loop
export SECURITY_JWT_SECRET_KEY="$(openssl rand -base64 48)"   # obrigatória
export ADMIN_CPF=<um CPF válido seu>                           # cria o admin no startup (só se o CPF ainda não existir)
export ADMIN_SENHA='<mínimo 8 caracteres, com letra e número>'
export ADMIN_EMAIL=admin@cortecerto.local
export CORS_ALLOWED_ORIGINS=http://localhost:4200               # o app mobile não usa CORS
# opcional: banco separado para o teste (o padrão é ./data/cortecerto.db)
# export SPRING_DATASOURCE_URL="jdbc:sqlite:C:/caminho/teste.db"
./mvnw spring-boot:run
```
- O Flyway aplica as migrations V1 a V5. A **V5 cria os 5 serviços** e, com isso, a tela de Serviços já aparece preenchida num banco novo.
- O backend está de pé quando `http://localhost:8080/api/api-docs` responde 200.
- Se uma tentativa de login der errado várias vezes, lembre que existe rate limit (10 falhas a cada 10 min por IP → 429) e bloqueio de conta
  (3 senhas erradas → 423 por 15 min). Para os testes manuais, você pode subir com `RATE_LIMIT_LIMITE=1000`.

### 2. Rodar o app no emulador Android
```bash
cd /c/Users/Usuario/Documents/Projetos/Dev/Projetos/cortecerto_flutter
flutter pub get        # no Windows sem Modo de Desenvolvedor pode reclamar de symlink; ative o Developer Mode se o build falhar
flutter emulators --launch <id>   # ou abra o emulador pelo Android Studio
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
```
- `10.0.2.2` é o endereço da sua máquina visto de dentro do emulador. Em aparelho físico, use o IP da máquina na rede. Atenção: o cleartext do debug
  só libera `10.0.2.2`/`localhost`/`127.0.0.1`, então um IP de rede exige incluir esse host em `android/app/src/debug/res/xml/network_security_config.xml`.

### 3. Roteiro de cliques
1. **Cadastro:** no Login, toque em "Cadastre-se". Teste primeiro um CPF inválido e uma senha fraca: devem aparecer os erros embaixo dos campos. Depois
   preencha tudo certo (data de nascimento dd/mm/aaaa). O app deve voltar ao Login com o aviso "Cadastro realizado". Repita o mesmo CPF para ver o 409 "CPF ou e-mail já cadastrado".
2. **Login:** primeiro com senha errada, que deve mostrar "CPF ou senha inválidos" e manter você no Login. Depois com a senha certa: você deve cair em Serviços com "Olá, {nome}!".
3. **Serviços:** devem aparecer os 5 serviços com preço. Toque em um deles.
4. **Agendamento:** os dias passados ficam desabilitados. Escolha um dia, veja os horários livres, escolha um e confirme. A tela Confirmado deve mostrar
   serviço, data dd/MM/aaaa e horário. Toque em "Voltar aos serviços".
5. **409:** abra o app em outro emulador (ou use o Swagger em `http://localhost:8080/api/swagger-ui.html`/curl com outro usuário) e
   agende o mesmo dia e horário que está na tela do primeiro aparelho, antes de confirmar lá. Ao confirmar no primeiro, deve aparecer
   "Horário acabou de ser reservado" e a lista é recarregada sem aquele horário.
6. **Produtos:** em Serviços, toque em "Ver produtos", selecione vários itens e confira o total (ex.: Pomada + Shampoo = R$ 55,00). Não existe botão de compra.
7. **Logout:** toque em "Sair" (ícone na AppBar). O app volta ao Login. Feche e abra o app: ele deve continuar no Login.
8. **Sessão persistida:** faça login, feche o app e abra de novo. Você deve entrar direto em Serviços.
9. **Admin provisório:** faça login com `ADMIN_CPF`/`ADMIN_SENHA`. Deve aparecer "Painel Admin" com o nome e o botão "Sair". O painel completo fica para a FASE 3.

### 4. Testes automatizados
```bash
flutter analyze
flutter test                      # 128 testes (o de contrato é pulado sem API_BASE_URL)
API_BASE_URL=http://localhost:8080/api flutter test --tags contract   # com o backend de pé (use RATE_LIMIT_LIMITE alto)
bash .loop/gate.sh                # tudo de uma vez: app + backend + contrato, e derruba o backend no final
```

## Testes e checagens que passaram
- Gate congelado `.loop/gate.frozen.sh` com **exit 0**. O reviewer também rodou o gate de forma independente e ele passou.
- `flutter analyze`: **No issues found** (0 erros, warnings ou infos).
- `flutter test --exclude-tags contract`: **128 passaram**. São 56 do developer e 72 do tester, cobrindo validadores, mapper de erros, JWT/sessão, interceptor,
  controllers, widget tests das 7 telas, rotas e fluxos do app inteiro com o router real e o Dio real sobre HTTP falso, além de uma varredura do código-fonte.
- Contrato contra o **backend real**, não pulado: register → login → 5 serviços da V5 → disponibilidades → agendar → 409 → 401 com token inválido.
- Backend `./mvnw -B clean test`: **168 testes, 0 falhas** (164 da FASE 1 + 4 da V5).
- Checagens estáticas: só 1 `Dio(` (`api_client.dart`), `Authorization` só no interceptor, nenhum print/log, manifests corretos e nenhum segredo versionado.

## Riscos e limitações conhecidas
- **Preços da V5 são PROVISÓRIOS:** Corte Simples 35,00, Corte + Barba 55,00, Barba 25,00, Sobrancelha 15,00 e Corte Completo 65,00. Esses valores não existiam
  no web nem no backend. **O dono da barbearia precisa ajustá-los**, pelo painel admin da FASE 3 ou com uma nova migration (a V5 não pode ser editada depois de aplicada).
- **O que não foi testado** (não havia emulador):
  - o app rodando em emulador ou aparelho;
  - `flutter build apk`;
  - o `flutter_secure_storage` real (Keystore), porque os testes usam mock/fake;
  - o `network_security_config`, que só foi conferido de forma estática.
  - 423/429 contra o backend real também não foram testados, porque o gate sobe com rate limit alto. Esses casos estão cobertos com HTTP falso no app e pelos testes da FASE 1.
- **O web Angular continua quebrado com o backend novo** (fora do escopo, não foi alterado). Os motivos são o formato novo de `disponibilidades` (`["HH:mm"]` do dia),
  a porta 8080, o CORS por variável de ambiente e o `clienteId` ignorado. Ele precisa ser ajustado antes de publicar o backend, se continuar em uso.
- **[IMPORTANTE, do review]** Se o usuário sair ou voltar enquanto uma requisição está em andamento, o controller chama `notifyListeners()` depois de descartado.
  Em debug isso aparece como erro (assertion); em release não acontece nada. Não afeta dados.
- O botão Voltar do Android na tela Confirmado fecha o app em vez de voltar para Serviços.
- Divergência pequena: o app aceita letras acentuadas na senha e o backend não aceita. Nesse caso o backend devolve 400 e a mensagem aparece no campo.
- Achados de segurança apenas BAIXA:
  - `isPublica` usa `endsWith`;
  - a regra de senha citada acima;
  - um exemplo de `ADMIN_SENHA` no relatório da FASE 1.
- Nesta fase, o ADMIN fica restrito a `/admin`. O telefone exige 10 ou 11 dígitos (regra do backend).

## Sugestões de próximos passos
1. **No início da FASE 3:** corrigir o `notifyListeners` após `dispose` com um guard `_descartado` ou um mixin comum nos 4 controllers, e adicionar um widget test que confirme que sair durante o carregamento não gera exceção.
2. `PopScope` na tela Confirmado, levando para `/servicos`. Também: comparar o path exato no `isPublica`, usar `[A-Za-z]` na regra de senha e recalcular `_hoje` na tela de Agendamento.
3. Corrigir o teste "ontem desabilitado" com uma data fixa e renomear (ou fortalecer) `migrationsAnterioresNaoForamAlteradas`.
4. Definir os preços reais dos serviços.
5. Rodar o roteiro acima num emulador e fazer `flutter build apk` antes da FASE 3. Ative o Modo de Desenvolvedor do Windows para o `pub get`/build com plugins.
6. FASE 3: painel admin completo (Agenda, CRUD) e "Meus Agendamentos". Depois disso, ajustar o web Angular ou aposentá-lo.
