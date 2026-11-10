#!/usr/bin/env bash
# Gate da FASE 6 (exportar o faturamento em CSV no celular; app Flutter; backend INTOCADO).
# Roda sem interação e sai 0 só se TUDO passar.
# Uso:  GATE_PORTA=18080 bash .loop/gate.sh   (GATE_PORTA padrão 8080; a 8080 costuma ser do backend da IDE do
#       usuário: nunca usar/derrubar). Caminhos resolvidos a partir da pasta do script (.loop/.. = raiz do app;
#       ../cortecerto-backend-loop = backend): pode ser chamado de qualquer diretório.
#
# Parte do gate final da FASE 5 (fases/resultado-5/gate.frozen.sh) e mantém TODAS as etapas. FASE 6 (TAREFA.md,
# "Gate desta fase", + contexto.md e decisão do usuário registrada no fim do .loop/dev.md):
#   - flutter pub get --offline (nada de requisição externa; antes era online);
#   - flutter test: total >= 573 (519 da FASE 5 + 36 do developer + 18 do tester da FASE 6, volta 1);
#     >= 285 fora de test/fase4, test/fase5, test/fase6 e test/a11y; mínimos por arquivo das FASES 4 e 5 iguais
#     aos do gate da FASE 5; mínimos por arquivo de test/fase6 = contagem da volta 1 (só podem crescer);
#   - 4.16 revista: base ca97ac2 (HEAD do app no início da FASE 6); lib/ só em lib/features/admin/**, lib/core/**
#     e lib/app.dart; fora de lib/, nas pastas nativas (android/ios/windows/macos/linux/web) só
#     android/settings.gradle.kts (AGP exigido pelo share_plus); rotas.dart, app_router.dart e
#     admin_agendamento_api.dart só com acréscimos;
#   - 5.a revista: em dependencies, contra ca97ac2, só share_plus acrescentado e flutter_secure_storage ^9.0.0 ->
#     ^10.3.1 (decisão do usuário, dev.md); dev_dependencies idênticas; sem dependency_overrides; sem path_provider;
#   - 6.x novas: share_plus importado em exatamente 1 arquivo de lib/ (a implementação do ExportadorArquivo, fora
#     de presentation/); CSV puro (sem flutter/BuildContext/dart:io/double/NumberFormat); exportador registrado em
#     lib/app.dart; manifesto do app intocado; AGP >= 8.12.1;
#   - backend volta a ser INTOCADO: HEAD == b6d1fe0 (.loop/backend-head-inicial.txt, e o arquivo tem que dizer
#     b6d1fe0) e git status --porcelain vazio, conferidos DEPOIS do mvnw/jar/contrato; ./mvnw -B clean test >= 265;
#     contrato com backend real (>= 4 testes, todos rodando);
#   - 9. flutter build apk --debug --no-pub: tem que gerar o APK agora e o manifesto mesclado tem o
#     ShareFileProvider do share_plus e nenhuma permissão de armazenamento.
#
# ---- texto original do gate da FASE 5 (mantido como referência) ----
# Gate da FASE 5 (Faturamento do admin + grade de horários uniforme; app Flutter + backend EDITÁVEL).
# Roda sem interação e sai 0 só se TUDO passar.
# Uso:  GATE_PORTA=18080 bash .loop/gate.sh   (GATE_PORTA padrão 8080; a 8080 costuma ser do backend da IDE)
#
# Parte do gate final da FASE 4 (fases/resultado-4/gate.sh = gate.frozen.sh da FASE 4 + ajustes das voltas 2-5,
# que trouxeram os mínimos 454 / 285 / 57 / 48 citados na TAREFA) e mantém TODAS as etapas. FASE 5:
#   - flutter test: total >= 519 (contagem da FASE 5 volta 1, tester: 454 FASE 4 + 55 do developer + 10 do tester);
#     >= 285 fora de test/fase4, test/a11y e test/fase5; mínimos por arquivo da FASE 4 (a11y sobe para 67)
#     e da FASE 5 (test/fase5/*), todos = contagem da volta 1 (só podem crescer);
#   - 4.16 revista: lista de arquivos de lib/ permitidos na FASE 5 (diff contra a base da fase, ffeb405);
#     rotas.dart e app_router.dart só com linhas ACRESCENTADAS; status_agendamento.dart e
#     agenda_admin_controller.dart intocados; pubspec sem pacote novo e sem pacote de gráfico;
#     sem NumberFormat em lib/features (valores pelo Formatters);
#   - backend: sem double/float no conversor e no FaturamentoService; V6 presente;
#     ./mvnw -B clean test com contagem (>= 265 = 217 FASE 4 + 44 developer + 4 tester; 0 falhas/erros/pulados)
#     e mínimos por classe de fase5/;
#   - contrato: banco SQLite temporário em target/ (NUNCA data/cortecerto.db: sha256 conferido antes/depois),
#     log do backend tem que mostrar a V6 aplicada no banco temporário; >= 4 testes de contrato;
#   - 8. backend: HEAD == .loop/backend-head-inicial.txt (7620220) e V1-V5 sem diff contra esse HEAD.
#
# ---- texto original do gate da FASE 4 (mantido como referência) ----
# Gate da FASE 4 (redesign de UI/UX; app Flutter + backend). Roda sem interação e sai 0 só se TUDO passar.
# Uso:  bash .loop/gate.sh   (os caminhos são resolvidos a partir da pasta do script: .loop/.. = raiz do app,
#        e ../cortecerto-backend-loop = backend; pode ser chamado de qualquer diretório)
#
# Parte do gate da FASE 3 (fases/resultado-3/gate.frozen.sh) e mantém TODAS as etapas e checagens dele.
# FASE 4 acrescenta:
#   - flutter test: falha se algum teste for pulado, se passarem menos que 450 no total ou 285 fora de test/fase4 e test/a11y (contexto.md 5.1)
#     ou se os arquivos de teste da FASE 4 (a11y, tema/contraste, widgets comuns, telas) não existirem/rodarem;
#   - checagens estáticas 4.11-4.17 (sem Color(0x/Colors./fontSize em lib/features, sem emoji em lib/,
#     IconButton com tooltip, arquivos de lib/ alterados só na lista permitida da TAREFA + decisão D1,
#     rotas.dart intocado, parte de domínio de status_agendamento.dart intocada);
#   - 8. (FASE 4; trocado na FASE 5) backend intocado: `git status --porcelain` igual a .loop/backend-status-inicial.txt e HEAD igual
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

