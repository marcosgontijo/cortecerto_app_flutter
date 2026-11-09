#!/usr/bin/env bash
# Gate da FASE 4 (redesign de UI/UX; app Flutter + backend). Roda sem interação e sai 0 só se TUDO passar.
# Uso:  bash .loop/gate.sh   (os caminhos são resolvidos a partir da pasta do script: .loop/.. = raiz do app,
#        e ../cortecerto-backend-loop = backend; pode ser chamado de qualquer diretório)
#
# Parte do gate da FASE 3 (fases/resultado-3/gate.frozen.sh) e mantém TODAS as etapas e checagens dele.
# FASE 4 acrescenta:
#   - flutter test: falha se algum teste for pulado, se passarem menos que o baseline (285, contexto.md 5.1)
#     ou se os arquivos de teste da FASE 4 (a11y, tema/contraste, widgets comuns, telas) não existirem/rodarem;
#   - checagens estáticas 4.11-4.17 (sem Color(0x/Colors./fontSize em lib/features, sem emoji em lib/,
#     IconButton com tooltip, arquivos de lib/ alterados só na lista permitida da TAREFA + decisão D1,
#     rotas.dart intocado, parte de domínio de status_agendamento.dart intocada);
#   - 8. backend intocado: `git status --porcelain` igual a .loop/backend-status-inicial.txt e HEAD igual
#     ao do início da fase (7620220, contexto.md), conferido DEPOIS do mvnw/jar/contrato.
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
PORTA="${GATE_PORTA:-8080}"

falhas=0
falhou() { echo "GATE FALHOU: $*" >&2; falhas=$((falhas + 1)); }
# falhou_det <etapa> <obtido> <esperado> <comando para reproduzir>
falhou_det() {
  echo "GATE FALHOU [$1]" >&2
  echo "   obtido:     $2" >&2
  echo "   esperado:   $3" >&2
  echo "   reproduzir: $4" >&2
  falhas=$((falhas + 1))
}
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
# FASE 4: arquivos de teste que provam os critérios da fase (se sumirem, a medição está ausente = falha)
for f in test/a11y/acessibilidade_test.dart test/a11y/telas_harness.dart test/fase4/tema_tokens_test.dart \
         test/fase4/widgets_comuns_test.dart test/fase4/telas_fase4_test.dart; do
  [ -f "$f" ] || falhou_det "flutter test (FASE 4)" "$f ausente" "arquivo presente" "ls $f"
done
# caminho RELATIVO à raiz do app (cwd): o flutter no Windows não entende /tmp nem /c/...
FT_JSON=".dart_tool/gate-ft-$$.json"
ft_out="$(flutter test --no-pub --exclude-tags contract -r expanded --file-reporter "json:$FT_JSON" 2>&1)"; ft_rc=$?
echo "$ft_out" | grep -E '\[E\]$|^[[:space:]]*(Expected|Actual|Which):' | head -40
echo "$ft_out" | tail -3
ft_ultima="$(echo "$ft_out" | grep -oE '[0-9]+:[0-9]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?' | tail -1)"
ft_pass="$(echo "$ft_ultima" | grep -oE '\+[0-9]+' | tr -d '+')"
ft_skip="$(echo "$ft_ultima" | grep -oE '~[0-9]+' | tr -d '~')"
ft_fail="$(echo "$ft_ultima" | grep -oE ' -[0-9]+' | tr -d ' -')"
echo "flutter test: passaram ${ft_pass:-?}, pulados ${ft_skip:-0}, falharam ${ft_fail:-0} (código $ft_rc)"
if [ "$ft_rc" -ne 0 ]; then
  falhou_det "flutter test --exclude-tags contract" "código $ft_rc, ${ft_fail:-?} falha(s)" "código 0" \
    "flutter test --no-pub --exclude-tags contract -r expanded"
fi
if [ -n "${ft_skip:-}" ] && [ "${ft_skip:-0}" != "0" ]; then
  falhou_det "flutter test (pulados)" "$ft_skip pulado(s)" "0 pulados" "flutter test --no-pub --exclude-tags contract -r expanded"
fi
# baseline: 285 testes das FASES 1-3 (contexto.md, critério 5.1). Nenhum teste pode sumir.
if [ -z "${ft_pass:-}" ] || [ "${ft_pass:-0}" -lt 285 ]; then
  falhou_det "flutter test (contagem)" "${ft_pass:-desconhecido} passaram" ">= 285 (baseline FASES 1-3) + novos da FASE 4" \
    "flutter test --no-pub --exclude-tags contract"
