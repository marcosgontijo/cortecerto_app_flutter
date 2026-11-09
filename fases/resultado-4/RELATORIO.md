# RELATÓRIO: FASE 4 (Redesign de UI/UX), entregue na volta 5

Revisão: app `cortecerto_flutter` no `main`/`2d0bf7e`, mais as alterações não commitadas da FASE 4 (35 entradas). Backend `cortecerto-backend-loop` no `loop/mobile-migration`/`7620220`, intocado (porcelain com 0 linhas).

## O que foi entregue
**Base visual (`lib/core/theme/`, `lib/core/widgets/`)**
- Tokens do `design-system/cortecerto/MASTER.md`:
  - `ColorScheme` escuro (grafite + dourado);
  - `AppTokens` (`ThemeExtension`) com `success`, `warning`, `info`, `neutral`, espaçamentos e raios;
  - `TextTheme` com a escala do MASTER.
- Temas de componente: botões, inputs, card, chip, AppBar, NavigationBar, SnackBar flutuante, Dialog e FAB.
- Componentes comuns:
  - `EstadoCarregando`, `EstadoVazio` e `EstadoErro` (com "Tentar novamente");
  - botão primário com estado de envio, sem toque duplo;
  - diálogo de confirmação destrutivo;
  - `StatusChip` com ícone e texto;
  - cabeçalho da marca;
  - `NavigationBar` do cliente;
  - blocos de feedback.
- `StatusAgendamento` não guarda mais `Color`. A cor vem do tema.
- `lib/features/**` não tem mais cor nem tamanho de fonte fixos, e `lib/` não tem emoji.

**Por tela**
- **Login / Cadastro:**
  - marca no topo, rótulos visíveis e ícones nos campos;
  - máscaras de CPF e telefone mantidas;
  - erro embaixo do campo;
  - mostrar/ocultar senha com rótulo acessível;
  - teclado com next/done (o done envia) e `autofillHints`;
  - botão com estado de envio;
  - link entre Login e Cadastro;
  - erro do servidor num bloco perto do botão.
- **Navegação do cliente:** barra inferior com Serviços, Meus agendamentos e Produtos. Os paths são os mesmos e o logout está em todas. Agendamento e Confirmado ficam fora da barra.
- **Serviços:** cards com ícone, nome, descrição, preço e "Agendar" à direita, mais os estados de carregando, vazio e erro com retry.
- **Produtos:** cards selecionáveis e barra fixa com `SafeArea`, quantidade e total. A barra ocupa toda a largura e não esconde a lista.
- **Agendamento:**
  - indicador de etapas Data → Horário → Confirmar, com o serviço no topo;
  - chips de horário ≥ 48dp, com os ocupados riscados, com ícone e com "Indisponível";
  - resumo antes de confirmar;
  - botão fixo, desabilitado até escolher o horário;
  - 409 mostra uma mensagem clara e recarrega os horários.
- **Confirmado:** ícone de sucesso, resumo, CTA "Ver meus agendamentos" e secundário "Voltar aos serviços". O Voltar do Android leva a `/servicos`.
- **Meus Agendamentos:**
  - abas Próximos/Histórico com contagem;
  - cards com data e horário em destaque e `StatusChip`;
  - vazio por aba com "Agendar um horário";
  - cancelar com diálogo e SnackBar.
- **Painel Admin:** saudação e card grande com ícone para a Agenda.
- **Agenda Admin:**
  - chips Hoje/Amanhã/Data;
  - contadores por status viram chips de filtro;
  - horário livre aparece como "Disponível" com ícone de adicionar;
  - horário ocupado mostra cliente, serviço e `StatusChip`;
  - FAB com ícone e tooltip "Novo agendamento";
  - detalhes em bottom sheet, com as ações destrutivas separadas e em `error`.
- **Formulário de agendamento (admin):**
  - mesmas regras de campo do Login/Cadastro;
  - serviços, horários e busca de clientes, cada um com carregando, vazio e erro com "Tentar novamente";
  - a busca de clientes foi a última a ganhar o retry, na volta 5.

## Como testar manualmente
1. Em `cortecerto-backend-loop`, suba o backend (Java 21).
2. No app, rode `flutter pub get` e `flutter run` num emulador ou aparelho Android. Se o seu backend local usa a 8080, mantenha a configuração de URL atual.
3. Como cliente:
   - cadastre-se e entre;
   - percorra Serviços → Agendar → escolha data e horário → confirme → Confirmado → Ver meus agendamentos;
   - cancele um agendamento e confira o diálogo e o SnackBar;
   - abra Produtos, selecione itens e veja o total na barra fixa.
4. Como admin:
   - Painel → Agenda;
   - troque entre Hoje, Amanhã e Data e filtre por status;
   - toque num horário livre (abre o formulário) e num ocupado (abre o bottom sheet);
   - use o FAB.