# FASE 5: sha256 do banco de desenvolvimento do usuário, conferido no fim (o gate NUNCA usa esse arquivo)
USER_DB_SHA_ANTES="$( [ -f "$BACKEND/data/cortecerto.db" ] && sha256sum "$BACKEND/data/cortecerto.db" | cut -d' ' -f1 || echo ausente)"
echo "== data/cortecerto.db (usuário): sha256 ${USER_DB_SHA_ANTES:0:12}"

cd "$APP" || exit 2

# ---------------------------------------------------------------- 1. flutter pub get
etapa "flutter pub get --offline"
# FASE 6: --offline (TAREFA: nada de requisição externa; tudo já está no cache do pub)
pub_out="$(flutter pub get --offline 2>&1)"; pub_rc=$?
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
# FASE 5: idem para os testes da fase (tela, período, grade, API, rota, tester) e o contrato do faturamento
FASE5_TESTES="fase5/faturamento_page_test.dart:14 fase5/grade_horarios_test.dart:8 fase5/periodo_faturamento_test.dart:11 \
fase5/faturamento_api_test.dart:7 fase5/rota_faturamento_test.dart:5 fase5/faturamento_tester_test.dart:10"
for par in $FASE5_TESTES; do
  f="test/${par%%:*}"
  [ -f "$f" ] || falhou_det "flutter test (FASE 5)" "$f ausente" "arquivo presente" "ls $f"
done
# FASE 6: testes da fase (CSV e tela do developer; CSV e tela do tester). Mínimo = contagem da volta 1 (só cresce).
FASE6_TESTES="fase6/faturamento_csv_test.dart:24 fase6/faturamento_exportar_test.dart:12 \
fase6/faturamento_csv_tester_test.dart:8 fase6/faturamento_exportar_tester_test.dart:10"
for par in $FASE6_TESTES; do
  f="test/${par%%:*}"
  [ -f "$f" ] || falhou_det "flutter test (FASE 6)" "$f ausente" "arquivo presente" "ls $f"
done
[ -f test/contract/faturamento_contract_test.dart ] \
  || falhou_det "contrato (FASE 5)" "test/contract/faturamento_contract_test.dart ausente" "arquivo presente" "ls test/contract"
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
# baseline total: 454 = 285 (FASES 1-3, contexto.md 5.1) + 169 da FASE 4 (volta 2: 149; volta 3: +4 em telas_fase4_test;
# volta 4: +6 em telas_fase4_test e +6 em a11y/acessibilidade_test; volta 5: +2 em telas_fase4_test e +2 em a11y).
# Só pode crescer. (Review volta 1, achado 3: o mínimo 285 sobre o TOTAL deixava sumir 140 testes antigos.)
# FASE 5 volta 1 (tester): 519 = 454 da FASE 4 + 55 do developer (fase5: 14+8+11+7+5 = 45; a11y +10)
# + 10 do tester (fase5/faturamento_tester_test.dart). Só pode crescer.
# FASE 6 volta 1 (tester): 573 = 519 da FASE 5 + 36 do developer (fase6: CSV 24 + tela 12)
# + 18 do tester (fase6: CSV 8 + tela 10). Só pode crescer.
FT_MIN_TOTAL=573
if [ -z "${ft_pass:-}" ] || [ "${ft_pass:-0}" -lt "$FT_MIN_TOTAL" ]; then
  falhou_det "flutter test (contagem)" "${ft_pass:-desconhecido} passaram" ">= $FT_MIN_TOTAL (519 FASE 5 + 54 FASE 6 volta 1)" \
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
  # testes das FASES 1-3 = tudo fora de test/fase4 e test/a11y (contados pelo JSON, só os que passaram)
  # FASE 5: a pasta nova test/fase5 também fica de fora (os 285 antigos não podem ser "compensados" por testes novos)
  # FASE 6: test/fase6 também fica de fora
  n_antigos="$(printf '%s\n' "$ft_por_arquivo" | awk '$1 !~ /^(fase4|fase5|fase6|a11y)\// && $2 ~ /^[0-9]+$/ {s += $2} END {print s+0}')"
  echo "FASES 1-3 (fora de test/fase4, test/fase5, test/fase6 e test/a11y): passaram $n_antigos (mínimo 285)"
  if [ "${n_antigos:-0}" -lt 285 ]; then
    falhou_det "flutter test (FASES 1-3)" "$n_antigos passaram fora de test/fase4, test/fase5, test/fase6 e test/a11y" ">= 285 (baseline contexto.md 5.1)" \
      "flutter test --no-pub --exclude-tags contract --file-reporter json:.dart_tool/x.json"
  fi
  # mínimos por arquivo: volta 1 (43/42/22/33) + volta 2: a11y +6 (estado inicial e vazio real do Agendamento,
  # rolagem 0, título do mês sem ação, 2.0 nos dois estados); telas +3 (recuos da barra de Produtos e
  # barra de total de borda a borda em 360 e 800 dp); volta 3: telas +4 (resumo do Agendamento com a largura
  # do calendário em 360 e 800 dp, spaceBetween da barra de Produtos, EstadoErro dos horários do Form admin);
  # volta 4: telas +6 (ação à direita nos cards de Serviços e Meus em 800 dp; Form admin: retry dos serviços,
  # vazio de serviços, vazio de horários, carregando); a11y +6 (Form admin erroServicos/vazioServicos/vazioHorarios
  # nos guidelines e em 360x640 a 2.0); volta 5: telas +2 (busca de clientes do Form admin: EstadoErro + retry com o
  # texto do campo; retry usa o texto atual); a11y +2 (Form admin erroClientes nos guidelines e em 360x640 a 2.0).
  # FASE 5: a11y sobe de 57 para 67 (Faturamento entra em TelaF4.values nos grupos 4.1 e 4.2 = +2, e 4 estados
  # extras - vazio, erro, semana, mês - em 4.1 e 4.2 = +8). Os da FASE 4 que a FASE 5 não mexe ficam iguais.
  for par in a11y/acessibilidade_test.dart:67 fase4/tema_tokens_test.dart:42 fase4/widgets_comuns_test.dart:22 fase4/telas_fase4_test.dart:48 \
             $FASE5_TESTES $FASE6_TESTES; do
    arq="${par%%:*}"; min="${par##*:}"
    n="$(printf '%s\n' "$ft_por_arquivo" | awk -v a="$arq" '$1 == a {print $2}')"
    echo "por arquivo: $arq passaram ${n:-0} (mínimo $min)"
    if [ "${n:-0}" -lt "$min" ]; then
      falhou_det "flutter test ($arq)" "${n:-0} passaram" ">= $min (contagem da FASE 5 volta 1 / FASE 6 volta 1)" "flutter test --no-pub -r expanded test/$arq"
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