fi
# os testes da FASE 4 têm que ter RODADO E PASSADO, por arquivo (contagem pelo reporter JSON; o reporter
# expanded não imprime todo teste). Mínimos = quantidade da FASE 4 volta 1 (tester); só podem crescer.
FT_CONTA=".dart_tool/gate-conta-$$.dart"
cat > "$FT_CONTA" <<'DART'
import 'dart:convert';
import 'dart:io';
void main(List<String> a) {
  final suites = <int, String>{}, testes = <int, int>{}, ok = <String, int>{};
  for (final l in File(a[0]).readAsLinesSync()) {
    if (!l.startsWith('{')) continue;
    final e = jsonDecode(l) as Map<String, dynamic>;
    switch (e['type']) {
      case 'suite':
        suites[e['suite']['id'] as int] = (e['suite']['path'] as String).replaceAll('\\', '/');
      case 'testStart':
        testes[e['test']['id'] as int] = e['test']['suiteID'] as int;
      case 'testDone':
        if (e['hidden'] == true || e['skipped'] == true || e['result'] != 'success') break;
        final k = (suites[testes[e['testID']]] ?? '?').split('/test/').last;
        ok[k] = (ok[k] ?? 0) + 1;
    }
  }
  ok.forEach((k, v) => print('$k $v'));
}
DART
ft_por_arquivo="$(dart "$FT_CONTA" "$FT_JSON" 2>&1)"; rc_conta=$?
rm -f "$FT_CONTA"
if [ "$rc_conta" -ne 0 ]; then
  falhou_det "flutter test (contagem por arquivo)" "não foi possível ler o JSON: $(printf '%s' "$ft_por_arquivo" | head -2)" \
    "contagem disponível" "flutter test --no-pub --exclude-tags contract --file-reporter json:/tmp/x.json"
else
  for par in a11y/acessibilidade_test.dart:43 fase4/tema_tokens_test.dart:42 fase4/widgets_comuns_test.dart:22 fase4/telas_fase4_test.dart:33; do
    arq="${par%%:*}"; min="${par##*:}"
    n="$(printf '%s\n' "$ft_por_arquivo" | awk -v a="$arq" '$1 == a {print $2}')"
    echo "FASE 4: $arq passaram ${n:-0} (mínimo $min)"
    if [ "${n:-0}" -lt "$min" ]; then
      falhou_det "flutter test (FASE 4: $arq)" "${n:-0} passaram" ">= $min (contagem da FASE 4 volta 1)" "flutter test --no-pub -r expanded test/$arq"
    fi
  done
fi
rm -f "$FT_JSON"


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

# ---------------------------------------------------------------- 4b. checagens estáticas da FASE 4
etapa "Checagens estáticas da FASE 4 (tema, emojis, escopo de arquivos)"
# silencia o aviso "LF will be replaced by CRLF" do git no Windows (não muda nada no repositório)
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.safecrlf GIT_CONFIG_VALUE_0=false

# 4.11 cor fixa em lib/features
c1="$(grep -rnE 'Color\(0x' lib/features --include='*.dart' || true)"
if [ -n "$c1" ]; then echo "$c1"; falhou_det "4.11 Color(0x em lib/features" "$(printf '%s\n' "$c1" | grep -c .) ocorrência(s)" "0" "grep -rnE 'Color\\(0x' lib/features"; fi
# 4.12 Colors.<x> (exceto transparent) em lib/features
c2="$(grep -rnoE 'Colors\.[A-Za-z0-9_]+' lib/features --include='*.dart' | grep -v 'Colors\.transparent$' || true)"
if [ -n "$c2" ]; then echo "$c2"; falhou_det "4.12 Colors. em lib/features" "$(printf '%s\n' "$c2" | grep -c .) ocorrência(s)" "0 (só Colors.transparent)" "grep -rnoE 'Colors\\.[A-Za-z0-9_]+' lib/features | grep -v transparent"; fi
# 4.13 fontSize solto em lib/features (TextStyle(fontSize:) pode estar em outra linha, por isso fontSize sozinho)
c3="$(grep -rnE 'fontSize' lib/features --include='*.dart' || true)"
if [ -n "$c3" ]; then echo "$c3"; falhou_det "4.13 fontSize em lib/features" "$(printf '%s\n' "$c3" | grep -c .) ocorrência(s)" "0 (usar Theme.of(context).textTheme)" "grep -rn fontSize lib/features"; fi
# 4.14 emojis em lib/ (inclusive comentários). grep -P precisa funcionar: se não funcionar, é falha (medição ausente).
if ! printf 'x\xe2\x9c\x82x\n' | grep -qP '[\x{2600}-\x{27BF}]' 2>/dev/null; then
  falhou_det "4.14 emoji" "grep -P sem suporte a Unicode neste ambiente" "grep -P funcionando" "printf 'x\\xe2\\x9c\\x82x' | grep -P '[\\x{2600}-\\x{27BF}]'"
