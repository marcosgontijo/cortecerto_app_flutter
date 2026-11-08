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
