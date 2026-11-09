APROVADO

## Revisão analisada (branch / HEAD de cada repositório)
- App `cortecerto_flutter`: branch `main`, HEAD `2d0bf7e`, mais as alterações não commitadas da FASE 4 (voltas 1 a 5). `git status --porcelain` tem 35 entradas.
- Arquivos alterados nesta volta: conferi com `find -newer gate-frozen-volta4.txt`. Mudaram:
  - `lib/features/admin/presentation/agendamento_form_page.dart`, sha256 `2b33a3ca…09ba`, igual ao `form_page.orig` do tester e ao registrado em `testes.md`;
  - `test/a11y/acessibilidade_test.dart`;
  - `test/a11y/telas_harness.dart`;
  - `test/fase4/telas_fase4_test.dart`;
  - `.loop/gate.sh`;
  - os `.md` do loop.

  O `diff` entre `rev4_libdiff.patch` e o `git diff HEAD -- lib/` atual mostra que, em `lib/`, só mudou `_ResultadoClientes`, mais o callback no ponto de construção. Nenhum controller, rota, `app.dart`, `pubspec.yaml` ou teste antigo (FASES 1-3) mudou nesta volta.
- Backend `cortecerto-backend-loop`: branch `loop/mobile-migration`, HEAD `7620220`, `git status --porcelain` com 0 linhas (conferi agora).
- `gate.frozen.sh`: sha256 `d8589c21…26a9`, igual ao `frozen_sha.txt`. Não foi alterado.
- Gates: `gate-volta5.txt` (14:35:51) e `gate-frozen-volta5.txt` (14:40:37) terminam em `GATE: PASSOU`/`GATE_RC=0`. Os dois são posteriores à última modificação de `lib/`, `test/` e `gate.sh` (14:33:34), então valem para esta revisão.
- Ordem: li o diff e o código antes de abrir `dev.md` e `testes.md`.

## Achados

[IMPORTANTE] 1. Teste do backend instável (pré-existente, FASE 3): pode derrubar qualquer gate de forma intermitente
- Local:
  - `cortecerto-backend-loop/src/test/java/br/com/ninodev/cortecerto/fase3/AgendamentoAdminIntegrationTest.java:405-406`, a busca `"100%"` com `length() == 1`;
  - a causa está em `ClienteService.java:78`, onde `digitos = termo.replaceAll("\\D","")` vira `"100"`;
  - e em `ClienteRepository.java:30-33`, com `or (:digitos <> '' and c.cpf like '%'||:digitos||'%')`;
  - o CPF vem de `AbstractIntegrationTest.java:67-79`, `novoCpf()` com `ThreadLocalRandom`.
