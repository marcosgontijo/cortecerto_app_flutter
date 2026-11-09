import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/estados.dart';
import '../domain/faturamento.dart';
import '../domain/periodo_faturamento.dart';
import 'faturamento_controller.dart';

/// Faturamento (`/admin/faturamento`, só ADMIN): período Dia/Semana/Mês com setas, resumo
/// (Recebido em destaque e Previsto à parte), lista por dia com barra proporcional
/// (Semana/Mês) e lista por serviço. Pull-to-refresh; os dados vêm sempre do servidor.
class FaturamentoPage extends StatefulWidget {
  const FaturamentoPage({super.key});

  @override
  State<FaturamentoPage> createState() => _FaturamentoPageState();
}

class _FaturamentoPageState extends State<FaturamentoPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FaturamentoController>().carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<FaturamentoController>();
    final t = AppTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Faturamento')),
      body: SafeArea(
        child: RefreshIndicator(
          key: const Key('faturamento-refresh'),
          onRefresh: c.carregar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(t.md),
            children: [
              _SeletorPeriodo(controller: c),
              SizedBox(height: t.md),
              ..._conteudo(c, t),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _conteudo(FaturamentoController c, AppTokens t) {
    final tema = Theme.of(context).textTheme;
    if (c.erro != null) {
      return [
        EstadoErro(key: const Key('faturamento-erro'), mensagem: c.erro!, onTentarNovamente: c.carregar),
      ];
    }
    final f = c.faturamento;
    if (f == null) {
      return const [
        EstadoCarregando(
          mensagem: 'Carregando faturamento',
          chaveIndicador: Key('faturamento-carregando'),
        ),
      ];
    }
    final mostrarPorDia = c.tipo != TipoPeriodo.dia;
    return [
      _CardRecebido(faturamento: f),
      SizedBox(height: t.sm),
      _CardPrevisto(faturamento: f),
      SizedBox(height: t.lg),
      if (f.semRealizados)
        const EstadoVazio(
          key: Key('faturamento-vazio'),
          icone: Icons.payments_outlined,
          titulo: 'Nenhum atendimento realizado neste período',
          texto: 'O recebido aparece quando um agendamento é marcado como realizado.',
        )
      else ...[
        if (mostrarPorDia) ...[
          Text('Por dia', style: tema.titleMedium),
          SizedBox(height: t.sm),
          Card(
            key: const Key('faturamento-por-dia'),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.md, vertical: t.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final d in f.porDia) _LinhaDia(dia: d, maior: f.maiorRecebidoDia),
                ],
              ),
            ),
          ),
          SizedBox(height: t.lg),
        ],
        Text('Por serviço', style: tema.titleMedium),
        SizedBox(height: t.sm),
        Card(
          key: const Key('faturamento-por-servico'),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: t.md, vertical: t.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < f.porServico.length; i++)
                  _LinhaServico(key: Key('faturamento-servico-$i'), item: f.porServico[i]),
              ],
            ),
          ),
        ),
      ],
    ];
  }
}

/// Dia / Semana / Mês, setas "anterior" e "próximo" e o rótulo do período.
class _SeletorPeriodo extends StatelessWidget {
  const _SeletorPeriodo({required this.controller});

  final FaturamentoController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<TipoPeriodo>(
          key: const Key('faturamento-tipo'),
          showSelectedIcon: false,
          segments: [
            for (final tipo in TipoPeriodo.values)
              ButtonSegment(
                value: tipo,
                label: Text(tipo.rotulo, key: Key('faturamento-tipo-${tipo.name}')),
              ),
          ],
          selected: {c.tipo},
          onSelectionChanged: (s) => c.selecionarTipo(s.first),
        ),
        SizedBox(height: t.sm),
        Row(
          children: [
            IconButton(
              key: const Key('faturamento-anterior'),
              tooltip: 'Período anterior',
              icon: const Icon(Icons.chevron_left),
              onPressed: c.anterior,
            ),
            Expanded(
              child: Text(
                c.periodo.rotulo,
                key: const Key('faturamento-periodo'),
                style: tema.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              key: const Key('faturamento-proximo'),
              tooltip: 'Próximo período',
              icon: const Icon(Icons.chevron_right),
              onPressed: c.proximo,
            ),
          ],
        ),
      ],
    );
  }
}

String _atendimentos(int n) => n == 1 ? '1 atendimento' : '$n atendimentos';

String _moeda(int centavos) => Formatters.moeda(centavos / 100);

/// Recebido em destaque (valor grande).
class _CardRecebido extends StatelessWidget {
  const _CardRecebido({required this.faturamento});

