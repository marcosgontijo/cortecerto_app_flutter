#!/usr/bin/env bash
# Só atua quando o loop está em andamento (existe .loop/)
[ -d .loop ] || exit 0
GATE=.loop/gate.frozen.sh; [ -f "$GATE" ] || GATE=.loop/gate.sh
[ -f "$GATE" ] || exit 0                    # tester ainda não criou o gate

# Limite de segurança: no máximo 6 bloqueios
N=$(cat .loop/stop-count 2>/dev/null || echo 0)
[ "$N" -ge 6 ] && { echo "Limite de bloqueios atingido" >&2; exit 0; }

# Veredito BLOQUEADO: precisa do humano, deixa parar
head -1 .loop/veredito.md 2>/dev/null | grep -q "STATUS: BLOQUEADO" && exit 0

[ -f .loop/gate.frozen.sh ] || cp .loop/gate.sh .loop/gate.frozen.sh
if bash "$GATE" > .loop/gate.log 2>&1 && head -1 .loop/veredito.md 2>/dev/null | grep -q "STATUS: ENTREGUE"; then
  rm -f .loop/stop-count; exit 0           # deu certo: pode parar
fi
echo $((N+1)) > .loop/stop-count
{ echo "O gate falhou ou o veredito não é ENTREGUE. Faça mais uma volta (developer → tester → reviewer → finalizador)."; tail -30 .loop/gate.log; } >&2
exit 2                                     # exit 2 = não pode parar
