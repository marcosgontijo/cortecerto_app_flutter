# Loop de agentes: como usar

## Instalação no seu projeto
Copie para a raiz do projeto:
```
.claude/agents/   (analista, developer, tester, reviewer, finalizador)
CLAUDE.md         (se o projeto já tem um, cole este conteúdo no final)
TAREFA.md
loop.sh
```
No Windows, rode pelo **WSL** (recomendado) ou pelo Git Bash.

## Uso
1. Escreva o pedido e os **critérios de aceite** em `TAREFA.md`. Esta é a parte que mais importa.
2. Faça um commit do estado atual.
3. Rode `./loop.sh 8` (8 é o máximo de voltas).
4. Na primeira volta, **revise `.loop/gate.frozen.sh`**. É ele que define o que conta como "deu certo".

## Como ele termina
| Saída | Significado | Onde olhar |
|---|---|---|
| 0 ✅ | Gate passou, review APROVADO e veredito ENTREGUE (os três concordam). Faz commit | `.loop/RELATORIO.md` |
| 1 ❌ | Acabaram as voltas | `.loop/feedback.md`, `.loop/historico.md` |
| 2 ⛔ | O finalizador precisa de uma decisão sua | `.loop/veredito.md` |
| 3 🔁 | Mesmo erro 3 vezes seguidas | `.loop/gate.log` |
| 4 ⚠️ | Problema de ambiente (falta claude, TAREFA, git) | terminal |

## Permissões
Em modo `-p` o Claude não pode pedir permissão para você. Então:
- Antes, abra `claude` no projeto e use `/permissions` para liberar os comandos de build e teste da sua stack (mvnw, npm, flutter, npx playwright...).
- Ou rode dentro de um container ou devcontainer e use `CLAUDE_FLAGS="--dangerously-skip-permissions" ./loop.sh`. **Só faça isso isolado da sua máquina.**

## Notificação no celular
Instale o app ntfy, escolha um nome de tópico difícil de adivinhar e rode:
`NTFY_TOPIC=meu-topico-secreto-123 ./loop.sh`

## Arquivos em .loop/ (não vão para o git)
contexto.md · dev.md · testes.md · review.md · veredito.md · feedback.md · historico.md · gate.frozen.sh · RELATORIO.md · logs de cada volta

## O que cada agente aplica
Os agentes foram refinados com base nas skills de [rubenmarcus/agent-skills](https://github.com/rubenmarcus/agent-skills) (commit `e1aa118`):

| Agente | Skill de base | Na prática |
|---|---|---|
| analista | `spec-to-plan` | registra branch/HEAD e o baseline dos testes; separa requisito de sugestão; cada critério de aceite ganha "como verificar"; lista as decisões em aberto |
| developer | `validated-coding-loop` + `evidence-driven-debugging` | uma mudança focada por vez com verificação e código de saída; reproduz o bug antes de corrigir; erro repetido exige hipótese nova |
| tester | `quality-gates` | cada teste diz que defeito pega; controle negativo (quebra proposital que o teste precisa pegar); teste pulado ou sem medição faz o gate falhar |
| reviewer | `critical-adversarial-review` | lê o diff antes do resumo do developer; tenta derrubar o resultado; achados marcados como DEMONSTRADO ou SUSPEITA; não inventa achado |
| finalizador | `multi-agent-collaboration` | confere sozinho as afirmações que decidem o veredito; DESCONHECIDO nunca vira OK; separa aprovação técnica de aprovação visual/humana |

## Créditos
Partes das instruções dos agentes foram traduzidas e adaptadas de [rubenmarcus/agent-skills](https://github.com/rubenmarcus/agent-skills), sob a licença MIT:

> MIT License — Copyright (c) 2026 Ruben Marcus
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
