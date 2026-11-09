#!/usr/bin/env bash
# Gate da FASE 3 (app Flutter + backend). Roda sem interação e sai 0 só se TUDO passar.
# Uso (a partir da raiz do app Flutter):  bash .loop/gate.sh
#
# Parte do gate da FASE 2 (fases/resultado-2/gate.frozen.sh) e mantém TODAS as etapas e checagens dele.
# Etapas: Java 21 → flutter pub get → flutter analyze → flutter test (sem contract) →
#         checagens estáticas/segurança → ./mvnw -B clean test → sobe o backend (jar) com
#         variáveis de teste (JWT, ADMIN_CPF válido e ADMIN_SENHA aleatórios, gerados aqui) →
#         flutter test --tags contract (FASE 2 + FASE 3, com ADMIN_CPF/ADMIN_SENHA repassados) →
#         derruba o backend (trap EXIT) e confere a porta 8080 livre.
# FASE 3: nenhum teste de contrato pode ser pulado, e a quantidade que passou tem que ser igual à
#         quantidade de test() em test/contract/*_test.dart.
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND="$(cd "$APP/../cortecerto-backend-loop" 2>/dev/null && pwd || true)"
PORTA=8080

falhas=0
falhou() { echo "GATE FALHOU: $*" >&2; falhas=$((falhas + 1)); }
etapa() { echo; echo "================ $* ================"; }

# ---------------------------------------------------------------- utilitários (FASE 3)
# CPF de teste aleatório com dígitos verificadores válidos (nunca versionado).
gerar_cpf() {
  local i soma resto cpf
  local -a d
  while :; do
    d=()
    for i in 0 1 2 3 4 5 6 7 8; do d[i]=$((RANDOM % 10)); done
    soma=0; for i in 0 1 2 3 4 5 6 7 8; do soma=$((soma + d[i] * (10 - i))); done
    resto=$(((soma * 10) % 11)); [ "$resto" -eq 10 ] && resto=0; d[9]=$resto
    soma=0; for i in 0 1 2 3 4 5 6 7 8 9; do soma=$((soma + d[i] * (11 - i))); done
    resto=$(((soma * 10) % 11)); [ "$resto" -eq 10 ] && resto=0; d[10]=$resto
    cpf="$(printf '%s' "${d[@]}")"
    # descarta CPFs com todos os dígitos iguais
    if [ -n "$(printf '%s' "$cpf" | tr -d "${cpf:0:1}")" ]; then echo "$cpf"; return 0; fi
  done
}

# Senha aleatória: >= 8 caracteres, com letra e número (regra do AdminInitializer).
gerar_senha() {
  local base
  if command -v openssl >/dev/null 2>&1; then
    base="$(openssl rand -hex 12 | tr -d '\r\n')"
  else
    base="$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n\r')"
  fi
  echo "Gt${base}9z"
}

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
        | grep -iE 'token|senha|password|cpf|jwt|bearer|authorization|telefone' || true)"
if [ -n "$sens" ]; then echo "$sens"; falhou "print/debugPrint/log com token/senha/CPF/telefone em lib/"; fi
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

# 4.8 (FASE 3) credenciais de admin nunca fixas nos testes de contrato nem em lib/
if grep -rnE "(ADMIN_SENHA|ADMIN_CPF|adminSenha|adminCpf)[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]" test/contract lib --include='*.dart'; then
  falhou "credencial de admin fixa em test/contract ou lib/"
fi

# 4.9 (FASE 3) APIs novas só instanciadas em lib/app.dart (composição única)
novas="$(grep -rnE '(AdminAgendamentoApi|ClientesApi)[[:space:]]*\(' lib --include='*.dart' \
         | grep -v '^lib/app.dart:' \
         | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' \
         | grep -vE '(AdminAgendamentoApi|ClientesApi)\(ApiClient ' || true)"
if [ -n "$novas" ]; then echo "$novas"; falhou "AdminAgendamentoApi/ClientesApi instanciadas fora de lib/app.dart"; fi

# 4.10 (FASE 3) o backend não registra telefone/CPF em log
if grep -rnE 'log\.(info|warn|error|debug|trace)\(.*(elefone|[cC]pf)' "$BACKEND/src/main/java" 2>/dev/null; then
  falhou "backend registra telefone/CPF em log"