# 4.16 (revista na FASE 6) escopo: arquivos alterados/novos desde a BASE da fase (ca97ac2, HEAD do app no início da
#      FASE 6 - contexto.md; fixa para a checagem continuar valendo se o loop.sh fizer commit entre as voltas).
#      TAREFA "Gate desta fase": lib/ só em lib/features/admin/**, lib/core/** e lib/app.dart; configuração nativa
#      só a exigida pelo share_plus (android/settings.gradle.kts: AGP >= 8.12.1, dev.md item 5).
#      Documentação (TAREFA.md, fases/, .claude/) e test/, .loop/, pubspec.* ficam fora desta lista (pubspec: 5.a).
FASE6_BASE_APP=ca97ac2
if ! git cat-file -e "$FASE6_BASE_APP^{commit}" 2>/dev/null; then
  falhou_det "4.16 escopo de arquivos" "commit base $FASE6_BASE_APP não encontrado (medição ausente)" "commit presente" "git log --oneline -3 $FASE6_BASE_APP"
else
  alterados="$( { git diff --name-only "$FASE6_BASE_APP" -- lib/ android/ ios/ windows/ macos/ linux/ web/; \
                  git ls-files --others --exclude-standard -- lib/ android/ ios/ windows/ macos/ linux/ web/; } | sort -u)"
  fora=""
  for arq in $alterados; do
    case "$arq" in
      lib/features/admin/*) ;;
      lib/core/*) ;;
      lib/app.dart) ;;
      android/settings.gradle.kts) ;;
      # registrants de plugin GERADOS pelo `flutter pub get` a partir do pubspec (share_plus entra e
      # flutter_secure_storage_macos vira _darwin); não são editados à mão. Conteúdo conferido em 6.f.
      linux/flutter/generated_plugin_registrant.cc|linux/flutter/generated_plugins.cmake) ;;
      windows/flutter/generated_plugin_registrant.cc|windows/flutter/generated_plugins.cmake) ;;
      macos/Flutter/GeneratedPluginRegistrant.swift) ;;
      *) fora="$fora $arq" ;;
    esac
  done
  echo "arquivos de lib/ e pastas nativas alterados desde $FASE6_BASE_APP: $(printf '%s\n' "$alterados" | grep -c .)"
  printf '%s\n' "$alterados" | sed 's/^/   /'
  if [ -n "$fora" ]; then falhou_det "4.16 escopo de arquivos" "fora da lista:$fora" \
    "só lib/features/admin/**, lib/core/**, lib/app.dart e android/settings.gradle.kts (TAREFA, Gate desta fase)" \
    "git diff --name-only $FASE6_BASE_APP -- lib/ android/ ios/; git ls-files --others --exclude-standard -- lib/ android/"; fi
  # rotas.dart, app_router.dart e admin_agendamento_api.dart: só ACRÉSCIMOS (nada existente removido ou alterado)
  for arq in lib/core/router/rotas.dart lib/core/router/app_router.dart lib/features/admin/data/admin_agendamento_api.dart; do
    rem="$(git diff -U0 "$FASE6_BASE_APP" -- "$arq" | tr -d '\r' | grep -E '^-' | grep -vE '^--- ' || true)"
    if [ -n "$rem" ]; then echo "$rem"; falhou_det "4.16 $arq" "$(printf '%s\n' "$rem" | grep -c .) linha(s) removida(s)/alterada(s)" "só linhas acrescentadas" "git diff $FASE6_BASE_APP -- $arq"; fi
  done
  # a rota continua debaixo de /admin (bloqueio de /admin/** para CLIENTE)
  grep -qE "adminFaturamento = '/admin/faturamento';" lib/core/router/rotas.dart \
    || falhou_det "4.16 rota do faturamento" "adminFaturamento fora de '/admin/faturamento'" "/admin/faturamento" "grep -n adminFaturamento lib/core/router/rotas.dart"
  # 6.d manifesto do app intocado (o share_plus traz o FileProvider no manifesto dele; nada de permissão nova)
  if [ -n "$(git diff --name-only "$FASE6_BASE_APP" -- android/app/src)" ]; then
    falhou_det "6.d AndroidManifest/res do app" "alterado desde $FASE6_BASE_APP" "intocado (contexto.md: nenhuma permissão nem provider manual)" "git diff $FASE6_BASE_APP -- android/app/src"
  fi
fi
# 4.17 status_agendamento.dart (domínio dos status): na FASE 5 não muda nada (fora da lista acima) e as entradas
#      do enum continuam com os valores da API.
for padrao in "pendente('PENDENTE', 'Pendente')" "confirmado('CONFIRMADO', 'Confirmado')" "cancelado('CANCELADO', 'Cancelado')" \
              "realizado('REALIZADO', 'Realizado')" "desconhecido('DESCONHECIDO', 'Desconhecido')"; do
  grep -qF "$padrao" lib/features/agendamento/domain/status_agendamento.dart \
    || falhou_det "4.17 status_agendamento.dart" "entrada do enum ausente: $padrao" "valores de API/rótulo mantidos" "grep -n PENDENTE lib/features/agendamento/domain/status_agendamento.dart"
done

# ---------------------------------------------------------------- 4c. checagens estáticas da FASE 5 (app)
etapa "Checagens estáticas da FASE 5 (app)"
# 5.a (revista na FASE 6) dependências: contra ca97ac2, em dependencies só share_plus acrescentado (único pacote novo
#     permitido) e flutter_secure_storage ^9.0.0 -> ^10.3.1 (conflito de win32 com o share_plus; decisão do usuário
#     registrada no fim do .loop/dev.md). dev_dependencies idênticas, sem dependency_overrides, sem path_provider
#     (dev.md: não é necessário), nenhum pacote de gráfico.
# secao <texto do pubspec> <nome>: linhas da seção de topo, sem comentários/brancos, espaços normalizados, ordenadas
secao() {
  printf '%s\n' "$1" | tr -d '\r' | awk -v s="$2:" '
    /^[^[:space:]#][^:]*:/ { dentro = ($1 == s) ; next }
    dentro { sub(/[[:space:]]+#.*$/, ""); if ($0 ~ /^[[:space:]]*(#|$)/) next; gsub(/[[:space:]]+/, " "); sub(/^ /, ""); print }' | sort
}
pub_base="$(git show "$FASE6_BASE_APP:pubspec.yaml" 2>/dev/null || true)"
if [ -z "$pub_base" ]; then
  falhou_det "5.a pubspec.yaml" "pubspec.yaml de $FASE6_BASE_APP ilegível (medição ausente)" "conteúdo da base" "git show $FASE6_BASE_APP:pubspec.yaml"
else
  pub_atual="$(cat pubspec.yaml)"
  dep_base="$(secao "$pub_base" dependencies)"
  dep_atual="$(secao "$pub_atual" dependencies)"
  dep_esperado="$( { printf '%s\n' "$dep_base" | sed -E 's/^flutter_secure_storage: \^9\.0\.0$/flutter_secure_storage: ^10.3.1/'; \
                     echo 'share_plus: ^13.3.1'; } | sort)"
  if ! printf '%s\n' "$dep_base" | grep -qx 'flutter_secure_storage: ^9.0.0'; then
    falhou_det "5.a pubspec.yaml" "base sem 'flutter_secure_storage: ^9.0.0' (parser da seção falhou?)" "linha presente na base" "git show $FASE6_BASE_APP:pubspec.yaml"
  elif [ "$dep_atual" != "$dep_esperado" ]; then
    diff <(printf '%s\n' "$dep_esperado") <(printf '%s\n' "$dep_atual") | sed 's/^/   /'
    falhou_det "5.a dependencies" "diferente do permitido (diff acima: < esperado, > atual)" \
      "base + 'share_plus: ^13.3.1' e flutter_secure_storage ^10.3.1, nada mais" "git diff $FASE6_BASE_APP -- pubspec.yaml"
  else
    echo "dependencies: base + share_plus ^13.3.1, flutter_secure_storage ^10.3.1 (permitido)"
  fi
  if [ "$(secao "$pub_base" dev_dependencies)" != "$(secao "$pub_atual" dev_dependencies)" ] || [ -z "$(secao "$pub_atual" dev_dependencies)" ]; then
    falhou_det "5.a dev_dependencies" "alteradas desde $FASE6_BASE_APP (ou ilegíveis)" "idênticas" "git diff $FASE6_BASE_APP -- pubspec.yaml"
  fi
  if printf '%s\n' "$pub_atual" | grep -qE '^dependency_overrides:'; then
    falhou_det "5.a dependency_overrides" "presente" "ausente (dev.md descartou forçar win32)" "grep -n -A5 dependency_overrides pubspec.yaml"
  fi
  if printf '%s\n' "$pub_atual" | grep -qE '^[[:space:]]+path_provider[[:space:]]*:'; then
    falhou_det "5.a path_provider" "declarado no pubspec" "ausente (dev.md: XFile.fromData dispensa)" "grep -n path_provider pubspec.yaml"
  fi
fi
# pubspec.lock coerente com o pubspec (share_plus resolvido)
grep -qE '^  share_plus:' pubspec.lock || falhou_det "5.a pubspec.lock" "share_plus ausente do lock" "share_plus resolvido" "grep -n share_plus pubspec.lock"
graf="$(grep -nE '^[[:space:]]+(fl_chart|charts_flutter|syncfusion_flutter_charts|graphic|community_charts_flutter|mp_chart|chart_sparkline)[[:space:]]*:' pubspec.yaml || true)"
if [ -n "$graf" ]; then echo "$graf"; falhou_det "5.a pacote de gráfico" "$graf" "nenhum (barra feita com widgets do tema)" "grep -n chart pubspec.yaml"; fi
# 5.b valores em R$ só pelo Formatters (nada de NumberFormat solto em lib/features)
nf="$(grep -rn 'NumberFormat' lib/features --include='*.dart' || true)"
if [ -n "$nf" ]; then echo "$nf"; falhou_det "5.b NumberFormat em lib/features" "$(printf '%s\n' "$nf" | grep -c .) ocorrência(s)" "0 (usar Formatters.moeda)" "grep -rn NumberFormat lib/features"; fi
grep -q 'Formatters.moeda' lib/features/admin/presentation/faturamento_page.dart \
  || falhou_det "5.b Formatters" "faturamento_page.dart não usa Formatters.moeda" "valores formatados pelo Formatters existente" "grep -n Formatters lib/features/admin/presentation/faturamento_page.dart"
# 5.c a tela Faturamento busca sempre no servidor: nenhum cache (Map/lista de respostas por período) no controller
if grep -nE '_cache|cache\[|Map<PeriodoFaturamento' lib/features/admin/presentation/faturamento_controller.dart; then
  falhou_det "5.c cache no FaturamentoController" "estrutura de cache encontrada" "sem cache (TAREFA 3)" "grep -n cache lib/features/admin/presentation/faturamento_controller.dart"
fi
unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0

# ---------------------------------------------------------------- 4e. checagens estáticas da FASE 6 (app)
etapa "Checagens estáticas da FASE 6 (app)"
# 6.a share_plus importado em exatamente 1 arquivo de lib/ (a implementação real do ExportadorArquivo), nunca na
#     página nem em presentation/ (TAREFA 2: "Nada de chamar share_plus direto da página").
sp="$(grep -rlE "package:share_plus/" lib --include='*.dart' | tr '\\' '/' | sort || true)"
n_sp="$(printf '%s' "$sp" | grep -c . || true)"
echo "arquivos de lib/ que importam share_plus: $n_sp ${sp:+($sp)}"
if [ "$n_sp" != "1" ]; then
  falhou_det "6.a share_plus" "$n_sp arquivo(s): $sp" "exatamente 1 (a implementação real do exportador)" "grep -rln package:share_plus lib"
else
  case "$sp" in
    */presentation/*) falhou_det "6.a share_plus" "importado em $sp" "fora de presentation/" "grep -rln package:share_plus lib" ;;
  esac
  grep -qE '(extends|implements)[[:space:]]+ExportadorArquivo' "$sp" \
    || falhou_det "6.a share_plus" "$sp não implementa ExportadorArquivo" "o único import é a implementação real" "grep -n ExportadorArquivo $sp"
fi
# 6.b CSV como função pura (TAREFA 1: sem widgets/BuildContext/I-O; valores sem ponto flutuante; contexto.md 1.1/1.7)
CSV_SRC=lib/features/admin/domain/faturamento_csv.dart
if [ ! -f "$CSV_SRC" ]; then
  falhou_det "6.b CSV" "$CSV_SRC ausente (medição ausente)" "arquivo presente" "ls lib/features/admin/domain"
else
  impuro="$(grep -nE "package:flutter/|BuildContext|dart:io|dart:ui|\bdouble\b|toStringAsFixed|NumberFormat|num\.parse|double\.parse|\.toDouble\(" "$CSV_SRC" | grep -vE '^[0-9]+:[[:space:]]*///?' || true)"
  if [ -n "$impuro" ]; then echo "$impuro"; falhou_det "6.b CSV puro" "dependência de UI/I-O ou ponto flutuante" "nenhuma" "grep -nE 'package:flutter/|BuildContext|dart:io|double|NumberFormat' $CSV_SRC"; fi
