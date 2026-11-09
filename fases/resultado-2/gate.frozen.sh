#!/usr/bin/env bash
# Gate da FASE 2 (app Flutter + backend). Roda sem interação e sai 0 só se TUDO passar.
# Uso (a partir da raiz do app Flutter):  bash .loop/gate.sh
#
# Etapas: Java 21 → flutter pub get → flutter analyze → flutter test (sem contract) →
#         checagens estáticas/segurança → ./mvnw -B clean test → sobe o backend (jar) com
#         variáveis de teste → flutter test --tags contract → derruba o backend (trap EXIT).
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND="$(cd "$APP/../cortecerto-backend-loop" 2>/dev/null && pwd || true)"
PORTA=8080

falhas=0
falhou() { echo "GATE FALHOU: $*" >&2; falhas=$((falhas + 1)); }
etapa() { echo; echo "================ $* ================"; }

# ---------------------------------------------------------------- limpeza (sempre)
BACK_PID=""
DB_FILE=""
LOG_BACKEND=""

pids_na_porta() {
  # PIDs (Windows) escutando na porta; vazio se livre.
  if command -v netstat >/dev/null 2>&1; then
    netstat -ano 2>/dev/null | tr -d '\r' \
      | awk -v p=":$PORTA" '$0 ~ /LISTEN|ESCUTA/ && index($2, p) == length($2) - length(p) + 1 {print $NF}' \
      | sort -u
  fi
}

derrubar_backend() {
  if [ -n "$BACK_PID" ]; then
    local winpid=""
    [ -r "/proc/$BACK_PID/winpid" ] && winpid="$(cat "/proc/$BACK_PID/winpid" 2>/dev/null)"
    if [ -n "$winpid" ] && command -v taskkill >/dev/null 2>&1; then
      taskkill //F //T //PID "$winpid" >/dev/null 2>&1 || true
    fi
    kill "$BACK_PID" 2>/dev/null || true
    sleep 1
    kill -9 "$BACK_PID" 2>/dev/null || true
    wait "$BACK_PID" 2>/dev/null || true
    BACK_PID=""
    # a porta estava livre antes de subirmos: quem estiver nela agora é o nosso backend
    local i p
    for i in 1 2 3 4 5 6 7 8 9 10; do
      p="$(pids_na_porta)"
      [ -z "$p" ] && break
      for pid in $p; do
        [ "$pid" = "0" ] && continue
        taskkill //F //T //PID "$pid" >/dev/null 2>&1 || kill -9 "$pid" 2>/dev/null || true
      done
      sleep 1
    done
  fi
}

limpar() {
  local rc=$?
  derrubar_backend
  if [ -n "$DB_FILE" ]; then rm -f "$DB_FILE" "$DB_FILE-wal" "$DB_FILE-shm" "$DB_FILE-journal" 2>/dev/null || true; fi
  if [ -n "$(pids_na_porta)" ]; then
    echo "AVISO: porta $PORTA ainda ocupada após o gate: $(pids_na_porta | tr '\n' ' ')" >&2
  fi
  exit "$rc"
}
trap limpar EXIT
trap 'exit 130' INT TERM

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
JAVA="$JAVA_HOME/bin/java"
[ -x "$JAVA" ] || JAVA="$JAVA_HOME/bin/java.exe"

if ! command -v flutter >/dev/null 2>&1; then
  echo "GATE FALHOU: flutter não está no PATH" >&2
  exit 2
fi
if [ -z "$BACKEND" ] || [ ! -f "$BACKEND/mvnw" ]; then
  echo "GATE FALHOU: backend não encontrado em $APP/../cortecerto-backend-loop" >&2
  exit 2
fi
echo "== App: $APP"
echo "== Backend: $BACKEND"
echo "== JAVA_HOME: $JAVA_HOME"
"$JAVA" -version 2>&1 | head -1

cd "$APP" || exit 2

# ---------------------------------------------------------------- 1. flutter pub get
etapa "flutter pub get"
pub_out="$(flutter pub get 2>&1)"; pub_rc=$?
echo "$pub_out" | tail -15
if [ "$pub_rc" -ne 0 ]; then
  # No Windows sem Modo de Desenvolvedor o pub resolve tudo mas sai 1 no passo de symlink dos plugins.
  if echo "$pub_out" | grep -qiE 'symlink|Developer Mode' \
     && [ -f .dart_tool/package_config.json ] && [ .dart_tool/package_config.json -nt pubspec.yaml ] \
     && ! echo "$pub_out" | grep -qiE 'version solving failed|could not find package|Because .* depends on'; then
    echo "(pub get: erro de symlink do Windows ignorado; dependências resolvidas em .dart_tool/package_config.json)"
  else
    falhou "flutter pub get (dependências não resolvidas)"
  fi