5. Desligue o backend com uma tela aberta e toque em "Tentar novamente". Faça isso em Serviços, nos horários e na busca de clientes do formulário admin.
6. Em Configurações do Android, aumente a fonte para 200% e ligue o TalkBack. Repita os passos 3 e 4.

As capturas geradas pelo loop (fonte real do sistema, tamanho de aparelho, build de teste com banner DEBUG) estão em `C:\Users\Usuario\AppData\Local\Temp\claude\9e3f5ea25985bb0e\aa4b67d2-cc1c-422a-86c6-a821ec117fd3\scratchpad\telas\png\`. São 15 arquivos, de `01_login.png` a `15_form_admin_erro_servicos.png`. A pasta é temporária: copie as capturas se quiser guardá-las.

## Testes e checagens que passaram
Números finais, todos da revisão atual:
- **`.loop/gate.sh`** (`gate-volta5.txt`):
  - `flutter analyze`: No issues found;
  - `flutter test`: 454 passaram, 0 pulados, 0 falharam, assim divididos:
    - FASES 1-3: 285 (mínimo 285);
    - a11y: 57;
    - tokens/contraste: 42;
    - widgets comuns: 22;
    - telas FASE 4: 48;
  - `./mvnw -B clean test`: 217 testes, 0 falhas, BUILD SUCCESS;
  - contrato: 3/3;
  - backend com porcelain e HEAD iguais aos do início da fase;
  - resultado: **GATE: PASSOU**.
- **`.loop/gate.frozen.sh`**:
  - 1ª tentativa: **FALHOU** por 1 teste instável do backend (ver Riscos). Flutter e contrato estavam verdes.
  - 2ª tentativa, sem nenhuma mudança: analyze sem issues, 454/454, mvnw 217/217, contrato 3/3, **GATE: PASSOU**.
- Checagens estáticas: sem `Color(0x`, `Colors.` (exceto `transparent`) nem `fontSize` em `lib/features/`, sem emoji em `lib/`, sem segredos e escopo de arquivos respeitado.
- Os testes de a11y cobrem cada tela e os estados extras:
  - `androidTapTargetGuideline`, `labeledTapTargetGuideline` e `textContrastGuideline`;
  - 360x640 com `textScaler` 2.0 sem overflow;
  - `disableAnimations`.
- Contraste WCAG calculado a partir dos tokens reais: texto ≥ 4.5:1 e `outline` ≥ 3:1.
- O tester aplicou controles negativos em cada correção (quebrou o código de propósito e confirmou que os testes falham).
- Conferido pelo finalizador: `flutter analyze` sem issues e 140/140 nos arquivos de telas, a11y e tester da FASE 3.

**Uso de `GATE_PORTA=18080`:** os gates foram rodados com `GATE_PORTA=18080`, para que o backend temporário do teste de contrato não brigasse com o seu backend local na 8080 (PID 25104, que não foi tocado). Sem a variável, o gate usa a 8080 por padrão. Se a 8080 estiver ocupada, rode `GATE_PORTA=18080 bash .loop/gate.sh`.

## O que ainda precisa de aprovação visual ou humana
Os testes usam a fonte de teste do Flutter, não a Roboto. As checagens técnicas não substituem uma pessoa olhando o aparelho.
- **Aparelho real ou emulador:** aparência geral, dourado sobre grafite e espaçamentos.
- **Roboto real:** contraste e quebras de linha com a fonte de verdade.
- **Fonte em 200%:** em aparelho. O teste de 360x640 com 2.0 só garante que não há overflow.
- **TalkBack:** ordem de leitura e rótulos (mostrar senha, chips de horário, ícone de logout, FAB).
- **Chips de horário com larguras desiguais** (captura `07_agendamento_horario.png`): o chip "Livre" é mais estreito que o "Indisponível", e a grade fica irregular. A sugestão visual é uma grade uniforme, com chips de largura fixa ou um `GridView` de 2 a 3 colunas.
- **"Agendar" em 360dp:** quando preço e botão não cabem na mesma linha (o `Wrap` quebra), o botão vai para a linha de baixo à esquerda, e não à direita. Em largura normal fica à direita (`03_servicos.png`). O mesmo vale para o "Cancelar" em Meus. Com a Roboto, isso provavelmente só acontece com fonte grande. Decida se aceita ou se prefere sempre à direita.
- **Seta "Voltar" em Meus Agendamentos** (`09_meus.png`): a tela é uma aba da barra inferior, mas tem uma seta Voltar no AppBar. Em apps com abas, o normal é não ter a seta. Decida se mantém, porque pode ser um caminho que os usuários do web esperam, ou se remove.
- **Estados centralizados dentro do formulário admin:** o `EstadoErro`/`EstadoVazio` fica centralizado dentro de seções alinhadas à esquerda.
- **Textos novos** (títulos, vazios, mensagens de erro).
- **Banner DEBUG:** nas capturas, ele cobre parte do ícone de logout no canto superior direito. É só no build de debug.

## Decisões tomadas sem o humano
- **D1 (desvio de escopo, para sua ciência):**
  - foi criado `lib/core/agenda/grade_atendimento.dart` (grade 08:00-19:30 de 30 em 30 min, mais `gradeComLivres`);
  - em `agenda_admin_controller.dart`, a lista `grade` passou a vir de `gerarGradeAtendimento()`. Gera exatamente a mesma lista, o comportamento é idêntico e está travado por teste e pelo gate;
  - motivo: a tela de Agendamento do cliente precisa mostrar a grade inteira e marcar como "Indisponível" o que a API não devolveu;
  - as Restrições do TAREFA não previam mexer em controller nem em `lib/core/agenda/`. O orquestrador autorizou, mas a decisão final é sua.
- **Retry com o campo vazio:** no formulário admin, se a busca de clientes falhar e o admin apagar o campo antes de tocar em "Tentar novamente", nada acontece. O controller ignora termo vazio, que é o comportamento de antes, e o erro continua na tela. O botão de buscar continua lá. O caso foi considerado aceitável e não tem teste.
- **FAB da Agenda Admin:** só o ícone "+", com tooltip "Novo agendamento", em vez de FAB estendido com texto. O texto aparece no título do formulário.
- **Atualizações em testes antigos:** onde o texto ou a estrutura mudou de propósito, os testes das FASES 1-3 foram atualizados para o texto novo, mantendo a mesma verificação de comportamento. Exemplo: os redirects por papel passaram a ser verificados por tipo de página. Nenhum teste foi removido.
- **`gate.sh` mais rígido que o `gate.frozen.sh`:** o `gate.sh` ganhou mínimos maiores. O frozen não foi alterado.

## Riscos e limitações conhecidas
- **Teste do backend instável (FASE 3, pré-existente, não é regressão desta fase):**
  - teste: `AgendamentoAdminIntegrationTest.buscaDeClientesTrataPercentUnderlineEBarraComoTexto`, linha 406 (busca "100%" espera 1 resultado).
  - causa: a busca de clientes também casa os dígitos do termo contra o CPF (`ClienteRepository`: `c.cpf like '%'||digitos||'%'`), e "100%" vira os dígitos "100". O teste cria 4 clientes extras com CPF aleatório (`AbstractIntegrationTest.novoCpf()`, `ThreadLocalRandom`). Quando algum deles contém "100", a busca devolve 2.
  - chance: uns 3 a 4% por execução (cerca de 4 CPFs × 9 posições × 1/1000).
  - efeito: qualquer um dos dois gates pode ficar vermelho de vez em quando sem defeito real. Aconteceu na 1ª tentativa do frozen nesta volta.
  - correção sugerida para uma fase de backend (no teste, não no código de produção), escolha uma:
    - conferir que o resultado contém o `clienteId` em vez de conferir `length() == 1`;
    - usar um termo sem dígitos;
    - gerar os CPFs do teste sem a sequência "100".

    Não é recomendado pôr retry automático do mvnw no gate, porque isso esconderia falhas reais.
- **O `gate.frozen.sh` é mais fraco que o `gate.sh`:**
  - mínimos do frozen: a11y 43 e telas 33. No `gate.sh`: 57 e 48;
  - o frozen não confere o total de 454 nem os 285 testes das FASES 1-3.

  Proposta: recongele copiando o `.loop/gate.sh` atual para `.loop/gate.frozen.sh` (só você pode fazer isso). Assim a proteção contra remoção de testes também fica no gate congelado. Antes, corrija o comentário da linha 8 do `gate.sh`, que ainda diz "450" (a checagem real é 454).
- O retry da busca de clientes só foi provado com API fake. O contrato não cobre falha de rede.
- Sem fontes personalizadas e sem tema claro (fora do escopo). Os tokens permitem acrescentar depois.

## Sugestões de próximos passos
1. Faça a aprovação visual em aparelho (lista acima) e decida sobre: seta Voltar em Meus, "Agendar" em 360dp, grade uniforme de horários e FAB com ou sem texto.
2. Registre a ciência do desvio D1.
3. Recongele o `gate.frozen.sh` a partir do `gate.sh` atual.
4. Abra uma tarefa de backend para estabilizar o teste da busca "100%".
5. Faça o commit da FASE 4 (o loop não faz commit) e atualize `fases/README.md` e `fases/resultado-4/`.
6. Quando os arquivos de fonte forem adicionados ao repo, aplique a tipografia sugerida pelo MASTER.md.
