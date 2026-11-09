import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters/formatters.dart';
import 'agendamento_form_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/botao_primario.dart';
import '../../../core/widgets/estados.dart';
import '../../agendamento/domain/status_agendamento.dart';

/// Criar/editar agendamento do admin. Volta com `true` quando salvou.
class AgendamentoFormPage extends StatefulWidget {
  const AgendamentoFormPage({super.key});

  @override
  State<AgendamentoFormPage> createState() => _AgendamentoFormPageState();
}

class _AgendamentoFormPageState extends State<AgendamentoFormPage> {
  final _busca = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AgendamentoFormController>().iniciar();
    });
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _escolherData(AgendamentoFormController c) async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: c.diaInicialCalendario,
      firstDate: c.primeiroDiaCalendario,
      lastDate: c.ultimoDiaCalendario,
      selectableDayPredicate: c.diaSelecionavel,
      helpText: 'Data do agendamento',
    );
    if (escolhida != null && mounted) await c.selecionarData(escolhida);
  }

  Future<void> _salvar(AgendamentoFormController c) async {
    final ok = await c.salvar();
    if (ok && mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AgendamentoFormController>();
    final t = AppTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(c.editando ? 'Editar agendamento' : 'Novo agendamento')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(t.md),
                children: [
                  const _Secao(icone: Icons.person_outline, titulo: 'Cliente'),
                  if (c.cliente != null) ...[
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: t.success, size: 20),
                        SizedBox(width: t.sm),
                        Expanded(
                          child: Text(
                            c.cliente!.nome,
                            key: const Key('form-cliente-selecionado'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: t.sm),
                  ],
                  if (!c.editando) ...[
                    TextField(
                      key: const Key('campo-busca-cliente'),
                      controller: _busca,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: 'Buscar cliente',
                        hintText: 'Nome ou CPF do cliente',
                        prefixIcon: const Icon(Icons.person_search_outlined),
                        suffixIcon: IconButton(
                          key: const Key('botao-buscar-cliente'),
                          tooltip: 'Buscar cliente',
                          icon: const Icon(Icons.search),
                          onPressed: () => c.buscarClientes(_busca.text),
                        ),
                      ),
                      onSubmitted: c.buscarClientes,
                    ),
                    _ResultadoClientes(
                      controller: c,
                      onTentarNovamente: () => c.buscarClientes(_busca.text),
                    ),
                  ],
                  SizedBox(height: t.lg),
                  const _Secao(icone: Icons.content_cut, titulo: 'Serviço'),
                  _Servicos(controller: c),
                  SizedBox(height: t.lg),
                  const _Secao(icone: Icons.event_outlined, titulo: 'Data'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const Key('form-botao-data'),
                      onPressed: c.salvando ? null : () => _escolherData(c),
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: Text(Formatters.data(c.data)),
                    ),
                  ),
                  SizedBox(height: t.lg),
                  const _Secao(icone: Icons.schedule, titulo: 'Horário'),
                  _Horarios(controller: c),
                  SizedBox(height: t.lg),
                  const _Secao(icone: Icons.flag_outlined, titulo: 'Status'),
                  Wrap(
                    spacing: t.sm,
                    runSpacing: t.sm,
                    children: [
                      for (final s in c.statusDisponiveis)
                        ChoiceChip(
                          key: Key('form-status-${s.api}'),
                          showCheckmark: false,
                          avatar: Icon(s.icone, size: 18, color: s.cor(t)),
                          label: Text(s.rotulo),
                          selected: c.status == s,
                          onSelected: (_) => c.selecionarStatus(s),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // CTA fixo fora da rolagem.
            DecoratedBox(
              decoration: BoxDecoration(
                color: t.surfaceHigh,
                border: Border(top: BorderSide(color: t.divider)),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(t.md, t.md - 4, t.md, t.md - 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (c.erroSalvar != null) ...[
                      BlocoErro(key: const Key('form-erro'), texto: c.erroSalvar!),
                      SizedBox(height: t.sm),
                    ],
                    BotaoPrimario(
                      key: const Key('form-botao-salvar'),
                      rotulo: c.editando ? 'Salvar alterações' : 'Criar agendamento',
                      icone: Icons.check,
                      enviando: c.salvando,
                      onPressed: c.podeSalvar ? () => _salvar(c) : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Título de seção do formulário (ícone + texto).
class _Secao extends StatelessWidget {
  const _Secao({required this.icone, required this.titulo});

  final IconData icone;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: t.sm),
      child: Row(
        children: [
          Icon(icone, size: 20, color: Theme.of(context).colorScheme.primary),
          SizedBox(width: t.sm),
          Text(titulo, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ResultadoClientes extends StatelessWidget {
  const _ResultadoClientes({required this.controller, required this.onTentarNovamente});

  final AgendamentoFormController controller;

  /// Repete a busca com o termo que está no campo.
  final VoidCallback onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final t = AppTokens.of(context);
    if (c.buscandoClientes) {
      return const EstadoCarregando(mensagem: 'Buscando clientes');
    }
    if (c.erroClientes != null) {
      return EstadoErro(
        key: const Key('form-erro-clientes'),
        mensagem: c.erroClientes!,
        onTentarNovamente: onTentarNovamente,
      );
    }
    if (c.buscouClientes && c.clientes.isEmpty) {
      return const EstadoVazio(
        key: Key('form-clientes-vazio'),
        icone: Icons.person_off_outlined,
        titulo: 'Nenhum cliente encontrado.',
        texto: 'Confira o nome ou o CPF e busque de novo.',
      );
    }
    return Column(
      children: [
        for (final cli in c.clientes)
          ListTile(
            key: Key('form-cliente-${cli.id}'),
            selected: c.cliente == cli,
            contentPadding: EdgeInsets.symmetric(horizontal: t.sm),
            leading: Icon(c.cliente == cli ? Icons.radio_button_checked : Icons.radio_button_off),
            title: Text(cli.nome),
            subtitle: Text([cli.cpf, cli.telefone].whereType<String>().join(' · ')),
            onTap: () => c.selecionarCliente(cli),
          ),
      ],
    );
  }
}

class _Servicos extends StatelessWidget {
  const _Servicos({required this.controller});

  final AgendamentoFormController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final t = AppTokens.of(context);
    if (c.carregandoServicos) {
      return const EstadoCarregando(mensagem: 'Carregando serviços');
    }
    if (c.erroServicos != null) {
      // iniciar() é o recarregar público do controller (serviços + horários).
      return EstadoErro(
        key: const Key('form-erro-servicos'),
        mensagem: c.erroServicos!,
        onTentarNovamente: c.iniciar,
      );
    }
    if (c.servicos.isEmpty) {
      return const EstadoVazio(
        key: Key('form-servicos-vazio'),
        icone: Icons.content_cut,
        titulo: 'Nenhum serviço cadastrado.',
        texto: 'Cadastre um serviço para poder agendar.',
      );
    }
    return Wrap(
      spacing: t.sm,
      runSpacing: t.sm,
      children: [
        for (final s in c.servicos)
          ChoiceChip(
            key: Key('form-servico-${s.id}'),
            label: Text(s.tipoServico),
            selected: c.servicoId == s.id,
            onSelected: (_) => c.selecionarServico(s.id),
          ),
      ],
    );
  }
}

class _Horarios extends StatelessWidget {
  const _Horarios({required this.controller});

  final AgendamentoFormController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final t = AppTokens.of(context);
    if (c.carregandoHorarios) {
      return const EstadoCarregando(mensagem: 'Carregando horários');
    }
    if (c.erroHorarios != null) {
      return EstadoErro(
        key: const Key('form-erro-horarios'),
        mensagem: c.erroHorarios!,
        onTentarNovamente: c.carregarHorarios,
      );
    }
    if (c.horarios.isEmpty) {
      return const EstadoVazio(
        key: Key('form-horarios-vazio'),
        icone: Icons.event_busy_outlined,
        titulo: 'Nenhum horário livre nesta data.',
        texto: 'Escolha outra data.',
      );
    }
    return Wrap(
      spacing: t.sm,
      runSpacing: t.sm,
      children: [
        for (final h in c.horarios)
          ChoiceChip(
            key: Key('form-horario-$h'),
            label: Text(h),
            selected: c.horario == h,
            onSelected: c.salvando ? null : (_) => c.selecionarHorario(h),
          ),
      ],
    );
  }
}