fi
# 6.c a página lê a abstração (não o pacote) e lib/app.dart registra o exportador no MultiProvider
PAGE_SRC=lib/features/admin/presentation/faturamento_page.dart
grep -q 'ExportadorArquivo' "$PAGE_SRC" \
  || falhou_det "6.c página" "faturamento_page.dart não usa ExportadorArquivo" "exportador injetado por Provider" "grep -n Exportador $PAGE_SRC"
grep -qE 'Provider<ExportadorArquivo>' lib/app.dart \
  || falhou_det "6.c lib/app.dart" "Provider<ExportadorArquivo> ausente" "exportador real registrado na composição" "grep -n Exportador lib/app.dart"
grep -qF "tooltip: 'Exportar CSV'" "$PAGE_SRC" \
  || falhou_det "6.c ação" "tooltip 'Exportar CSV' ausente" "IconButton com tooltip Exportar CSV" "grep -n Exportar $PAGE_SRC"
# 6.f registrants gerados coerentes com o pubspec (o pub get acima os regenera; se estiverem velhos, o build
#     desktop não teria o plugin). No Linux o share_plus é só Dart e entra pelo url_launcher_linux (dependência dele).
for par in "windows/flutter/generated_plugins.cmake:share_plus" "linux/flutter/generated_plugins.cmake:url_launcher_linux" \
           "macos/Flutter/GeneratedPluginRegistrant.swift:import share_plus"; do
  arq="${par%%:*}"; txt="${par#*:}"
  grep -qF "$txt" "$arq" 2>/dev/null \
    || falhou_det "6.f registrant gerado" "$arq sem '$txt'" "registrant regenerado pelo flutter pub get" "flutter pub get --offline; git diff -- $arq"
