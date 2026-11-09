import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters/formatters.dart';
import 'agendamento_form_controller.dart';

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
    final cs = Theme.of(context).colorScheme;
    final titulo = Theme.of(context).textTheme.titleMedium;
    return Scaffold(
      appBar: AppBar(title: Text(c.editando ? 'Editar agendamento' : 'Novo agendamento')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Cliente', style: titulo),
                  const SizedBox(height: 8),
                  if (c.cliente != null)
                    Text(
                      c.cliente!.nome,
                      key: const Key('form-cliente-selecionado'),
                      style: TextStyle(color: cs.secondary, fontWeight: FontWeight.bold),
                    ),
                  if (!c.editando) ...[
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('campo-busca-cliente'),
                      controller: _busca,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Nome ou CPF do cliente',
                        suffixIcon: IconButton(
                          key: const Key('botao-buscar-cliente'),
                          icon: const Icon(Icons.search),
                          onPressed: () => c.buscarClientes(_busca.text),
                        ),
                      ),
                      onSubmitted: c.buscarClientes,
                    ),
                    _ResultadoClientes(controller: c),
                  ],
                  const SizedBox(height: 16),
                  Text('Serviço', style: titulo),
                  const SizedBox(height: 8),
                  _Servicos(controller: c),
                  const SizedBox(height: 16),
                  Text('Data', style: titulo),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('form-botao-data'),
                    onPressed: c.salvando ? null : () => _escolherData(c),
                    icon: const Icon(Icons.event),
                    label: Text(Formatters.data(c.data)),
                  ),
                  const SizedBox(height: 16),
                  Text('Horário', style: titulo),
                  const SizedBox(height: 8),
                  _Horarios(controller: c),
                  const SizedBox(height: 16),
                  Text('Status', style: titulo),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in c.statusDisponiveis)
                        ChoiceChip(
                          key: Key('form-status-${s.api}'),
                          label: Text(s.rotulo),
                          selected: c.status == s,
                          onSelected: (_) => c.selecionarStatus(s),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (c.erroSalvar != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        c.erroSalvar!,
                        key: const Key('form-erro'),
                        style: TextStyle(color: cs.error, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ElevatedButton(
                    key: const Key('form-botao-salvar'),
                    onPressed: c.podeSalvar ? () => _salvar(c) : null,
                    child: c.salvando
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(c.editando ? 'Salvar alterações' : 'Criar agendamento'),
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

class _ResultadoClientes extends StatelessWidget {
  const _ResultadoClientes({required this.controller});

  final AgendamentoFormController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.buscandoClientes) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (c.erroClientes != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(c.erroClientes!, key: const Key('form-erro-clientes')),
      );
    }
    if (c.buscouClientes && c.clientes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('Nenhum cliente encontrado.', key: Key('form-clientes-vazio')),
      );
    }
    return Column(
      children: [
        for (final cli in c.clientes)
          ListTile(
            key: Key('form-cliente-${cli.id}'),
            dense: true,
            selected: c.cliente == cli,
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
    if (c.carregandoServicos) return const LinearProgressIndicator();
    if (c.erroServicos != null) return Text(c.erroServicos!, key: const Key('form-erro-servicos'));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
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
    if (c.carregandoHorarios) return const LinearProgressIndicator();
    if (c.erroHorarios != null) {
      return Row(
        children: [
          Expanded(child: Text(c.erroHorarios!, key: const Key('form-erro-horarios'))),
          TextButton(onPressed: c.carregarHorarios, child: const Text('Tentar novamente')),
        ],
      );
    }
    if (c.horarios.isEmpty) {
      return const Text('Nenhum horário livre nesta data.', key: Key('form-horarios-vazio'));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
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