- Gatilho: um dos 4 clientes que não são a "Ana 100% Silva" recebe um CPF aleatório contendo "100". São `outro` e os 3 do laço da linha 390. O CPF do próprio `clienteId` não atrapalha, porque é a mesma linha. A chance é de cerca de 9 janelas × 1/1000 por CPF, ou seja, uns 3 a 4% por execução. As outras buscas do teste (`%`, `_`, `\`, `a_a`) não têm dígitos e não são afetadas.
- Esperado x obtido: o esperado é 1 resultado. Na 1ª tentativa do frozen veio `expected:<1> but was:<2>`.
- Evidência: DEMONSTRADO.
  - A falha está em `gate-frozen-volta5-tentativa1.txt:961-1047`, com Flutter 454/454 e contrato 3/3 na mesma execução.
  - A causa foi confirmada lendo o teste, o service e o repository.
  - O teste passou em `gate-volta5.txt` e em `gate-frozen-volta5.txt`.
  - O backend está intocado (HEAD e porcelain iguais), então não é regressão da FASE 4. A análise do tester em `testes.md` (F1) está correta.
- Impacto: não afeta o app nem o critério 5.3 desta fase. O código de produção se comporta como documentado ("nome ou dígitos do CPF"). O risco é de processo: o `loop.sh` ou o usuário podem ver um gate vermelho sem defeito real.
- Menor correção segura: fica fora desta fase, que não pode editar o backend. Numa fase de backend, há três caminhos no teste:
  - conferir a presença do `clienteId` em vez do `length()`;
  - usar um termo sem dígitos;
  - gerar os CPFs dos clientes do teste sem a sequência "100".

  Não se deve pôr retry automático no gate. Vai para o RELATORIO como decisão do usuário.

[SUGESTÃO] 2. Retry com o campo vazio não faz nada, e o caso não foi registrado no `dev.md` como o veredito pediu
- Local:
  - `lib/features/admin/presentation/agendamento_form_page.dart:105`, com `() => c.buscarClientes(_busca.text)`;
  - `agendamento_form_controller.dart:201-202`, com `if (t.isEmpty) return;`.
- Gatilho: a busca falha, o admin apaga o campo e toca em "Tentar novamente".
- Esperado x obtido: o veredito da volta 4 aceitou que nada aconteça, mas pediu o registro no `dev.md`. O `dev.md` não menciona o caso (conferi com `grep`). O erro continua na tela sem nenhum retorno.
- Evidência: SUSPEITA quanto ao comportamento em tela. Vem da leitura do código e não há teste para isso.
- Impacto: baixo. O caso é raro e não perde dados.
- Menor correção: registrar no RELATORIO como comportamento conhecido. Não precisa de mudança de código.

[SUGESTÃO] 3. Comentário do cabeçalho do `gate.sh` desatualizado
- Local: `.loop/gate.sh:8`. O comentário diz "menos que 450 no total", mas a checagem real (`:202`) é `-lt 454`.
- Impacto: só na documentação. O limiar efetivo está certo e mais rígido.

[SUGESTÃO] 4. Decisões que continuam com o usuário (não são defeitos desta volta, vão para o RELATORIO)
- O `gate.frozen.sh` é mais fraco que o `gate.sh`:
  - os mínimos do frozen são 43/42/22/33, contra 57/42/22/48 no `gate.sh`;
  - o frozen não tem o total de 454 nem a contagem dos 285 antigos.

  O `diff` mostra que o `gate.sh` só endurece. O usuário pode recongelar.
- D1 (`lib/core/agenda/grade_atendimento.dart` + linha em `agenda_admin_controller.dart`): foi autorizado pelo orquestrador e precisa da ciência do usuário.
- A seta "Voltar" em Meus Agendamentos, que também é aba da NavigationBar.
- O "Agendar" em 360dp quando o `Wrap` quebra (sugestão 2 da volta 4).

## Conferido sem achado (tentativas de derrubar que não se sustentaram)
- **Correção do 2.1 (busca de clientes):** `_ResultadoClientes` (`agendamento_form_page.dart:207-245`) agora usa `EstadoCarregando`, `EstadoErro(key: form-erro-clientes, onTentarNovamente)` e `EstadoVazio(form-clientes-vazio)`. A Key foi mantida, e `fase3_tester_test.dart:543` continua passando.
- **Duplo toque e concorrência no retry:**
  - `buscarClientes` limpa o erro e marca `buscando` antes do `await`, de forma síncrona, e notifica. O `EstadoErro` sai da árvore no mesmo frame.
  - Toques dentro do mesmo frame são resolvidos pela guarda `_reqClientes`: só a última resposta vale.
  - O retry chama a mesma ação do `botao-buscar-cliente`, sem caminho novo no controller.
- **Termo usado no retry:** é o texto atual do campo, não um termo guardado. Isso é coerente com o botão de buscar e foi testado ("ana" → "bruno").
- **Varredura dos três estados em `lib/features/**/*_page.dart`** (`grep` de `BlocoErro`, `EstadoErro`, `EstadoVazio`, `EstadoCarregando` e indicadores):
  - os únicos `BlocoErro` restantes são erros de envio, perto do botão: `form-erro` (`:158`), `erro-agendamento`, `erro-cadastro` e `erro-login`;
  - toda lista carregada da API tem os três estados: Serviços, Meus, horários do Agendamento, Agenda Admin, e serviços, horários e busca de clientes do Form;
  - não sobrou nenhum `LinearProgressIndicator`.

  O critério 2.1 está atendido na régua do finalizador (cada lista da API).
- **Os testes novos verificam de verdade:**
  - `telas_fase4_test.dart:751-801` usa `isA<EstadoErro>`, procura "Tentar novamente" **dentro** do bloco com a Key, confere a contagem e os termos das chamadas e checa que o erro some e o resultado aparece e é selecionável;
  - o harness (`telas_harness.dart:280-282, 337-372`) confere o tipo, o botão dentro do bloco e o bloco na área visível antes dos guidelines, o que evita guidelines rodando sobre outro estado.

  Os controles negativos NC-A, NC-B e NC-C descritos em `testes.md` atacam exatamente os modos de falha possíveis: callback vazio, termo fixo e volta ao `BlocoErro`.
- **Gate não afrouxado:**
  - o `diff` entre `gate.sh.antes` (volta 4) e o `gate.sh` atual mostra só o aumento dos mínimos (450→454, a11y 55→57, telas 46→48) e comentários;
  - o `diff` entre o frozen e o `gate.sh` mostra só acréscimos e endurecimentos;
  - as contagens batem com a saída real do gate (454; 57/42/22/48; 285 antigos).
- **Afirmações do `dev.md` e do `testes.md`:** batem com o diff, com os sha256 e com as saídas dos gates.

## Critérios do TAREFA.md
Não encontrei nenhum critério descumprido no código ou nos testes.
- **1.x tokens, temas, StatusChip, sem cor/fonte fixa, contraste:** `tema_tokens_test` (42) e as checagens estáticas do gate, verdes.
- **2.x estados, botão com envio e diálogo:** a lacuna da volta 4 está fechada.
- **3 telas:** testes das voltas anteriores, ainda verdes. Esta volta não mexeu nessas telas além do Form.
- **4.1/4.2:** 57 testes, incluindo o estado novo. **4.3/4.4:** sem mudança.
- **5.1:** 285 antigos passando, sem teste antigo alterado nesta volta.
- **5.2:** só D1, autorizado.
- **5.3:**
  - analyze sem issues;
  - 454/454 com 0 pulados;
  - mvnw 217/217 nos dois gates finais;
  - contrato 3/3;
  - backend com porcelain 0.

A ressalva é o achado 1: o mvnw pode falhar de forma intermitente por um teste da FASE 3, sem relação com esta fase.

## Limites da revisão
- **Executado:**
  - `git rev-parse`, `status` e `diff` nos dois repositórios;
  - `find -newer` contra os gates;
  - `cmp` do form contra `form_page.orig` e o sha256;
  - `diff` entre `gate.sh.antes`, `gate.sh` e `gate.frozen.sh`, e o sha256 do frozen;
  - `grep` da varredura de estados;
  - `flutter test --no-pub test/fase4/telas_fase4_test.dart test/a11y/acessibilidade_test.dart test/tester/fase3_tester_test.dart`, com 140/140 passando.
- **Só lido:**
  - o código do Form e o `buscarClientes` do controller;
  - o `EstadoErro`;
  - os testes e o harness novos;
  - o teste do backend, o `ClienteService.buscarClientes`, o `ClienteRepository.buscar` e o `AbstractIntegrationTest.novoCpf`;
  - as três saídas de gate.
- **Não reexecutado:** a suíte completa, o mvnw e o contrato. Usei os gates desta revisão. Também não rodei o teste do backend repetidas vezes para reproduzir a instabilidade: a evidência é a falha registrada na tentativa 1 mais a leitura da causa. Não procurei o mesmo padrão (busca com dígitos contra CPF aleatório) em outros testes do backend.
- **Depende de aprovação humana:** não há capturas de tela, e os testes usam a fonte de teste do Flutter, não a Roboto. As checagens técnicas não substituem a aprovação visual de uma pessoa num aparelho ou emulador. Precisam ser vistos:
  - o `EstadoErro` centralizado dentro da seção "Cliente", que é alinhada à esquerda;
  - a Roboto a 200%;
  - o TalkBack;
  - o dourado sobre grafite;
  - o "Agendar" em 360dp.
