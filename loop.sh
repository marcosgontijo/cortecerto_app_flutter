#!/usr/bin/env bash
# Loop de agentes: analista -> (developer -> tester -> reviewer -> finalizador)*
# Quem decide se acabou é ESTE script, não os agentes.
#
# Uso:  ./loop.sh [MAX_ITERACOES]
# Saída: 0 = ENTREGUE | 1 = não convergiu | 2 = BLOQUEADO | 3 = travado | 4 = erro de ambiente
#
# Variáveis opcionais:
#   CLAUDE_FLAGS  flags extras para o claude (padrão: --permission-mode acceptEdits)
#   NTFY_TOPIC    tópico do ntfy.sh para receber notificação no celular

set -u
MAX="${1:-8}"
CLAUDE_FLAGS="${CLAUDE_FLAGS:---permission-mode acceptEdits}"
L=".loop"

# ---------- utilidades ----------
notificar() {
  echo "$1"
  if [ -n "${NTFY_TOPIC:-}" ]; then
    curl -s -d "$1" "https://ntfy.sh/$NTFY_TOPIC" > /dev/null || true
  fi
}

primeira_linha() { head -1 "$1" 2>/dev/null | tr -d '\r'; }

rodar_claude() {  # $1 = prompt, $2 = arquivo de log
  # shellcheck disable=SC2086
  claude -p "$1" $CLAUDE_FLAGS > "$2" 2>&1
}

# ---------- checagens iniciais ----------
command -v claude > /dev/null || { echo "claude CLI não encontrado"; exit 4; }
[ -f TAREFA.md ] || { echo "Crie o TAREFA.md com o pedido e os critérios de aceite"; exit 4; }
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || { echo "Rode dentro de um repositório git"; exit 4; }

if [ -n "$(git status --porcelain -- . ':!.loop')" ]; then
  echo "⚠️  Há alterações não commitadas. Recomendo commitar antes (Ctrl+C para cancelar, Enter para seguir)."
  read -r _
fi

mkdir -p "$L"
grep -qxF ".loop/" .git/info/exclude 2>/dev/null || echo ".loop/" >> .git/info/exclude
touch "$L/historico.md"

# ---------- fase 0: análise (uma vez) ----------
if [ ! -f "$L/contexto.md" ]; then
  echo "=== Análise inicial do projeto ==="
  rodar_claude "Use o subagente analista para analisar o projeto e escrever .loop/contexto.md." "$L/analise.log"
  [ -f "$L/contexto.md" ] || { echo "O analista não gerou .loop/contexto.md. Veja $L/analise.log"; exit 4; }
fi

# ---------- loop ----------
ULTIMO_ERRO=""
REPETICOES=0

for i in $(seq 1 "$MAX"); do
  echo "=== Volta $i/$MAX ==="

  # apaga os vereditos da volta anterior para nunca reaproveitar um APROVADO antigo
  rm -f "$L/review.md" "$L/veredito.md" "$L/dev.md" "$L/testes.md"

  rodar_claude "Esta é a volta $i do loop. Siga o fluxo do CLAUDE.md usando os subagentes na ordem:
developer -> tester -> reviewer -> finalizador.
Leia TAREFA.md, .loop/contexto.md e, se existir, .loop/feedback.md (problemas da volta anterior)." "$L/volta-$i.log"

  # --- congela o gate na primeira vez que ele aparece ---
  if [ -f "$L/gate.sh" ] && [ ! -f "$L/gate.frozen.sh" ]; then
    cp "$L/gate.sh" "$L/gate.frozen.sh"
    notificar "🔒 Gate congelado na volta $i. Revise .loop/gate.frozen.sh: ele define o que é 'deu certo'."
  fi
  AVISO_GATE=""
  if [ -f "$L/gate.sh" ] && [ -f "$L/gate.frozen.sh" ] && ! cmp -s "$L/gate.sh" "$L/gate.frozen.sh"; then
    AVISO_GATE="ATENÇÃO: .loop/gate.sh foi alterado, mas o gate congelado continua valendo. Não tente mudar o gate."
  fi

  # --- PORTÃO DETERMINÍSTICO: o script roda os testes ---
  if [ -f "$L/gate.frozen.sh" ]; then
    bash "$L/gate.frozen.sh" > "$L/gate.log" 2>&1; GATE=$?
  else
    echo "Nenhum gate foi criado pelo tester." > "$L/gate.log"; GATE=1
  fi

  STATUS="$(primeira_linha "$L/veredito.md")"
  REVIEW="$(primeira_linha "$L/review.md")"
  echo "gate=$GATE | review=${REVIEW:-?} | ${STATUS:-sem veredito}"

  # --- deu certo? os três precisam concordar ---
  if [ "$GATE" -eq 0 ] && [ "$REVIEW" = "APROVADO" ] && [ "$STATUS" = "STATUS: ENTREGUE" ]; then
    git add -A   # .loop/ fica de fora (está no .git/info/exclude)
    git commit -qm "loop: entrega aprovada na volta $i" || true
    notificar "✅ ENTREGUE na volta $i. Relatório: $L/RELATORIO.md"
    exit 0
  fi

  # --- bloqueado: precisa de você ---
  if [ "$STATUS" = "STATUS: BLOQUEADO" ]; then
    notificar "⛔ BLOQUEADO na volta $i. Veja o motivo em $L/veredito.md"
    exit 2
  fi

  # --- detecção de loop travado (mesmo erro 3x seguidas) ---
  ASSINATURA="$(tail -30 "$L/gate.log" | sed -E 's/[0-9]+(\.[0-9]+)?s//g; s/[0-9]{2}:[0-9]{2}:[0-9]{2}//g' | md5sum | cut -d' ' -f1)"
  if [ "$GATE" -ne 0 ] && [ "$ASSINATURA" = "$ULTIMO_ERRO" ]; then
    REPETICOES=$((REPETICOES + 1))
  else
    REPETICOES=0
  fi
  ULTIMO_ERRO="$ASSINATURA"
  if [ "$REPETICOES" -ge 2 ]; then
    notificar "🔁 Travado: o mesmo erro se repetiu 3 vezes (volta $i). Veja $L/gate.log"
    exit 3
  fi

  # --- monta o feedback para a próxima volta ---
  {
    echo "# Feedback da volta $i"
    [ -n "$AVISO_GATE" ] && echo "$AVISO_GATE"
    if [ "$STATUS" = "STATUS: ENTREGUE" ] && [ "$GATE" -ne 0 ]; then
      echo "CONTRADIÇÃO: o finalizador disse ENTREGUE, mas o gate FALHOU. O gate é quem vale."
    fi
    echo; echo "## Gate (saída final)"; tail -40 "$L/gate.log"
    echo; echo "## Review"; cat "$L/review.md" 2>/dev/null || echo "(o reviewer não escreveu review.md)"
    echo; echo "## Veredito e pendências"; cat "$L/veredito.md" 2>/dev/null || echo "(o finalizador não escreveu veredito.md)"
  } > "$L/feedback.md"
done

notificar "❌ Não convergiu em $MAX voltas. Veja $L/feedback.md e $L/historico.md"
exit 1