done
# 6.e AGP >= 8.12.1 (README do share_plus 13.3.1)
agp="$(grep -oE 'com\.android\.application"\) version "[0-9.]+"' android/settings.gradle.kts | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)"
if [ -z "$agp" ]; then
  falhou_det "6.e AGP" "versão não encontrada em android/settings.gradle.kts (medição ausente)" ">= 8.12.1" "grep -n com.android.application android/settings.gradle.kts"
elif [ "$(printf '%s\n8.12.1\n' "$agp" | sort -V | head -1)" != "8.12.1" ]; then
  falhou_det "6.e AGP" "$agp" ">= 8.12.1 (exigência do share_plus 13.3.1)" "grep -n com.android.application android/settings.gradle.kts"
else
  echo "AGP: $agp"
fi

# ---------------------------------------------------------------- 4d. checagens estáticas do backend (FASE 5)
etapa "Checagens estáticas do backend (FASE 5)"
BJ="$BACKEND/src/main/java/br/com/ninodev/cortecerto"
MIG="$BACKEND/src/main/resources/db/migration"
# critério 1.1: V6 nova (exatamente uma V6) e nenhuma V7+ inesperada
v6="$(ls "$MIG"/V6__*.sql 2>/dev/null | wc -l | tr -d ' ')"
[ "$v6" = "1" ] || falhou_det "1.1 migration V6" "$v6 arquivo(s) V6__*.sql" "exatamente 1" "ls $MIG"
# critério 1.5: conversor e agregação sem ponto flutuante (contexto.md 1.8)
for arq in "$BJ/util/PrecoUtils.java" "$BJ/service/FaturamentoService.java"; do
  if [ ! -f "$arq" ]; then
    falhou_det "1.5 sem ponto flutuante" "$arq ausente (medição ausente)" "arquivo presente" "ls $BJ/util $BJ/service"
  elif grep -nE '\b(double|Double|float|Float)\b' "$arq"; then
    falhou_det "1.5 sem ponto flutuante" "double/float em $(basename "$arq")" "BigDecimal/long" "grep -nE 'double|Double|float|Float' $arq"
  fi