fi
if [ ! -f .dart_tool/package_config.json ]; then
  falhou ".dart_tool/package_config.json ausente"
fi

# ---------------------------------------------------------------- 2. flutter analyze
etapa "flutter analyze"
if ! flutter analyze --no-pub --fatal-warnings --no-fatal-infos; then
  falhou "flutter analyze (erros ou warnings)"
fi

# ---------------------------------------------------------------- 3. flutter test (sem contract)
etapa "flutter test --exclude-tags contract"
if ! flutter test --no-pub --exclude-tags contract; then
  falhou "flutter test --exclude-tags contract"
fi

# ---------------------------------------------------------------- 4. checagens estáticas / segurança (app)
etapa "Checagens estáticas e de segurança (app)"

# 4.1 print/debugPrint/log com dados sensíveis
sens="$(grep -rnE '(^|[^A-Za-z0-9_])(print|debugPrint|log)[[:space:]]*\(' lib --include='*.dart' \
        | grep -iE 'token|senha|password|cpf|jwt|bearer|authorization' || true)"
if [ -n "$sens" ]; then echo "$sens"; falhou "print/debugPrint/log com token/senha/CPF em lib/"; fi
# qualquer print( em lib/ também é proibido (avoid_print); LogInterceptor vaza headers/corpo
outros="$(grep -rnE '(^|[^A-Za-z0-9_.])print[[:space:]]*\(|LogInterceptor' lib --include='*.dart' || true)"
if [ -n "$outros" ]; then echo "$outros"; falhou "print( ou LogInterceptor em lib/"; fi

# 4.2 exatamente um construtor Dio( em lib/ (não conta DioException, BaseOptions etc.)
dios="$(grep -rnE '(^|[^A-Za-z0-9_])Dio[[:space:]]*\(' lib --include='*.dart' | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' || true)"
n_dio="$(printf '%s' "$dios" | grep -c . || true)"
echo "Dio( em lib/: $n_dio"; [ -n "$dios" ] && echo "$dios"
if [ "$n_dio" != "1" ]; then falhou "esperado exatamente 1 construtor Dio( em lib/ (achados: $n_dio)"; fi
if [ "$n_dio" = "1" ] && ! echo "$dios" | grep -q '^lib/core/network/api_client.dart:'; then
  falhou "o único Dio( deveria estar em lib/core/network/api_client.dart"
fi

# 4.3 Authorization / Bearer montado fora do interceptor
auth="$(grep -rnE "Authorization|['\"]Bearer" lib --include='*.dart' \
        | grep -v '^lib/core/network/auth_interceptor.dart:' | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' || true)"
if [ -n "$auth" ]; then echo "$auth"; falhou "header Authorization montado fora do auth_interceptor"; fi

# 4.4 chave do token única; nada de SharedPreferences para o token
if grep -rn 'jwt_token' lib --include='*.dart'; then falhou "chave antiga jwt_token em lib/"; fi
if grep -rn 'SharedPreferences' lib --include='*.dart'; then falhou "SharedPreferences em lib/ (token só no secure storage)"; fi

# 4.5 AndroidManifest: INTERNET no main; cleartext só no debug e só para hosts locais
MAIN_MANIFEST=android/app/src/main/AndroidManifest.xml
grep -q 'android.permission.INTERNET' "$MAIN_MANIFEST" || falhou "INTERNET ausente no AndroidManifest do main"
if grep -qE 'usesCleartextTraffic="true"|networkSecurityConfig' "$MAIN_MANIFEST"; then
  falhou "cleartext/networkSecurityConfig no AndroidManifest do main (release)"
fi
[ -f android/app/src/main/res/xml/network_security_config.xml ] && falhou "network_security_config no main (deve ser só debug)"
NSC=android/app/src/debug/res/xml/network_security_config.xml
if [ -f "$NSC" ]; then
  grep -q '<base-config' "$NSC" && falhou "cleartext global (base-config) no debug"
  extra="$(grep -oE '<domain[^>]*>[^<]+</domain>' "$NSC" | sed -E 's/<[^>]+>//g' | tr -d ' ' \
           | grep -vxE '10\.0\.2\.2|localhost|127\.0\.0\.1' || true)"
  [ -n "$extra" ] && falhou "cleartext liberado para host não local: $extra"
fi

# 4.6 segredos versionados no app
if git ls-files | grep -E '(^|/)\.env$|\.jks$|\.keystore$|key\.properties$|\.pem$|\.p12$'; then
  falhou "arquivo sensível versionado no app"
fi
if git ls-files -z | xargs -0 grep -lIE 'BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,}' 2>/dev/null; then
  falhou "chave privada/token em arquivo versionado do app"
fi
if grep -rnE "(secret|senha|password)[A-Za-z_]*[[:space:]]*=[[:space:]]*['\"][^'\"]{6,}['\"]" lib --include='*.dart'; then
  falhou "possível segredo literal em lib/"
