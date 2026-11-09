# CorteCerto — o que falta (retomar aqui)

> Atualizado em 08/11/2026. As 3 fases da migração web → mobile estão **entregues e no GitHub**.

## Onde paramos

| Fase | Entrega | Voltas |
|---|---|---|
| 1 | Backend seguro (BCrypt, JWT, validações, permissões, PII) e sem agendamento duplicado | 2 |
| 2 | Base do app (ApiClient único, DI, go_router, sessão) + telas do cliente + seed de serviços | 1 |
| 3 | CRUD de agendamentos do admin (Painel e Agenda Admin) + "Meus Agendamentos" | 3 |

**Testes no fim:** backend 217, Flutter 285, contrato ponta a ponta 3/3 (admin altera → cliente vê), contra o backend real.

**Repositórios:**
- App Flutter: `marcosgontijo/cortecerto_app_flutter`, branch `main` (último commit `ef83c6f`).
- Backend: `marcosgontijo/cortecerto`, branch `loop/mobile-migration` (último commit `7620220`).
  Cópia local em `C:\Users\Usuario\Documents\Projetos\Dev\Projetos\cortecerto-backend-loop`.
  A pasta `cortecerto` original está numa branch antiga com mudanças locais: **não usar**.

**Relatórios detalhados:** `fases/resultado-1/`, `fases/resultado-2/` e `fases/resultado-3/` (o `RELATORIO.md` da fase 3 tem o resumo de tudo).

---

## O que falta (por prioridade)

### 1. Testar o app num aparelho de verdade
Nada foi testado em emulador ou celular, nem o build do APK, nem o secure storage real.
- [ ] Subir o backend e rodar o app no emulador (passo a passo abaixo).
- [ ] Seguir o roteiro de 11 cliques de `fases/resultado-3/RELATORIO.md` → "Roteiro de cliques (admin → cliente)".
- [ ] Testar login errado 3 vezes (bloqueio 423) e o limite por IP (429) contra o backend real.
- [ ] `flutter build apk --release` e instalar num celular.

### 2. Ajustar os preços dos serviços
Os preços da migration V5 são **provisórios**: Corte Simples 35, Corte + Barba 55, Barba 25, Sobrancelha 15, Corte Completo 65.
- [ ] Definir os preços reais.
- [ ] Criar uma migration **V6** com os valores (não editar a V5, para não quebrar o checksum do Flyway).

### 3. Revisar as decisões tomadas sem você
Os agentes decidiram sozinhos 17 pontos (o 18º foi decisão sua). A lista completa está em
`fases/resultado-3/RELATORIO.md` → "Decisões tomadas sem o humano". Os que mais valem conferir:
- [ ] Cliente cancelando agendamento já cancelado ou realizado → 409.
- [ ] Admin não pode criar agendamento já como CANCELADO.
- [ ] Busca de clientes só retorna role CLIENTE e **não ignora acentos** ("Jose" não acha "José").
- [ ] Com filtro ativo, a Agenda Admin vira lista em vez de grade.
- [ ] Horário livre que já passou aparece como "Horário encerrado".
- [ ] Agendamento criado pelo admin começa como CONFIRMADO.

### 4. Levar o backend para a branch principal
- [ ] Abrir um Pull Request de `loop/mobile-migration` para `master` (ou `pipeline_prod`) e revisar.
- [ ] Rodar o **checklist de deploy** do `README.md` do backend **antes** de publicar:
  - backup do banco de produção;
  - a V3 cancela agendamentos duplicados antigos sem avisar;
  - a V4 normaliza CPF/e-mail e deixa colisões para correção manual (rodar as consultas do README antes);
  - definir as variáveis: `SECURITY_JWT_SECRET_KEY`, `ADMIN_CPF`, `ADMIN_SENHA`, `ADMIN_EMAIL`, `CORS_ALLOWED_ORIGINS`;
  - o token agora vale 8h e identifica o usuário pelo id.
- [ ] Se o CPF do seed antigo (V1) for de uma pessoa real, decidir se vale reescrever o histórico do repositório.

### 5. Decidir o que fazer com o web Angular
O web **quebra** com o backend novo: o formato de `disponibilidades` mudou, o `clienteId` enviado é ignorado e a origem precisa estar em `CORS_ALLOWED_ORIGINS`.
- [ ] Ajustar o web (seria uma nova fase) **ou** aposentá-lo antes de publicar o backend.

### 6. Melhorias pequenas (baixa prioridade)
- [ ] Agenda Admin: "Hoje" só troca de dia na próxima recarga se a tela ficar aberta depois da meia-noite.
- [ ] `lib/features/agendamento/presentation/agendamento_page.dart:68`: somar 90 dias com `DateTime(y, m, d + 90)` em vez de `Duration`.
- [ ] Backend: fixar o algoritmo do JWT (com plano de rotação de chave); rate limit com reserva atômica e mapa limitado; corrigir o comentário de `hibernate.jdbc.time_zone` no `application.yml`.
- [ ] Token continua válido até expirar mesmo se o cliente for apagado.
- [ ] Busca de clientes ignorando acentos.

### Ideias para uma Fase 4
- [ ] Cards "Clientes" e "Serviços" do Painel Admin (CRUD de clientes e de serviços/preços pelo app — resolveria o item 2 sem migration).
- [ ] Ajustes no web Angular (item 5).
- [ ] Notificações (push) quando o admin altera um agendamento.

---

## Como subir tudo para testar

**Backend** (Git Bash, na pasta `cortecerto-backend-loop`):
```bash
export JAVA_HOME=/c/Users/Usuario/.jdks/corretto-21.0.11; export PATH="$JAVA_HOME/bin:$PATH"   # o java do PATH é o 8
export SECURITY_JWT_SECRET_KEY="$(openssl rand -base64 48)"
export ADMIN_CPF=52998224725 ADMIN_SENHA='Admin12345' ADMIN_EMAIL=admin@teste.com   # valores de teste
./mvnw spring-boot:run      # sobe em http://localhost:8080/api
```

**App** (na pasta `cortecerto_flutter`, com o emulador Android aberto):
```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
```

**Testes automatizados:**
```bash
flutter analyze && flutter test        # testes do app (o contrato é pulado sem backend)
bash fases/resultado-3/gate.frozen.sh  # tudo: app + backend + contrato contra o backend real
```
> No Windows, `flutter pub get` pode dar erro de symlink (falta o Modo de Desenvolvedor). Os testes rodam mesmo assim.

---

## Como retomar com os agentes
1. Abra o Claude Code nesta pasta e digite `/agents`: os 5 agentes (analista, developer, tester, reviewer, finalizador) devem aparecer.
2. Para uma demanda nova, peça: *"Crie a FASE 4 em `fases/` para <o que você quer>, ative no TAREFA.md e siga o fluxo do CLAUDE.md, no máximo 6 voltas."*
3. O estado do loop da Fase 3 foi guardado em `.loop-fase3/` (fora do git). A próxima fase começa com uma `.loop/` nova.
4. Enquanto existir `.loop/` com veredito, o hook Stop roda o gate antes de o Claude encerrar. Mova ou apague a `.loop/` se for só conversar.