  final Faturamento faturamento;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    final f = faturamento;
    return Card(
      key: const Key('faturamento-recebido'),
      child: Padding(
        padding: EdgeInsets.all(t.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(t.sm),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(t.raioCampo),
              ),
              child: Icon(Icons.payments_outlined, size: 28, color: cs.primary),
            ),
            SizedBox(width: t.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recebido', style: tema.titleMedium),
                  SizedBox(height: t.xs),
                  Text(
                    _moeda(f.recebidoCentavos),
                    key: const Key('faturamento-recebido-valor'),
                    style: tema.headlineMedium?.copyWith(color: cs.onSurface),
                  ),
                  SizedBox(height: t.xs),
                  Text(
                    '${_atendimentos(f.quantidadeRealizados)} realizado${f.quantidadeRealizados == 1 ? '' : 's'}',
                    key: const Key('faturamento-recebido-quantidade'),
                    style: tema.bodyMedium?.copyWith(color: t.onSurfaceMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Previsto (confirmados e pendentes), à parte e menor que o Recebido.
class _CardPrevisto extends StatelessWidget {
  const _CardPrevisto({required this.faturamento});

  final Faturamento faturamento;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    final f = faturamento;
    return Card(
      key: const Key('faturamento-previsto'),
      child: Padding(
        padding: EdgeInsets.all(t.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(t.sm),
              child: Icon(Icons.event_available_outlined, size: 28, color: t.info),
            ),
            SizedBox(width: t.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Previsto', style: tema.titleSmall),
                  SizedBox(height: t.xs),
                  Text(
                    _moeda(f.previstoCentavos),
                    key: const Key('faturamento-previsto-valor'),
                    style: tema.titleLarge,
                  ),
                  SizedBox(height: t.xs),
                  Text(
                    '${_atendimentos(f.quantidadePrevistos)} confirmado${f.quantidadePrevistos == 1 ? '' : 's'} '
                    'ou pendente${f.quantidadePrevistos == 1 ? '' : 's'}',
                    key: const Key('faturamento-previsto-quantidade'),
                    style: tema.bodyMedium?.copyWith(color: t.onSurfaceMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Um dia: data, valor recebido em texto e barra proporcional ao maior recebido do período.
/// A barra é só reforço visual (fica fora da semântica): o valor está sempre no texto.
class _LinhaDia extends StatelessWidget {
  const _LinhaDia({required this.dia, required this.maior});

  final FaturamentoDia dia;
  final int maior;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    final chave = Formatters.dataApi(dia.data);
    final proporcao = maior <= 0 ? 0.0 : dia.recebidoCentavos / maior;
    return Padding(
      key: Key('faturamento-dia-$chave'),
      padding: EdgeInsets.symmetric(vertical: t.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: t.sm,
            runSpacing: t.xs,
            children: [
              Text(DateFormat('EEE, dd/MM', 'pt_BR').format(dia.data), style: tema.bodyMedium),
              Text(
                _moeda(dia.recebidoCentavos),
                key: Key('faturamento-dia-valor-$chave'),
                style: tema.titleSmall,
              ),
            ],
          ),
          SizedBox(height: t.xs),
          ExcludeSemantics(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: t.surfaceHigh,
                borderRadius: BorderRadius.circular(t.raioChip),
              ),
              alignment: Alignment.centerLeft,
              child: proporcao <= 0
                  ? null
                  : FractionallySizedBox(
                      widthFactor: proporcao.clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: DecoratedBox(
                        key: Key('faturamento-barra-$chave'),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(t.raioChip),
                        ),
                      ),
                    ),
            ),
          ),
          if (dia.previstoCentavos > 0) ...[
            SizedBox(height: t.xs),
            Text(
              'Previsto: ${_moeda(dia.previstoCentavos)}',
              style: tema.bodySmall?.copyWith(color: t.onSurfaceMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Um serviço: nome, quantidade de realizados e recebido.
class _LinhaServico extends StatelessWidget {
  const _LinhaServico({super.key, required this.item});

  final FaturamentoServico item;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.sm),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: t.sm,
        runSpacing: t.xs,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.servico, style: tema.bodyLarge),
              Text(
                '${_atendimentos(item.quantidade)} realizado${item.quantidade == 1 ? '' : 's'}',
                style: tema.bodySmall?.copyWith(color: t.onSurfaceMuted),
              ),
            ],
          ),
          Text(_moeda(item.recebidoCentavos), style: tema.titleSmall),
        ],
      ),
    );
  }
}
