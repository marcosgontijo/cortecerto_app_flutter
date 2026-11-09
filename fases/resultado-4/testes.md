# testes.md (FASE 4, volta 5)

## Tipo de app e ferramentas
- App mobile Flutter: `flutter test` (widget tests com `mocktail` e APIs fake), `flutter analyze`, `meetsGuideline` para acessibilidade.
- Backend Spring Boot: `./mvnw -B clean test` (Java 21) e testes de contrato com o backend real na porta 18080. Tudo isso roda dentro do gate.
- Segurança: as checagens estáticas do gate (segredos, `.env.example`, escopo de arquivos) e o grep de segredos no diff desta volta.

## Revisão testada
- App `cortecerto_flutter`: branch `main`, HEAD `2d0bf7e`, mais as alterações não commitadas da FASE 4. `git status --porcelain` tem 35 entradas.
- Backend `cortecerto-backend-loop`: branch `loop/mobile-migration`, HEAD `7620220`, `git status --porcelain` com 0 linhas, antes e depois dos gates.
- `lib/features/admin/presentation/agendamento_form_page.dart`: sha256 `2b33a3ca…09ba`, igual antes dos controles negativos e depois de todos eles.
- `.loop/gate.frozen.sh`: sha256 `d8589c21…26a9`. Não foi alterado.

## O que mudou nesta volta (só testes e gate)
- `test/fase4/telas_fase4_test.dart`, grupo "Formulário admin", +2 testes:
  1. `busca de clientes: erro com EstadoErro; "Tentar novamente" busca de novo e mostra o resultado`. A 1ª busca ('mar') falha com `semConexao`. O teste confere que `form-erro-clientes` é `isA<EstadoErro>()`, com a mensagem de conexão, e que ainda não há resultado. Depois toca em "Tentar novamente" (procurado dentro do `EstadoErro`) e confere:
     - os termos ficam `['mar', 'mar']`;
     - o erro some;
     - `form-cliente-77` aparece e fica `selected` ao ser tocado.
  2. `busca de clientes: "Tentar novamente" usa o texto atual do campo`. Busca 'ana' pelo "search" do teclado, que falha. Depois troca o texto para 'bruno' sem buscar (os termos continuam `['ana']`) e toca em retry. Resultado: `['ana', 'bruno']`, o erro some e aparece o `EstadoVazio` `form-clientes-vazio`.
- `test/a11y/telas_harness.dart`: estado novo `EstadoF4.erroClientes`, só no formAdmin.
  - `clientesApi.buscar` lança `semConexao`, e o harness busca 'mar' pelo botão.
  - `verify(buscar('mar')).called(1)`.
  - Confere `form-erro-clientes` com `isA<EstadoErro>()` e "Tentar novamente" dentro dele.
  - Confere que o bloco está na área visível da tela. Assim os guidelines não rodam sobre outro estado e passam por acaso.
- `test/a11y/acessibilidade_test.dart`: `(formAdmin, erroClientes)` entrou nas duas listas, guidelines (androidTapTarget, labeledTapTarget, textContrast) e 360x640 com textScaler 2.0. São +2 testes.
- `.loop/gate.sh`: mínimos subiram de 450 para 454 no total, de 55 para 57 em a11y e de 46 para 48 em telas. A origem é a contagem real desta volta. Nada foi afrouxado. O `diff` mostra só essas linhas e os comentários.

## Critério → teste → defeito que pega → status
| Critério | Teste | Defeito que pega | Status |
|---|---|---|---|
| 2.1 Erro de lista da API = `EstadoErro` com "Tentar novamente" (busca de clientes do Form admin) | telas_fase4 "busca de clientes: erro com EstadoErro…" | `BlocoErro` ou texto solto com a mesma Key (NC-C); retry sem efeito (NC-A); retry com termo errado (NC-B); resultado que não aparece depois do retry | PASSOU |
| 2.1 Retry repete `buscarClientes` com o texto do campo | telas_fase4 "…usa o texto atual do campo" | termo fixo ou antigo no callback (NC-B) | PASSOU |
| 4.1 Guidelines no estado de erro da busca | acessibilidade "4.1 guidelines — estados extras formAdmin / erroClientes" | alvo pequeno ou sem rótulo, ou contraste no `EstadoErro`; o harness também falha se o estado não for `EstadoErro` (NC-C) | PASSOU |
| 4.2 360x640 com 2.0 no estado de erro da busca | acessibilidade "4.2 … formAdmin / erroClientes" | overflow ou exceção, e tipo errado (NC-C) | PASSOU |
| Demais critérios da FASE 4 e das FASES 1-3 | suíte completa no gate | já cobertos nas voltas 1-4 | PASSOU (454/454, 0 pulados) |
| 5.3 analyze / test / mvnw / contrato | `.loop/gate.sh` | ver a seção Gates | PASSOU |

