# Design System — CorteCerto (MASTER)

> Fonte única de verdade visual do app. Gerado com a skill `ui-ux-pro-max` (2026-11-09) e adaptado para o app Flutter.
> Páginas com regras próprias ficam em `design-system/cortecerto/pages/<pagina>.md` e têm prioridade sobre este arquivo.

## De onde veio
- Buscas `"barbershop booking appointment mobile"` e `"barber salon grooming"` (`--design-system`): devolveram paletas genéricas de SaaS
  (azul "calendar" / "trust blue"). **Descartadas**: não combinam com barbearia nem com a identidade atual (grafite + dourado).
- Busca `"dark gold luxury" --domain color` → resultado 1 **"Premium dark + gold accent"** (E-commerce Luxury: `#1C1917`, `#44403C`,
  dourado `#CA8A04`/`#A16207`). **Adotada** e convertida para tema escuro (o resultado original é de fundo claro).
- Estilo: **Minimalism / Soft UI** (sombras suaves, alto contraste, hierarquia clara). O "Liquid Glass" que a skill também sugeriu foi
  descartado: o desfoque custa desempenho e o estilo é próprio das plataformas Apple.
- Padrão de fluxo: **Funnel em etapas** (indicador de progresso + um CTA por etapa) para o agendamento.
- Tipografia: a skill sugeriu Cormorant + Montserrat ou DM Sans. **Nesta fase fica a fonte do sistema (Roboto)** com a escala abaixo,
  porque incluir fonte nova exige baixar arquivos ou o `google_fonts` (requisição externa em tempo de execução). Ver "Fora do escopo" da FASE-4.

## Cores (tema escuro, tokens semânticos)
| Token | Hex | Uso | Contraste medido |
|---|---|---|---|
| `background` | `#0C0A09` | fundo das telas | — |
| `surface` | `#1C1917` | cards, app bar, campos | — |
| `surfaceHigh` | `#292524` | card elevado, chip não selecionado, bottom bar | — |
| `onSurface` | `#FAFAF9` | texto principal | 16.7:1 em surface |
| `onSurfaceMuted` | `#A8A29E` | texto secundário, legenda | 6.9:1 em surface, 6.0:1 em surfaceHigh |
| `primary` (dourado) | `#D4A017` | CTA, item selecionado, foco | 7.4:1 em surface, 8.3:1 em background |
| `onPrimary` | `#0C0A09` | texto sobre o dourado | 8.3:1 |
| `outline` | `#8A837E` | borda de campo e de controle | 4.7:1 em surface, 4.1:1 em surfaceHigh (≥ 3:1) |
| `divider` | `#44403C` | divisórias decorativas (não carregam informação) | — |
| `error` | `#F87171` | erro, cancelar/excluir | 6.3:1 em surface; `onError` `#0C0A09` 7.1:1 |
| `success` | `#4ADE80` | sucesso, CONFIRMADO | 10.0:1 em surface |
| `warning` | `#FBBF24` | PENDENTE | 10.5:1 em surface |
| `info` | `#60A5FA` | REALIZADO | 6.9:1 em surface |
| `neutral` | `#A8A29E` | CANCELADO, DESCONHECIDO | 6.9:1 em surface |

Status de agendamento: chip com **ícone + texto** (nunca só cor), cor do status no texto/ícone/borda sobre `surfaceHigh`.
- PENDENTE → `warning`, ícone `schedule` · CONFIRMADO → `success`, `check_circle` · REALIZADO → `info`, `task_alt`
- CANCELADO → `neutral`, `cancel` · DESCONHECIDO → `neutral`, `help_outline`

## Tipografia (Roboto do sistema, via `TextTheme`)
| Papel | Tamanho / peso |
|---|---|
| `headlineSmall` (título de tela/hero) | 24 / w700 |
| `titleLarge` (app bar) | 20 / w600 |
| `titleMedium` (título de card) | 16 / w600 |
| `bodyLarge` (texto padrão) | 16 / w400, altura 1.5 |
| `bodyMedium` (secundário) | 14 / w400, altura 1.45 |
| `labelLarge` (botões) | 16 / w600 |
| `labelMedium` (chips) | 13 / w600 — nada abaixo de 12 |

Telas leem estilos com `Theme.of(context).textTheme`, nunca `TextStyle(fontSize: …)` solto.

## Espaçamento, forma e elevação
- Escala 4/8: `xs 4 · sm 8 · md 16 · lg 24 · xl 32 · xxl 48`. Margem lateral das telas: 16 (24 em largura ≥ 600).
- Raios: campo/botão 12, card 16, chip 999 (pílula), bottom sheet 24 no topo.
- Elevação: cards em `surface` sem sombra pesada (borda `divider` de 1px ou elevação 1). Nada de 3D ou sombras complexas.

## Componentes
- **Botão primário** (`FilledButton`): dourado, altura mínima 52, largura total nos formulários, mostra `CircularProgressIndicator` pequeno
  e fica desabilitado enquanto envia. **Secundário**: `OutlinedButton` com `outline`. **Destrutivo**: texto/borda `error`.
- **Campo** (`TextFormField`): rótulo sempre visível (nunca só placeholder), erro logo abaixo do campo, ícone à esquerda,
  `textInputAction` next/done, `autofillHints` quando couber, senha com botão mostrar/ocultar (com rótulo acessível).
- **Card de lista**: área de toque inteira com ripple, título `titleMedium`, detalhe `bodyMedium` muted, ação à direita.
- **Estados padrão** (widgets comuns em `lib/core/widgets/`): `EstadoCarregando` (skeleton ou indicador centralizado),
  `EstadoVazio` (ícone + título + texto + ação opcional), `EstadoErro` (mensagem + botão "Tentar novamente").
- **Feedback**: `SnackBar` flutuante para sucesso/erro; diálogo de confirmação para ações destrutivas, com o botão destrutivo em `error`.
- **Ícones**: só Material Icons (outlined no conteúdo, filled no item selecionado da navegação). Tamanhos 20 / 24 / 32. Nenhum emoji.

## Interação e acessibilidade
- Área de toque ≥ 48×48dp em tudo que é clicável (inclusive ícones e chips de horário).
- Contraste: texto ≥ 4.5:1, ícones e bordas que carregam informação ≥ 3:1.
- Botões só com ícone têm `tooltip`/`Semantics(label:)`.
- Funciona com texto em 200% (`textScaler` 2.0) em tela de 360×640 sem overflow.
- Animações: 150–300ms, `Curves.easeOut`; se `MediaQuery.disableAnimations` estiver ligado, sem animação.
- Respeitar `SafeArea` em barras fixas (bottom bar, CTA fixo) e dar espaço no fim das listas para não ficarem atrás delas.

## Navegação
- Cliente: **NavigationBar inferior** com 3 destinos — Serviços, Meus agendamentos, Produtos — usando os mesmos paths de hoje.
  Fluxo de agendamento e Confirmado ficam fora da barra (telas de etapa).
- Admin: Painel com cards grandes; Agenda com FAB "+ Novo agendamento".
- Voltar sempre previsível (o comportamento de `PopScope` da Confirmado continua).

## Anti-padrões (evitar)
Emoji como ícone · cor fixa (`Color(0x…)`/`Colors.x`) em tela · informação só por cor · texto < 12 · placeholder no lugar de rótulo ·
erro só no topo do formulário · botão que parece clicável e não faz nada · sombras complexas · 3D · animação sem propósito.
