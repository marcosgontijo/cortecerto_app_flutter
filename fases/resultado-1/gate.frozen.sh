#!/usr/bin/env bash
# Gate da FASE 1 (somente backend). Roda sem interação e sai 0 só se TUDO passar.
# Uso (a partir da raiz do app Flutter):  bash .loop/gate.sh
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND="$(cd "$FLUTTER_ROOT/../cortecerto-backend-loop" 2>/dev/null && pwd || true)"

falhas=0
falhou() { echo "GATE FALHOU: $*" >&2; falhas=$((falhas + 1)); }

# ---------------------------------------------------------------- Java 21
if [ -d /c/Users/Usuario/.jdks/corretto-21.0.11 ]; then
  export JAVA_HOME=/c/Users/Usuario/.jdks/corretto-21.0.11
elif [ -d /mnt/c/Users/Usuario/.jdks/corretto-21.0.11 ]; then
  export JAVA_HOME=/mnt/c/Users/Usuario/.jdks/corretto-21.0.11
else
  echo "GATE FALHOU: Java 21 (corretto-21.0.11) não encontrado" >&2
  exit 2
fi
export PATH="$JAVA_HOME/bin:$PATH"

if [ -z "$BACKEND" ] || [ ! -f "$BACKEND/mvnw" ]; then
  echo "GATE FALHOU: backend não encontrado em $FLUTTER_ROOT/../cortecerto-backend-loop" >&2
  exit 2
fi
cd "$BACKEND" || exit 2
echo "== Backend: $BACKEND"
echo "== JAVA_HOME: $JAVA_HOME"
"$JAVA_HOME/bin/java" -version 2>&1 | head -1

# ---------------------------------------------------------------- checagem de segredos
echo "== Checagem de segredos"

# 1) application*.yml do main: chave JWT e senha do admin só via variável de ambiente
for f in src/main/resources/application*.yml src/main/resources/application*.yaml src/main/resources/application*.properties; do
  [ -f "$f" ] || continue
  # secret-key / senha / password / seed com valor literal (que não seja ${...} nem vazio)
  if grep -nEi '^\s*(secret-key|senha|password|seed)\s*[:=]\s*["'"'"']?[^"'"'"'$[:space:]{][^[:space:]]*' "$f"; then
    falhou "valor literal de segredo em $f"
  fi
done

# 2) migrations novas (V2+) não podem inserir usuário nem gravar senha literal
for f in src/main/resources/db/migration/V*.sql; do
  case "$(basename "$f")" in V1__*) continue ;; esac
  if grep -niE 'insert[[:space:]]+into[[:space:]]+cliente' "$f"; then
    falhou "migration $f insere cliente (seed de usuário)"
  fi
  if tr '\n' ' ' < "$f" | grep -oiE "set[^;]*" | sed -E 's/[Ww][Hh][Ee][Rr][Ee].*//' | grep -iE "senha[[:space:]]*=[[:space:]]*'" ; then
    falhou "migration $f grava senha literal"
  fi
done

# 3) a V1 (já aplicada em produção) não pode ser alterada (checksum do Flyway)
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  if ! git diff --quiet HEAD -- src/main/resources/db/migration/V1__init.sql; then
    falhou "V1__init.sql foi alterada (quebra o checksum do Flyway em produção)"
  fi
  # 4) nada de .env, banco ou chave privada versionados
  if git ls-files | grep -E '(^|/)\.env$|\.db$|\.pem$|\.p12$|\.jks$|\.key$'; then
    falhou "arquivo sensível versionado"
  fi
  if git ls-files -z -- ':!web' | xargs -0 grep -lIE 'BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,}' 2>/dev/null; then
    falhou "chave privada/token encontrado em arquivo versionado"
  fi
fi

# 5) arquivos novos (ainda não versionados) também: .env real não pode estar fora do .gitignore
if [ -f .env ] && ! git check-ignore -q .env 2>/dev/null; then
  falhou ".env existe e não está no .gitignore"
fi

# 6) .env.example sem valores para os segredos
if [ -f .env.example ]; then
  if grep -nE '^(SECURITY_JWT_SECRET_KEY|ADMIN_SENHA|ADMIN_CPF)=.+' .env.example; then
    falhou ".env.example contém valor para segredo"
  fi
else
  falhou ".env.example ausente"
fi

# 7) nada de @CrossOrigin("*") ou credenciais com curinga no código de produção
if grep -rnE '@CrossOrigin|setAllowCredentials\(true\)' src/main/java; then
  falhou "CORS com curinga/credenciais no código de produção"
fi

# ---------------------------------------------------------------- build + testes
echo "== ./mvnw -B clean test"
if ! ./mvnw -B clean test; then
  falhou "./mvnw -B clean test"
fi

echo
if [ "$falhas" -ne 0 ]; then
  echo "GATE: FALHOU ($falhas problema(s))"
  exit 1
fi
echo "GATE: PASSOU"
exit 0