fi

# 4.7 backend: .env.example sem valores de segredo e .env fora do git
if [ -f "$BACKEND/.env.example" ] && grep -nE '^(SECURITY_JWT_SECRET_KEY|ADMIN_SENHA|ADMIN_CPF)=.+' "$BACKEND/.env.example"; then
  falhou ".env.example do backend contém valor de segredo"
fi
if (cd "$BACKEND" && git ls-files | grep -E '(^|/)\.env$'); then falhou ".env versionado no backend"; fi

# ---------------------------------------------------------------- 5. backend: ./mvnw -B clean test
etapa "./mvnw -B clean test (backend)"
cd "$BACKEND" || exit 2
if ! ./mvnw -B clean test; then
  falhou "./mvnw -B clean test"
fi

# ---------------------------------------------------------------- 6. sobe o backend e roda os testes de contrato
etapa "Testes de contrato (backend real na porta $PORTA)"
if [ -n "$(pids_na_porta)" ]; then
  falhou "porta $PORTA já ocupada antes de subir o backend (PIDs: $(pids_na_porta | tr '\n' ' '))"
elif ! ./mvnw -B -q -DskipTests package; then
  falhou "./mvnw package (jar para subir o backend)"
else
  JAR="$(ls target/*.jar 2>/dev/null | grep -v '\.original$' | head -1)"
  if [ -z "$JAR" ]; then
    falhou "jar do backend não encontrado em target/"
  else
    # Segredos SÓ de teste, gerados aqui (nunca em arquivo versionado).
    if command -v openssl >/dev/null 2>&1; then
      SECURITY_JWT_SECRET_KEY="$(openssl rand -base64 48 | tr -d '\r\n')"
    else
      SECURITY_JWT_SECRET_KEY="$(head -c 48 /dev/urandom | base64 | tr -d '\r\n')"
    fi
    DB_FILE="target/gate-contract-$$-$RANDOM.db"
    LOG_BACKEND="target/gate-backend.log"
    export SECURITY_JWT_SECRET_KEY
    export SPRING_DATASOURCE_URL="jdbc:sqlite:$DB_FILE"
    export RATE_LIMIT_LIMITE=100000
    export ADMIN_CPF=11144477735
    export ADMIN_SENHA="Gate$RANDOM$RANDOM"a1
    export ADMIN_EMAIL=admin.gate@teste.local
    export CORS_ALLOWED_ORIGINS=http://localhost:4200
    export SERVER_PORT=$PORTA
    "$JAVA" -jar "$JAR" > "$LOG_BACKEND" 2>&1 &
    BACK_PID=$!
    echo "backend PID $BACK_PID (log: $BACKEND/$LOG_BACKEND)"

    ok=0
    for _ in $(seq 1 120); do
      if ! kill -0 "$BACK_PID" 2>/dev/null; then break; fi
      code="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORTA/api/api-docs" 2>/dev/null || true)"
      if [ "$code" = "200" ]; then ok=1; break; fi
      sleep 1
    done
    unset SECURITY_JWT_SECRET_KEY ADMIN_SENHA

    if [ "$ok" != "1" ]; then
      tail -40 "$LOG_BACKEND" >&2
      falhou "backend não respondeu 200 em /api/api-docs em 120s"
    else
      echo "backend no ar."
      cd "$APP" || exit 2
      contrato_out="$(API_BASE_URL="http://localhost:$PORTA/api" flutter test --no-pub --tags contract --reporter expanded 2>&1)"
      contrato_rc=$?
      echo "$contrato_out" | tail -25
      if [ "$contrato_rc" -ne 0 ]; then
        falhou "flutter test --tags contract"
      elif echo "$contrato_out" | grep -qE ' ~[0-9]+' || ! echo "$contrato_out" | grep -qE '\+[1-9][0-9]*'; then
        falhou "testes de contrato foram pulados (API_BASE_URL não chegou ao teste?)"
      fi
      # o backend não pode ter registrado o token/senha em log
      if grep -nE 'Bearer [A-Za-z0-9_-]+\.|"senha"[[:space:]]*:' "$BACKEND/$LOG_BACKEND"; then
        falhou "log do backend contém token ou senha"
      fi
      cd "$BACKEND" || exit 2
    fi
  fi
fi

# ---------------------------------------------------------------- 7. derruba o backend e confere a porta
etapa "Derrubando o backend"
derrubar_backend
if [ -n "$(pids_na_porta)" ]; then
  falhou "porta $PORTA continua ocupada depois de derrubar o backend"
else
  echo "porta $PORTA livre."
fi

echo
if [ "$falhas" -ne 0 ]; then
  echo "GATE: FALHOU ($falhas problema(s))"
  exit 1
fi
echo "GATE: PASSOU"
exit 0
