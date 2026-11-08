APROVADO

# Review — FASE 1, volta 2

Rodei o gate congelado (`bash .loop/gate.frozen.sh`, a partir da raiz do Flutter): **EXIT=0, 164 testes, 0 falhas, GATE: PASSOU**.
Revisei o diff real do backend (`git status`, `git diff`, os untracked de src/main e src/test). O app Flutter só foi lido.

## BLOQUEANTE da volta 1: resolvido
- `JwtFilter.java:58-80`: `shouldNotFilter` só pula a validação do token nas rotas permitAll. Também conferi se isso abre alguma brecha:
  - Pular o JwtFilter **nunca concede acesso**. A requisição só segue sem autenticação, e a autorização continua sendo decidida pela SecurityFilterChain (`AppConfig`), com o matcher normalizado do Spring. Uma divergência entre `ROTAS_PUBLICAS` e os permitAll leva a 401, nunca a um acesso indevido (fail-closed).
  - Path traversal e sufixos (`/clientes/login/../..`, `..;`, `;`, `/error/../clientes`): o AntPathMatcher compara a URI crua, que não casa com esses padrões, e o StrictHttpFirewall rejeita esses caminhos antes. O teste `Volta2.tentativasDeCaminhoParecidoComRotaPublica...` cobre isso.
  - `/clientes/login/` (com barra no fim): o JwtFilter trata como pública, mas a chain cai em `/clientes/**` → hasRole(ADMIN) → 401/403. Não é brecha.
  - `OPTIONS` liberado no filtro é coerente com o `permitAll` de OPTIONS que já estava na chain. Só afeta o preflight do CORS.
  - `/error`: `include-message: never` e `include-stacktrace: never`, então não vaza dados.
  - Rotas protegidas: token inválido continua dando 401 com o mesmo corpo (13 rotas × 6 tokens, testado).
- O contrato com o app está mantido. O `auth_interceptor.dart` manda o token salvo em toda requisição, e o login e o cadastro agora devolvem 200 mesmo com token vencido, lixo ou assinado com outra chave.

## IMPORTANTES da volta 1
- **V4** (`V4__normaliza_cpf_email_cliente.sql`): é segura para produção. Não apaga nada e não falha. Quando há colisão, os dois registros ficam como estão. O UPDATE não viola os índices únicos da V2, porque exclui toda colisão entre os valores normalizados, inclusive com linhas que já estavam normalizadas. A V1 não aparece no diff e a V2/V3 não foram tocadas segundo o dev (o gate confere a V1). O checklist de deploy está no README. OK.
- **Fuso UTC**: está fixado no `main` antes do Spring subir, no Dockerfile (`ENV TZ` + `-Duser.timezone`), no surefire e no compose. Tem teste. OK.
- **Rate limit**: só falhas contam (400/401/409/423), o padrão é 10 e a limpeza roda no máximo 1x/min. Por ser um `@Component Filter`, ele roda depois da SecurityFilterChain, então o firewall já barrou as variantes de caminho e não consegui contornar pela URI. O IP vem de `getRemoteAddr()` (forward-headers fica `none` por padrão), então não dá para falsificar com X-Forwarded-For. OK.

## Opcionais
- `LoginService.java:53`: `@Transactional(noRollbackFor = ApiException.class)` está correto, porque o incremento persiste mesmo no 401. Com IMMEDIATE, as tentativas são serializadas. O teste concorrente (6 tentativas simultâneas → 3×401 + 3×423) prova isso. Não introduziu bug.
- O BCrypt fictício antes do 423 está correto e não muda o status nem a mensagem.

## Testes
- Comparei `IpRateLimitFilterTest` com o original via `git diff`. **Não ficou mais fraco**: os 4 cenários originais continuam, adaptados ao novo contrato, com asserções extras e 4 testes novos. `IpRateLimitFilterDoFilterTest` passa pelo `doFilter` real e prova quais status contam.
- `LegadoV4IntegrationTest` é ponta a ponta de verdade: pré-migra até a V3, insere os legados, o app aplica a V4 e depois tudo é exercitado pela API. Os testes novos provam o que dizem provar.

## Critérios da FASE 1 (revalidação rápida)
Todos estão cobertos por testes de integração que passam no gate. O contrato com o Flutter continua igual: `POST /clientes/login` → `{token,id,name,role}`, `POST /agendamento` com o cliente vindo do JWT e 409, `GET /disponibilidades` → `["HH:mm"]`.

## Achados

[SUGESTÃO] cortecerto-backend-loop/src/main/resources/application.yml:33-37 — o comentário diz que `hibernate.jdbc.time_zone: UTC` fixa o fuso ao gravar/ler, mas o tester provou (B2) que ele não afeta `LocalDate`/`LocalTime` no SQLite. A proteção real está no `main`, no Dockerfile e no surefire. — Corrigir o comentário (ou remover a propriedade) para ninguém confiar nela.

[SUGESTÃO] cortecerto-backend-loop/src/main/resources/db/migration/V4__normaliza_cpf_email_cliente.sql — quando dois legados colidem e nenhum dos dois está normalizado, os dois ficam crus. Assim, `existsByCpf/existsByEmail` e o índice único não barram um terceiro cadastro com o valor normalizado (achado do tester). Isso está dentro do "resolução manual" documentado. — Deixar o checklist do README como passo obrigatório ANTES do deploy (com o resultado registrado). Opcional: bloquear o cadastro quando houver valor cru que normalize para o mesmo valor.

[SUGESTÃO] cortecerto-backend-loop/src/main/java/br/com/ninodev/cortecerto/security/IpRateLimitFilter.java:82-93 — entre a checagem (`isRequestAllowed`) e o `registrarFalha` depois da chain há uma janela de corrida, então rajadas simultâneas de um IP no limite passam todas. O mapa também cresce com IPs distintos (IPv6) dentro da janela de 10 min, já que a limpeza só remove entradas vencidas. O impacto é baixo, porque o bloqueio por conta continua valendo. — Opcional: reservar a tentativa de forma atômica antes da chain (incrementar e desfazer no sucesso) e limitar o tamanho do mapa (ex.: 100k entradas, descartando as mais antigas).

[SUGESTÃO] cortecerto-backend-loop/src/main/java/br/com/ninodev/cortecerto/security/IpRateLimitFilter.java:130 — o monitoramento é por sufixo (`endsWith("/login")`), então pega qualquer rota terminada em /login ou /register. Hoje não tem efeito. — Comparar com os caminhos exatos `/clientes/login` e `/clientes/register`.

[SUGESTÃO] cortecerto-backend-loop/src/main/java/br/com/ninodev/cortecerto/service/LoginService.java:53 — com `@Transactional` + `transaction_mode=IMMEDIATE`, todo login (inclusive de CPF inexistente) segura o lock global de escrita do SQLite durante o BCrypt. Muitas falhas vindas de vários IPs serializam todos os logins e escritas. Isso é aceitável no volume atual. — Numa fase futura: fazer o BCrypt fora da transação e só o incremento atômico dentro dela (`UPDATE ... SET tentativas = tentativas + 1`), ou usar WAL.

[SUGESTÃO] cortecerto-backend-loop/src/main/java/br/com/ninodev/cortecerto/service/JwtService.java — o B1 continua aberto: o algoritmo depende do tamanho da chave e a assinatura com caractere extra é aceita. O dev justificou o adiamento. — Tratar numa fase futura, com um plano de rotação de token.
