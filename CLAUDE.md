# Fluxo de trabalho com agentes

Este projeto usa um loop de agentes controlado por `loop.sh`. Quando receber uma volta do loop, siga exatamente esta ordem, usando os subagentes:

1. **analista**: somente se `.loop/contexto.md` não existir.
2. **developer**: implementa a TAREFA ou corrige o que está em `.loop/feedback.md`.
3. **tester**: escreve e roda os testes e mantém `.loop/gate.sh`.
4. **reviewer**: faz a revisão crítica e escreve `.loop/review.md`.
5. **finalizador**: escreve `.loop/veredito.md` (e `.loop/RELATORIO.md` se for ENTREGUE).

Regras gerais:
- `TAREFA.md` é a fonte da verdade sobre o que foi pedido e os critérios de aceite.
- Nenhum agente edita `.loop/gate.frozen.sh`.
- Nada de commit, push, deploy, publicação ou requisições a sistemas externos. Quem faz o commit é o `loop.sh`.
- Se algo for ambíguo, não invente: o finalizador marca BLOQUEADO e explica o motivo.

## Contexto deste projeto
- App **mobile Flutter** (CorteCerto), migração do web Angular. Os repositórios e permissões estão na tabela do `TAREFA.md`.
- **Backend Spring Boot** (editável): `C:\Users\Usuario\Documents\Projetos\Dev\Projetos\cortecerto-backend-loop` (worktree, branch `loop/mobile-migration`).
- **Referência do web** (somente leitura, nunca editar): `cortecerto-backend-loop\web\cortecertoweb`. A pasta antiga `cortecertoweb` NÃO é referência.
- Comandos: Flutter `flutter pub get`, `flutter analyze`, `flutter test`. Backend: `./mvnw test` (precisa de Java 21: exporte `JAVA_HOME=/c/Users/Usuario/.jdks/corretto-21.0.11` e coloque `$JAVA_HOME/bin` no começo do PATH; o java do PATH do sistema é o 8).
- O `.loop/gate.sh` deve rodar os testes dos DOIS lados (Flutter e backend).
- Nunca fazer commit/push no repositório do backend.

## Modo chat (sem o loop.sh)
Quando o usuário pedir para "entrar no loop" dentro do chat, o agente principal orquestra:
1. Crie `.loop/` se não existir.
2. Rode o **analista** (só se `.loop/contexto.md` não existir).
3. Repita **developer → tester → reviewer → finalizador** até o veredito ser `STATUS: ENTREGUE`, no máximo 6 voltas.
4. Antes de cada volta nova, apague `.loop/review.md`, `.loop/veredito.md`, `.loop/dev.md`, `.loop/testes.md` e monte `.loop/feedback.md` com a saída do gate + review + veredito da volta anterior.
5. Na primeira vez que `.loop/gate.sh` existir, copie para `.loop/gate.frozen.sh` e avise o usuário para revisá-lo.
6. Se o veredito for `STATUS: BLOQUEADO`, pare e mostre o motivo ao usuário.

## Fases
O trabalho está dividido em fases (`fases/README.md`). O `TAREFA.md` da raiz é sempre a fase ativa. Trabalhe só no escopo dela.