done
# V6 sem CAST AS REAL (preenchimento só por texto/inteiro)
# (linhas de comentário SQL "--" são ignoradas: o cabeçalho da V6 cita "nada de CAST AS REAL")
if sed -E 's/--.*$//' "$MIG"/V6__*.sql 2>/dev/null | grep -niE 'AS[[:space:]]+(REAL|FLOAT|DOUBLE|NUMERIC)'; then
  falhou_det "1.1 V6" "CAST para ponto flutuante na V6" "só INTEGER" "grep -niE 'AS (REAL|FLOAT)' $MIG/V6__*.sql"
fi
# critério 2: DTOs do faturamento sem campos de cliente (dados pessoais)
pess="$(grep -hniE 'cliente|cpf|telefone|email' "$BJ"/dto/Faturamento*DTO.java 2>/dev/null | grep -vE '^[0-9]+:[[:space:]]*(\*|//|/\*)' || true)"
if [ -n "$pess" ]; then echo "$pess"; falhou_det "2 dados pessoais" "campo de cliente nos DTOs do faturamento" "nenhum" "grep -niE 'cliente|cpf|telefone|email' $BJ/dto/Faturamento*DTO.java"; fi
[ -n "$(ls "$BJ"/dto/Faturamento*DTO.java 2>/dev/null)" ] || falhou_det "2 DTOs do faturamento" "ausentes (medição ausente)" "dto/Faturamento*DTO.java" "ls $BJ/dto"

# ---------------------------------------------------------------- 5. backend: ./mvnw -B clean test
etapa "./mvnw -B clean test (backend)"
cd "$BACKEND" || exit 2
mvn_out="$(./mvnw -B clean test 2>&1)"; mvn_rc=$?
echo "$mvn_out" | grep -aE 'Tests run:|ERROR|FAIL' | tail -30
if [ "$mvn_rc" -ne 0 ]; then
  falhou_det "./mvnw -B clean test" "código $mvn_rc" "código 0" "cd \"$BACKEND\" && ./mvnw -B clean test"
fi
# contagem pelos relatórios do surefire (gerados agora: o clean apagou os antigos)
if ! ls target/surefire-reports/TEST-*.xml >/dev/null 2>&1; then
  falhou_det "backend (contagem)" "sem relatórios do surefire (medição ausente)" "target/surefire-reports/TEST-*.xml" "cd \"$BACKEND\" && ./mvnw -B clean test"