## Controles negativos (todos em `agendamento_form_page.dart`, desfeitos com `cp` do backup e conferidos com `diff` vazio e o mesmo sha256 `2b33a3ca…`)
O arquivo já tem alterações não commitadas, então `git diff` contra o HEAD não serve como prova de volta ao estado anterior. A prova é o `diff` contra a cópia de antes, que deu vazio, mais o sha256 igual.

- **NC-A: retry sem efeito.** `onTentarNovamente: () => c.buscarClientes(_busca.text)` virou `() {}`. Os 2 testes novos falharam:
  ```
  Expected: ['mar', 'mar']   Actual: ['mar']
  Expected: ['ana', 'bruno'] Actual: ['ana']
  Some tests failed.
  ```
  Revertido: `diff` vazio, sha256 igual.
- **NC-B: retry com termo fixo.** O callback passou a ser `() => c.buscarClientes('ana')`. Os 2 testes falharam:
  ```
  Expected: ['mar', 'mar']   Actual: ['mar', 'ana']
  Expected: ['ana', 'bruno'] Actual: ['ana', 'ana']
  ```
  Revertido: `diff` vazio, sha256 igual.
- **NC-C: volta ao `BlocoErro`, que era o código da volta 4.** O ramo de erro passou a ser `return BlocoErro(key: const Key('form-erro-clientes'), texto: c.erroClientes!);`. Falharam 4 testes: os 2 de telas e os 2 de a11y (guidelines/erroClientes e 360x640/erroClientes):
  ```
  Expected: <Instance of 'EstadoErro'>
    Actual: BlocoErro:<BlocoErro-[<'form-erro-clientes'>]>
  00:07 +101 -4: Some tests failed.
  ```
  Revertido com `cp`. O `diff` durante a quebra mostrou o arquivo inteiro, porque o script de quebra gravou CRLF. Depois do `cp`, o `diff` ficou vazio e o sha256 voltou a `2b33a3ca…`, o mesmo de antes. O arquivo continua com LF.

Os 2 testes de telas e os 2 de a11y passaram com o código correto antes e depois dos controles (`flutter test --no-pub test/fase4/telas_fase4_test.dart test/a11y/acessibilidade_test.dart`: 105/105). Os gates abaixo também rodaram depois dos controles.

## Gates
- `GATE_PORTA=18080 bash .loop/gate.sh`, saída em `C:\Users\Usuario\AppData\Local\Temp\claude\9e3f5ea25985bb0e\aa4b67d2-cc1c-422a-86c6-a821ec117fd3\scratchpad\gate-volta5.txt`:
  - analyze `No issues found!`;
  - `flutter test`: passaram 454, pulados 0, falharam 0;
  - FASES 1-3: 285 (mínimo 285);
  - a11y 57/57 mínimo, tokens 42/42, widgets 22/22, telas 48/48;
  - mvnw `Tests run: 217, Failures: 0, Errors: 0, Skipped: 0`, `BUILD SUCCESS`;
  - contrato: passaram 3 de 3;
  - backend com porcelain e HEAD iguais;
  - **`GATE: PASSOU`, `GATE_RC=0`**.
- `GATE_PORTA=18080 bash .loop/gate.frozen.sh`:
  - **1ª tentativa**, em `C:\Users\Usuario\AppData\Local\Temp\claude\9e3f5ea25985bb0e\aa4b67d2-cc1c-422a-86c6-a821ec117fd3\scratchpad\gate-frozen-volta5-tentativa1.txt`: **`GATE: FALHOU (1 problema(s))`, `GATE_RC=1`**. Flutter estava todo verde (454; mínimos frozen 43/42/22/33) e o contrato deu 3/3. A falha foi no mvnw:
    ```
    AgendamentoAdminIntegrationTest.buscaDeClientesTrataPercentUnderlineEBarraComoTexto:406
      JSON path "$.length()" expected:<1> but was:<2>
    Tests run: 217, Failures: 1 ... BUILD FAILURE
    ```
  - **2ª tentativa**, sem nenhuma mudança, em `C:\Users\Usuario\AppData\Local\Temp\claude\9e3f5ea25985bb0e\aa4b67d2-cc1c-422a-86c6-a821ec117fd3\scratchpad\gate-frozen-volta5.txt`: analyze sem issues, 454/454, mvnw 217/217 `BUILD SUCCESS`, contrato 3/3, **`GATE: PASSOU`, `GATE_RC=0`**.