fi

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
    # Segredos SÓ de teste, gerados aqui (nunca em arquivo versionado). Não são exportados no shell do
    # gate: vão inline só para o processo do backend e, depois, só para o processo dos testes de contrato.
    if command -v openssl >/dev/null 2>&1; then
      GATE_JWT="$(openssl rand -base64 48 | tr -d '\r\n')"
    else
      GATE_JWT="$(head -c 48 /dev/urandom | base64 | tr -d '\r\n')"
    fi
    GATE_ADMIN_CPF="$(gerar_cpf)"
    GATE_ADMIN_SENHA="$(gerar_senha)"
    DB_FILE="target/gate-contract-$$-$RANDOM.db"
    LOG_BACKEND="target/gate-backend.log"
    echo "admin de teste: CPF válido gerado (final ${GATE_ADMIN_CPF:9:2}) e senha aleatória"
    SECURITY_JWT_SECRET_KEY="$GATE_JWT" \
    SPRING_DATASOURCE_URL="jdbc:sqlite:$DB_FILE" \
    RATE_LIMIT_LIMITE=100000 \
    ADMIN_CPF="$GATE_ADMIN_CPF" \
    ADMIN_SENHA="$GATE_ADMIN_SENHA" \
    ADMIN_EMAIL=admin.gate@teste.local \
    CORS_ALLOWED_ORIGINS=http://localhost:4200 \
    SERVER_PORT=$PORTA \
      "$JAVA" -jar "$JAR" > "$LOG_BACKEND" 2>&1 &
    BACK_PID=$!
    unset GATE_JWT
    echo "backend PID $BACK_PID (log: $BACKEND/$LOG_BACKEND)"

    ok=0
    for _ in $(seq 1 120); do
      if ! kill -0 "$BACK_PID" 2>/dev/null; then break; fi
      code="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORTA/api/api-docs" 2>/dev/null || true)"
      if [ "$code" = "200" ]; then ok=1; break; fi
      sleep 1
    done

    if [ "$ok" != "1" ]; then
      tail -40 "$LOG_BACKEND" >&2
      falhou "backend não respondeu 200 em /api/api-docs em 120s"
    else
      echo "backend no ar."
      cd "$APP" || exit 2
      # quantidade esperada: todo test() dos arquivos de contrato (FASE 2 + FASE 3)
      esperados="$(cat test/contract/*_test.dart | grep -cE '^[[:space:]]*test\(' || true)"
      n_arquivos="$(ls test/contract/*_test.dart 2>/dev/null | wc -l | tr -d ' ')"
      echo "testes de contrato esperados: $esperados (em $n_arquivos arquivos)"
      contrato_out="$(API_BASE_URL="http://localhost:$PORTA/api" ADMIN_CPF="$GATE_ADMIN_CPF" ADMIN_SENHA="$GATE_ADMIN_SENHA" \
                      flutter test --no-pub --tags contract --reporter expanded test/contract 2>&1)"
      contrato_rc=$?
      echo "$contrato_out" | tail -30
      ultima="$(echo "$contrato_out" | grep -oE '[0-9]+:[0-9]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?' | tail -1)"
      passaram="$(echo "$ultima" | grep -oE '\+[0-9]+' | tr -d '+')"
      echo "contrato: passaram ${passaram:-0} de $esperados"
      if [ "$contrato_rc" -ne 0 ]; then
        falhou "flutter test --tags contract"
      elif echo "$contrato_out" | grep -qE ' ~[0-9]+' || ! echo "$contrato_out" | grep -qE '\+[1-9][0-9]*'; then
        falhou "testes de contrato foram pulados (API_BASE_URL/ADMIN_* não chegaram ao teste?)"
      fi
      if [ "${n_arquivos:-0}" -lt 3 ] || [ "${esperados:-0}" -lt 3 ]; then
        falhou "esperados ao menos 3 testes de contrato (FASE 2 + FASE 3); achados $esperados em $n_arquivos arquivos"
      fi
      if [ "${passaram:-0}" != "$esperados" ]; then
        falhou "nem todos os testes de contrato rodaram e passaram (${passaram:-0} de $esperados)"
      fi
      # o backend não pode ter registrado o token/senha em log
      if grep -nE 'Bearer [A-Za-z0-9_-]+\.|"senha"[[:space:]]*:' "$BACKEND/$LOG_BACKEND"; then
        falhou "log do backend contém token ou senha"
      fi
      if grep -qF "$GATE_ADMIN_SENHA" "$BACKEND/$LOG_BACKEND"; then
        falhou "log do backend contém a senha do admin"
      fi
      if grep -qF "$GATE_ADMIN_CPF" "$BACKEND/$LOG_BACKEND"; then
        falhou "log do backend contém o CPF do admin"
      fi
      if echo "$contrato_out" | grep -qF "$GATE_ADMIN_SENHA"; then
        falhou "saída dos testes de contrato contém a senha do admin"
      fi
      cd "$BACKEND" || exit 2
    fi
    unset GATE_ADMIN_SENHA GATE_ADMIN_CPF
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
