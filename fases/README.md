# Plano em fases: migração do CorteCerto para o mobile

| Fase | Foco | Onde mexe | Gate |
|---|---|---|---|
| [FASE-1](FASE-1.md) | Backend seguro (BCrypt, JWT, validação, papéis, PII) e sem agendamento duplicado | Backend | `./mvnw test` |
| [FASE-2](FASE-2.md) | Base do app (go_router, sessão, ApiClient único) + telas do cliente | Flutter | `flutter analyze` + `flutter test` |
| [FASE-3](FASE-3.md) | CRUD de agendamentos do admin + "Meus Agendamentos" sempre atualizado | Backend + Flutter | os três |

O loop sempre lê o `TAREFA.md` da raiz. **A fase ativa é a que está copiada lá.**

## Como passar para a próxima fase
Depois de a fase atual terminar com ✅ ENTREGUE:

1. Revise as mudanças: `git diff` no Flutter e, na pasta `cortecerto-backend-loop`, `git status` / `git diff`.
   Se aprovar, faça o commit do backend você mesmo (os agentes não fazem commit lá).
2. Guarde o resultado da fase e limpe o estado do loop (Git Bash/WSL, na raiz do Flutter):
   ```bash
   N=1   # número da fase que acabou
   mkdir -p fases/resultado-$N && cp .loop/RELATORIO.md .loop/historico.md fases/resultado-$N/ 2>/dev/null
   rm -rf .loop        # o gate muda a cada fase; o analista roda de novo e vê o código novo
   ```
3. Ative a próxima fase: `cp fases/FASE-2.md TAREFA.md`
4. Faça o commit no Flutter: `git add -A && git commit -m "inicio da fase 2"`
5. Entre no loop de novo: *"Siga o fluxo do CLAUDE.md para a tarefa do TAREFA.md, no máximo 6 voltas."*
   Na primeira volta, revise o `.loop/gate.frozen.sh`.