- A porta 8080 (backend local do usuário, PID 25104) não foi tocada e continua em LISTEN. A 18080 ficou livre ao final.

## Falhas
### F1. Teste do backend instável (pré-existente, FASE 3; não é regressão da FASE 4)
- Teste: `cortecerto-backend-loop/src/test/java/.../fase3/AgendamentoAdminIntegrationTest.java:406`, última asserção (`busca=100%` espera 1 resultado).
- Causa, conferida por leitura:
  - `ClienteRepository.buscar` também faz `c.cpf like '%' || digitos || '%'`, e os dígitos de "100%" são "100".
  - Os clientes do teste recebem CPF aleatório (`AbstractIntegrationTest.novoCpf()` com `ThreadLocalRandom`). Quando algum CPF contém "100", a busca devolve 2.
  - É probabilístico. A estimativa é de alguns por cento por execução (cerca de 4 a 6 CPFs com 9 posições cada).
- Por que não é desta volta: o backend está intocado (HEAD `7620220`, porcelain 0), e o mesmo teste passou no `gate.sh` minutos antes e na 2ª execução do frozen.
- Reproduzir: `cd cortecerto-backend-loop && JAVA_HOME=/c/Users/Usuario/.jdks/corretto-21.0.11 PATH="$JAVA_HOME/bin:$PATH" ./mvnw -B test -Dtest=AgendamentoAdminIntegrationTest#buscaDeClientesTrataPercentUnderlineEBarraComoTexto`. Pode ser preciso repetir várias vezes até cair num CPF com "100".
- Menor correção segura (fora do escopo da FASE 4, que não edita o backend): no teste, fixar os CPFs dos clientes criados, ou usar um termo sem dígitos (por exemplo `"% S"`), ou conferir pelo id em vez de pelo `length()`. Fica a decisão para o usuário ou uma fase de backend.
- Impacto no gate: qualquer um dos dois gates pode falhar de forma intermitente por esse motivo. Não afrouxei nada.

## Achados de segurança
- Nenhum achado novo nesta volta. O diff desta volta só toca testes e os mínimos do gate. O grep de segredos no diff não achou nada além da senha de fixture `abc12345`, que já existia nos testes com API fake. As checagens de segurança do gate passaram nos dois gates.
- BAIXA (informativo, pré-existente): a busca de clientes do admin casa os dígitos do termo contra o CPF completo armazenado. Um termo com dígitos, como "100%", traz clientes pelo CPF. É o comportamento documentado (`nome ou dígitos do CPF`, só ADMIN). O CPF na resposta vem mascarado. Não é vazamento, mas explica o F1.

## O que NÃO foi possível testar
- Visual (só uma pessoa olhando a tela pode aprovar):
  - o `EstadoErro` centralizado (ícone de 48, padding `lg`) dentro da seção "Cliente", que é alinhada à esquerda;
  - o contraste real com a Roboto;
  - a aparência em aparelho a 200%;
  - o TalkBack.

  Os testes usam a fonte de teste do Flutter, e não há emulador nem capturas.
- O retry contra o backend real: o teste de contrato não cobre a falha de rede da busca de clientes. O retry foi provado só com a API fake.
- As sugestões 2 e 3 do review da volta 4 (alinhamento do "Agendar" em 360dp e as decisões do usuário) não foram objeto desta volta.

## Proposta de mudança no gate
- O `gate.frozen.sh` continua com mínimos mais fracos (43/33 contra 57/48 no `gate.sh`, sem o mínimo total de 454 e sem a contagem de 285 das FASES 1-3). Proponho que o usuário recongele a partir do `gate.sh` atual se quiser essa proteção no frozen. Não alterei o frozen.
- A instabilidade do F1 afeta os dois gates. Isso deve ser resolvido no teste do backend, não no gate. Repetir automaticamente a etapa do mvnw esconderia defeitos reais.