else
  c4="$(grep -rnP '[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}\x{FE0F}]' lib --include='*.dart' || true)"
  if [ -n "$c4" ]; then echo "$c4"; falhou_det "4.14 emoji em lib/" "$(printf '%s\n' "$c4" | grep -c .) linha(s)" "0" "grep -rnP '[\\x{1F000}-\\x{1FAFF}\\x{2600}-\\x{27BF}\\x{2B00}-\\x{2BFF}\\x{FE0F}]' lib"; fi
fi
# 4.15 todo IconButton( em lib/ tem tooltip: nas 12 linhas seguintes (critério 4.3; o labeledTapTargetGuideline cobre em execução)
c5="$(grep -rnE 'IconButton(\.(filled|filledTonal|outlined))?\(' lib --include='*.dart' | while IFS=: read -r arq lin _; do
        sed -n "${lin},$((lin + 12))p" "$arq" | grep -q 'tooltip:' || echo "$arq:$lin"
      done)"
if [ -n "$c5" ]; then echo "$c5"; falhou_det "4.15 IconButton sem tooltip" "$c5" "todo IconButton com tooltip" "grep -rnE 'IconButton\\(' -A12 lib"; fi

# 4.16 escopo: arquivos de lib/ alterados/novos só na lista permitida da TAREFA (Restrições)
#      + decisão D1 do orquestrador: lib/core/agenda/** e a linha da grade em agenda_admin_controller.dart.
alterados="$( { git diff --name-only HEAD -- lib/; git ls-files --others --exclude-standard -- lib/; } | sort -u)"
fora=""
for arq in $alterados; do
  case "$arq" in
    lib/core/theme/*|lib/core/widgets/*|lib/core/agenda/*) ;;
    lib/features/*/presentation/*_page.dart) ;;
    lib/features/agendamento/domain/status_agendamento.dart) ;;
    lib/app.dart|lib/core/router/app_router.dart) ;;
    lib/features/admin/presentation/agenda_admin_controller.dart) ;;  # D1, conferido abaixo
    lib/features/*/presentation/*_controller.dart) fora="$fora $arq" ;;
    lib/features/*/presentation/*.dart)
      # widget de apresentação NOVO ao lado das páginas: permitido; arquivo existente alterado: não
      git ls-files --error-unmatch "$arq" >/dev/null 2>&1 && fora="$fora $arq" ;;
    *) fora="$fora $arq" ;;
  esac
done
if [ -n "$fora" ]; then falhou_det "4.16 escopo de arquivos" "fora da lista:$fora" "só theme/, widgets/, *_page.dart, status_agendamento.dart, app.dart/app_router.dart, core/agenda (D1)" "git diff --name-only HEAD -- lib/; git ls-files --others --exclude-standard -- lib/"; fi
# D1: no controller do admin só pode mudar o import da grade e a linha `grade = gerarGradeAtendimento();`
d1="$(git diff -U0 HEAD -- lib/features/admin/presentation/agenda_admin_controller.dart | grep -E '^[+-]' | grep -vE '^(\+\+\+|---) ' \
      | grep -vE "^\+import '\.\./\.\./\.\./core/agenda/grade_atendimento\.dart';$" \
      | grep -vE '^\+  static final List<String> grade = gerarGradeAtendimento\(\);$' \
      | grep -vE '^-  static final List<String> grade = \[$' \
      | grep -vE '^-    for \(var m = 8 \* 60; m <= 19 \* 60 \+ 30; m \+= 30\)$' \
      | grep -vE "^-      '\\$\{\(m ~/ 60\)\.toString\(\)\.padLeft\(2, '0'\)\}:\\$\{\(m % 60\)\.toString\(\)\.padLeft\(2, '0'\)\}',$" \
      | grep -vE '^-  \];$' | tr -d '\r' || true)"
if [ -n "$d1" ]; then echo "$d1"; falhou_det "4.16 D1 agenda_admin_controller.dart" "linhas além da grade alteradas" "só import + 'grade = gerarGradeAtendimento();'" "git diff HEAD -- lib/features/admin/presentation/agenda_admin_controller.dart"; fi
# rotas (paths) intocadas
if [ -n "$(git diff --name-only HEAD -- lib/core/router/rotas.dart)" ]; then
  falhou_det "4.16 rotas.dart" "alterado" "sem mudança" "git diff HEAD -- lib/core/router/rotas.dart"
fi
# 4.17 status_agendamento.dart: só a parte visual muda (nenhuma linha de lógica de domínio removida)
#      Toda linha NÃO visual da versão do HEAD (lógica: deApi, ocupaHorario, conhecidos, dataDaApi, intDaApi,
#      dataHora...) tem que continuar existindo, idêntica, no arquivo atual.
STATUS_F=lib/features/agendamento/domain/status_agendamento.dart
d2="$(git show "HEAD:$STATUS_F" 2>/dev/null | tr -d '\r' \
      | grep -vE '^\s*$|^\s*//|^import |Color|cor|TextStyle|padding|borderRadius|Container|decoration|child:|Widget|build|StatusChip|status\.|^\s*[])};,]+\s*$|^\s*(pendente|confirmado|cancelado|realizado|desconhecido)\(|const StatusAgendamento\(|@override|super\.key|final StatusAgendamento status;' \
      | while IFS= read -r l; do tr -d '\r' < "$STATUS_F" | grep -qxF -- "$l" || echo "removida/alterada: $l"; done)"
[ -n "$(git show "HEAD:$STATUS_F" 2>/dev/null | head -1)" ] || d2="versão do HEAD ilegível (medição ausente)"
if [ -n "$d2" ]; then echo "$d2"; falhou_det "4.17 status_agendamento.dart" "lógica de domínio removida/alterada" "só a parte visual (cor/ícone/chip)" "git diff HEAD -- lib/features/agendamento/domain/status_agendamento.dart"; fi
for padrao in "pendente('PENDENTE', 'Pendente')" "confirmado('CONFIRMADO', 'Confirmado')" "cancelado('CANCELADO', 'Cancelado')" \
              "realizado('REALIZADO', 'Realizado')" "desconhecido('DESCONHECIDO', 'Desconhecido')"; do
  grep -qF "$padrao" lib/features/agendamento/domain/status_agendamento.dart \
    || falhou_det "4.17 status_agendamento.dart" "entrada do enum ausente: $padrao" "valores de API/rótulo mantidos" "grep -n PENDENTE lib/features/agendamento/domain/status_agendamento.dart"
done
if grep -nE '\b(Color|Colors)\b' lib/features/agendamento/domain/status_agendamento.dart | grep -vE 'Color cor\(AppTokens|^[0-9]+:[[:space:]]*///' | grep -E 'Color\(0x|Colors\.|final Color'; then
  falhou_det "4.17 status_agendamento.dart" "Color fixa no enum" "cor vinda do tema (AppTokens)" "grep -nE 'Color' lib/features/agendamento/domain/status_agendamento.dart"
fi
unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0

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

# ---------------------------------------------------------------- 8. (FASE 4) backend não editado
etapa "Backend intocado (porcelain e HEAD iguais ao início da fase)"
cd "$APP" || exit 2
INICIAL="$APP/.loop/backend-status-inicial.txt"
if [ ! -f "$INICIAL" ]; then
  falhou_det "8. backend intocado" ".loop/backend-status-inicial.txt ausente" "arquivo com o porcelain do início da fase" "ls .loop/"
else
  atual="$(git -C "$BACKEND" status --porcelain 2>&1 | tr -d '\r')"; rc_git=$?
  esperado="$(tr -d '\r' < "$INICIAL")"
  if [ "$rc_git" -ne 0 ]; then
    falhou_det "8. backend intocado" "git status falhou: $atual" "git status ok" "git -C \"$BACKEND\" status --porcelain"
  elif [ "$atual" != "$esperado" ]; then
    echo "--- inicial"; echo "$esperado"; echo "--- atual"; echo "$atual"
    falhou_det "8. backend intocado" "porcelain diferente ($(printf '%s' "$atual" | grep -c .) linha(s))" \
      "igual a .loop/backend-status-inicial.txt ($(printf '%s' "$esperado" | grep -c .) linha(s))" "git -C \"$BACKEND\" status --porcelain"
  else
    echo "porcelain igual ao inicial ($(printf '%s' "$atual" | grep -c .) linha(s))."
  fi
fi
# HEAD do backend no início da FASE 4: 7620220 (contexto.md, seção Backend)
back_head="$(git -C "$BACKEND" rev-parse --short=7 HEAD 2>/dev/null || echo desconhecido)"
if [ "$back_head" != "7620220" ]; then
  falhou_det "8. backend HEAD" "$back_head" "7620220 (início da FASE 4)" "git -C \"$BACKEND\" log --oneline -3"
else
  echo "HEAD do backend: $back_head"
fi

echo
if [ "$falhas" -ne 0 ]; then
  echo "GATE: FALHOU ($falhas problema(s))"
  exit 1
fi
echo "GATE: PASSOU"
exit 0