else
  bt="$(cat target/surefire-reports/TEST-*.xml | grep -oE '<testsuite [^>]*>' | awk '
    { t=f=e=s=0
      if (match($0,/ tests="[0-9]+"/))    t=substr($0,RSTART+8,RLENGTH-9)
      if (match($0,/ failures="[0-9]+"/)) f=substr($0,RSTART+11,RLENGTH-12)
      if (match($0,/ errors="[0-9]+"/))   e=substr($0,RSTART+9,RLENGTH-10)
      if (match($0,/ skipped="[0-9]+"/))  s=substr($0,RSTART+10,RLENGTH-11)
      T+=t; F+=f; E+=e; S+=s }
    END { print T+0, F+0, E+0, S+0 }')"
  read -r b_tot b_fail b_err b_skip <<< "$bt"
  echo "backend: testes $b_tot, falhas $b_fail, erros $b_err, pulados $b_skip"
  # 265 = 217 (FASE 4) + 44 do developer (fase5: Faturamento 12, MigrationV6 4, PrecoUtils 20, ValorAgendamento 8)
  #       + 4 do tester (Fase5TesterIntegrationTest). Só pode crescer.
  if [ "${b_tot:-0}" -lt 265 ]; then
    falhou_det "backend (contagem)" "${b_tot:-0} testes" ">= 265 (217 FASE 4 + 48 FASE 5 volta 1)" "cd \"$BACKEND\" && ./mvnw -B clean test"
  fi
  if [ "${b_fail:-1}" != "0" ] || [ "${b_err:-1}" != "0" ] || [ "${b_skip:-1}" != "0" ]; then
    falhou_det "backend (falhas/pulados)" "falhas $b_fail, erros $b_err, pulados $b_skip" "0, 0, 0" "cd \"$BACKEND\" && ./mvnw -B clean test"
  fi
  for par in fase5.FaturamentoIntegrationTest:12 fase5.MigrationV6ValorCentavosTest:4 fase5.PrecoUtilsTest:20 \
             fase5.ValorAgendamentoIntegrationTest:8 fase5.Fase5TesterIntegrationTest:4 fase3.AgendamentoAdminIntegrationTest:18 \
             fase1.MigrationsFlywayTest:5; do
    cls="${par%%:*}"; min="${par##*:}"
    x="target/surefire-reports/TEST-br.com.ninodev.cortecerto.$cls.xml"
    n="$(grep -oE '<testsuite [^>]*>' "$x" 2>/dev/null | grep -oE ' tests="[0-9]+"' | grep -oE '[0-9]+')"
    nf="$(grep -oE '<testsuite [^>]*>' "$x" 2>/dev/null | grep -oE ' (failures|errors|skipped)="[1-9][0-9]*"' || true)"
    echo "backend por classe: $cls ${n:-0} (mínimo $min)"
    if [ "${n:-0}" -lt "$min" ] || [ -n "$nf" ]; then
      falhou_det "backend ($cls)" "${n:-0} testes ${nf}" ">= $min, sem falha/erro/pulado (contagem da FASE 5 volta 1)" \
        "cd \"$BACKEND\" && ./mvnw -B test -Dtest=$(echo "$cls" | sed 's/.*\.//')"
    fi
  done
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
      # FASE 5: + faturamento_contract_test.dart (1 teste) = 4 arquivos / 4 testes
      if [ "${n_arquivos:-0}" -lt 4 ] || [ "${esperados:-0}" -lt 4 ]; then
        falhou_det "contrato (quantidade)" "$esperados teste(s) em $n_arquivos arquivo(s)" ">= 4 em >= 4 (FASES 2, 3 e 5)" "ls test/contract"
      fi
      if ! echo "$contrato_out" | grep -qE '\+[0-9]+.*faturamento_contract_test\.dart: REALIZADO em recebido'; then
        falhou_det "contrato (FASE 5)" "teste do faturamento não rodou (não aparece na saída)" "faturamento_contract_test.dart rodou (e, pela contagem acima, passou)" \
          "API_BASE_URL=http://localhost:$PORTA/api ADMIN_CPF=... ADMIN_SENHA=... flutter test --tags contract test/contract/faturamento_contract_test.dart"
      fi
      # o banco usado foi o TEMPORÁRIO (com a V6 aplicada nele), nunca o data/cortecerto.db do usuário
      if [ ! -s "$BACKEND/$DB_FILE" ]; then
        falhou_det "contrato (banco temporário)" "$DB_FILE ausente ou vazio" "banco temporário criado pelo backend" "ls -la $BACKEND/target/*.db"
      fi
      if ! grep -qE 'Migrating schema .* to version "?6' "$BACKEND/$LOG_BACKEND"; then
        falhou_det "contrato (V6 no banco temporário)" "log sem 'Migrating ... to version 6'" "V6 aplicada no banco novo" "grep -n Migrating $BACKEND/$LOG_BACKEND"
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

# ---------------------------------------------------------------- 8. (FASE 6) backend INTOCADO
# TAREFA "Gate desta fase": HEAD igual a b6d1fe0 e git status --porcelain vazio no backend. Conferido DEPOIS do
# mvnw/jar/contrato (target/ é ignorado pelo git do backend). O hash vem de .loop/backend-head-inicial.txt e o
# arquivo tem que dizer b6d1fe0 (não dá para "acertar" o gate trocando o arquivo).
etapa "Backend: HEAD igual a b6d1fe0 e working tree limpo"
cd "$APP" || exit 2
BACKEND_HEAD_FASE6=b6d1fe0
HEAD_INI_F="$APP/.loop/backend-head-inicial.txt"
if [ ! -s "$HEAD_INI_F" ]; then
  falhou_det "8. backend HEAD" ".loop/backend-head-inicial.txt ausente/vazio (medição ausente)" "arquivo com $BACKEND_HEAD_FASE6" "ls .loop/"
else
  head_ini="$(tr -d '\r\n[:space:]' < "$HEAD_INI_F")"
  if [ "${head_ini:0:7}" != "$BACKEND_HEAD_FASE6" ]; then
    falhou_det "8. backend HEAD" ".loop/backend-head-inicial.txt diz '$head_ini'" "$BACKEND_HEAD_FASE6 (TAREFA)" "cat .loop/backend-head-inicial.txt"
  fi
  back_head="$(git -C "$BACKEND" rev-parse HEAD 2>/dev/null || echo desconhecido)"
  ini_full="$(git -C "$BACKEND" rev-parse "$BACKEND_HEAD_FASE6^{commit}" 2>/dev/null || echo desconhecido-ini)"
  if [ "$back_head" != "$ini_full" ]; then
    falhou_det "8. backend HEAD" "$back_head" "$BACKEND_HEAD_FASE6 (nada de commit no backend)" "git -C \"$BACKEND\" log --oneline -3"
  else
    echo "HEAD do backend: ${back_head:0:7} (igual a $BACKEND_HEAD_FASE6)"
  fi
fi
back_porc="$(git -C "$BACKEND" status --porcelain 2>&1)"; rc_porc=$?
if [ "$rc_porc" -ne 0 ]; then
  falhou_det "8. backend status" "git status falhou: $back_porc (medição ausente)" "porcelain vazio" "git -C \"$BACKEND\" status --porcelain"
elif [ -n "$back_porc" ]; then
  printf '%s\n' "$back_porc" | head -20 | sed 's/^/   /'
  falhou_det "8. backend status" "$(printf '%s\n' "$back_porc" | grep -c .) arquivo(s) alterado(s)/novo(s)" "porcelain vazio (backend não editável na FASE 6)" "git -C \"$BACKEND\" status --porcelain"
else
  echo "backend: git status --porcelain vazio."
fi
# o banco de desenvolvimento do usuário (data/cortecerto.db) não pode ter sido tocado pelo gate
if [ -n "$USER_DB_SHA_ANTES" ]; then
  depois_sha="$( [ -f "$BACKEND/data/cortecerto.db" ] && sha256sum "$BACKEND/data/cortecerto.db" | cut -d' ' -f1 || echo ausente)"
  if [ "$depois_sha" != "$USER_DB_SHA_ANTES" ]; then
    falhou_det "8. data/cortecerto.db" "sha256 mudou durante o gate ($USER_DB_SHA_ANTES -> $depois_sha)" "intocado" "sha256sum \"$BACKEND/data/cortecerto.db\""
  else
    echo "data/cortecerto.db intocado (sha256 igual ao do início do gate)."
  fi
fi

# ---------------------------------------------------------------- 9. (FASE 6) build Android
# TAREFA 3: "o app compila (flutter build apk --debug ou equivalente verificado pelo gate/tester)". O APK tem que
# ser gerado AGORA (mais novo que o início desta etapa) e o manifesto mesclado tem que ter o FileProvider do
# share_plus e nenhuma permissão de armazenamento.
etapa "flutter build apk --debug"
cd "$APP" || exit 2
APK=build/app/outputs/flutter-apk/app-debug.apk
MARCA=".dart_tool/gate-apk-$$.marca"
falhas_antes_apk=$falhas
: > "$MARCA"
sleep 1
apk_out="$(flutter build apk --debug --no-pub 2>&1)"; apk_rc=$?
echo "$apk_out" | grep -vE '^\s*$' | tail -6
if [ "$apk_rc" -ne 0 ]; then
  falhou_det "9. build apk" "código $apk_rc" "código 0 e 'Built $APK'" "flutter build apk --debug --no-pub"
elif [ ! -f "$APK" ] || [ ! "$APK" -nt "$MARCA" ]; then
  falhou_det "9. build apk" "$APK ausente ou antigo (não foi gerado agora)" "APK gerado nesta execução" "flutter build apk --debug --no-pub; ls -la $APK"
else
  echo "APK gerado: $APK ($(wc -c < "$APK" | tr -d ' ') bytes)"
  # o Gradle não regera o manifesto se as entradas não mudaram (build incremental): exige-se que ele seja mais
  # novo que o pubspec.lock e o settings.gradle.kts (ou seja, mesclado DEPOIS da entrada do share_plus/AGP).
  MERGED="$(find build/app/intermediates -path '*merged_manifest/debug/processDebugMainManifest*' -name AndroidManifest.xml 2>/dev/null | head -1)"
  if [ -z "$MERGED" ] || [ ! "$MERGED" -nt pubspec.lock ] || [ ! "$MERGED" -nt android/settings.gradle.kts ]; then
    falhou_det "9. manifesto mesclado" "não encontrado ou mais velho que pubspec.lock/settings.gradle.kts (medição ausente)" "build/app/intermediates/merged_manifest/debug/processDebugMainManifest/AndroidManifest.xml atualizado" "find build/app/intermediates -name AndroidManifest.xml"
  else
    grep -q 'dev.fluttercommunity.plus.share.ShareFileProvider' "$MERGED" \
      || falhou_det "9. manifesto mesclado" "sem ShareFileProvider do share_plus" "provider do plugin mesclado" "grep -n share $MERGED"
    if grep -nE 'permission\.(WRITE|READ|MANAGE)_EXTERNAL_STORAGE|READ_MEDIA_' "$MERGED"; then
      falhou_det "9. manifesto mesclado" "permissão de armazenamento" "nenhuma (o arquivo vai pelo cache do app)" "grep -n permission $MERGED"
    fi
    [ "$falhas" -eq "$falhas_antes_apk" ] && echo "manifesto mesclado: ShareFileProvider presente, sem permissão de armazenamento."
  fi
fi
rm -f "$MARCA"

echo
if [ "$falhas" -ne 0 ]; then
  echo "GATE: FALHOU ($falhas problema(s))"
  exit 1
fi
echo "GATE: PASSOU"
exit 0
