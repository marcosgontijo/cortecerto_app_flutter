import 'package:flutter/foundation.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/state/notificador_seguro.dart';
import '../../agendamento/data/agendamento_api.dart';
import '../../agendamento/domain/status_agendamento.dart';
import '../../servicos/data/servicos_api.dart';
import '../../servicos/domain/servico.dart';
import '../data/admin_agendamento_api.dart';
import '../data/clientes_api.dart';
import '../domain/agendamento_admin.dart';

/// Argumentos da rota do formulário: [existente] para editar; senão cria em [data]/[horario].
class AgendamentoFormArgs {
  const AgendamentoFormArgs.criar({required this.data, this.horario}) : existente = null;
  AgendamentoFormArgs.editar(AgendamentoAdmin this.existente)
      : data = existente.data,
        horario = existente.horario;

  final AgendamentoAdmin? existente;
  final DateTime data;
  final String? horario;

  bool get editando => existente != null;
}

/// Formulário de criar/editar agendamento do admin.
class AgendamentoFormController extends ChangeNotifier with NotificadorSeguro {
  AgendamentoFormController({
    required AdminAgendamentoApi adminApi,
    required ClientesApi clientesApi,
    required AgendamentoApi agendamentoApi,
    required ServicosApi servicosApi,
    required this.args,
    DateTime Function()? relogio,
  })  : _adminApi = adminApi,
        _clientesApi = clientesApi,
        _agendamentoApi = agendamentoApi,
        _servicosApi = servicosApi,
        _relogio = relogio ?? DateTime.now {
    final e = args.existente;
    _data = DateTime(args.data.year, args.data.month, args.data.day);
    _horario = args.horario;
    if (e == null) {
      // Criação nunca começa no passado (o backend recusa com 400).
      if (_data.isBefore(hoje)) {
        _data = hoje;
        _horario = null;
      } else if (_horario != null && horarioJaPassou(_horario!)) {
        _horario = null;
      }
    }
    _status = e?.status ?? StatusAgendamento.confirmado;
    if (e != null) {
      _cliente = ClienteResumo(id: e.clienteId, nome: e.nomeCliente, telefone: e.telefoneCliente);
    }
  }

  final AdminAgendamentoApi _adminApi;
  final ClientesApi _clientesApi;
  final AgendamentoApi _agendamentoApi;
  final ServicosApi _servicosApi;
  final AgendamentoFormArgs args;
  final DateTime Function() _relogio;

  // clientes
  List<ClienteResumo> _clientes = const [];
  bool _buscandoClientes = false;
  bool _buscouClientes = false;
  String? _erroClientes;
  ClienteResumo? _cliente;
  int _reqClientes = 0;

  // serviços
  List<Servico> _servicos = const [];
  bool _carregandoServicos = false;
  String? _erroServicos;
  int? _servicoId;

  // data e horário
  late DateTime _data;
  String? _horario;
  List<String> _horarios = const [];
  bool _carregandoHorarios = false;
  String? _erroHorarios;
  int _reqHorarios = 0;

  late StatusAgendamento _status;

  bool _salvando = false;
  String? _erroSalvar;

  bool get editando => args.editando;

  /// Hoje (sem hora), pelo relógio injetável.
  DateTime get hoje {
    final a = _relogio();
    return DateTime(a.year, a.month, a.day);
  }

  /// `true` se [horario] ("HH:mm") na data selecionada já passou (mesma regra do backend:
  /// data+horário antes de agora).
  bool horarioJaPassou(String horario) {
    final partes = horario.split(':');
    final h = int.tryParse(partes.first);
    final m = partes.length > 1 ? int.tryParse(partes[1]) : 0;
    if (h == null || m == null) return false;
    return DateTime(_data.year, _data.month, _data.day, h, m).isBefore(_relogio());
  }

  /// Primeiro dia do calendário: na criação, hoje (sem passado); na edição, o menor entre
  /// a data do agendamento e hoje (editar um passado sem mudar data/horário é permitido).
  DateTime get primeiroDiaCalendario {
    final h = hoje;
    if (!editando) return h;
    final original = DateTime(args.data.year, args.data.month, args.data.day);
    final menor = original.isBefore(h) ? original : h;
    return _data.isBefore(menor) ? _data : menor;
  }

  /// Último dia do calendário: o maior entre a data selecionada (ou a original) e hoje+365.
  /// Assim um agendamento a mais de um ano no futuro não quebra o `showDatePicker`.
  DateTime get ultimoDiaCalendario {
    final h = hoje;
    var maior = DateTime(h.year, h.month, h.day + 365);
    final original = DateTime(args.data.year, args.data.month, args.data.day);
    if (original.isAfter(maior)) maior = original;
    if (_data.isAfter(maior)) maior = _data;
    return maior;
  }

  /// Na edição, só a data original do agendamento, a data já selecionada e dias a partir
  /// de hoje podem ser escolhidos (o backend recusa mudar para uma data passada). Na criação
  /// o calendário já começa em hoje, então todos os dias do intervalo valem.
  bool diaSelecionavel(DateTime dia) {
    final d = DateTime(dia.year, dia.month, dia.day);
    if (!editando) return true;
    final original = DateTime(args.data.year, args.data.month, args.data.day);
    return d == original || d == _data || !d.isBefore(hoje);
  }

  /// Dia inicial do calendário: a data selecionada, limitada a [primeiroDiaCalendario, ultimoDiaCalendario].
  DateTime get diaInicialCalendario {
    final primeiro = primeiroDiaCalendario;
    final ultimo = ultimoDiaCalendario;
    if (_data.isBefore(primeiro)) return primeiro;
    if (_data.isAfter(ultimo)) return ultimo;
    return _data;
  }
  List<ClienteResumo> get clientes => _clientes;
  bool get buscandoClientes => _buscandoClientes;
  bool get buscouClientes => _buscouClientes;
  String? get erroClientes => _erroClientes;
  ClienteResumo? get cliente => _cliente;
  List<Servico> get servicos => _servicos;
  bool get carregandoServicos => _carregandoServicos;
  String? get erroServicos => _erroServicos;
  int? get servicoId => _servicoId;
  DateTime get data => _data;
  String? get horario => _horario;
  List<String> get horarios => _horarios;
  bool get carregandoHorarios => _carregandoHorarios;
  String? get erroHorarios => _erroHorarios;
  StatusAgendamento get status => _status;
  bool get salvando => _salvando;
  String? get erroSalvar => _erroSalvar;

  /// Status oferecidos: na criação não faz sentido criar já cancelado (o backend recusa).
  List<StatusAgendamento> get statusDisponiveis => editando
      ? StatusAgendamento.conhecidos
      : const [StatusAgendamento.pendente, StatusAgendamento.confirmado, StatusAgendamento.realizado];

  bool get podeSalvar =>
      !_salvando && _cliente != null && _servicoId != null && _horario != null;

  /// Carrega serviços e horários livres da data inicial.
  Future<void> iniciar() async {
    await Future.wait([_carregarServicos(), carregarHorarios()]);
  }

  Future<void> _carregarServicos() async {
    _carregandoServicos = true;
    _erroServicos = null;
    notifyListeners();
    try {
      _servicos = await _servicosApi.listar();
      final e = args.existente;
      if (e != null && _servicoId == null) {
        _servicoId = _servicos.where((s) => s.id == e.servicoId).firstOrNull?.id ??
            _servicos.where((s) => s.tipoServico == e.servico).firstOrNull?.id;
      }
    } catch (e) {
      _erroServicos = ApiErrorMapper.deErro(e).mensagem;
    } finally {
      _carregandoServicos = false;
      notifyListeners();
    }
  }

  Future<void> buscarClientes(String termo) async {
    final t = termo.trim();
    if (t.isEmpty) return;
    final req = ++_reqClientes;
    _buscandoClientes = true;
    _erroClientes = null;
    notifyListeners();
    try {
      final lista = await _clientesApi.buscar(t);
      if (req != _reqClientes) return;
      _clientes = lista;
      _buscouClientes = true;
    } catch (e) {
      if (req != _reqClientes) return;
      _erroClientes = ApiErrorMapper.deErro(e).mensagem;
    } finally {
      if (req == _reqClientes) {
        _buscandoClientes = false;
        notifyListeners();
      }
    }
  }

  void selecionarCliente(ClienteResumo c) {
    if (editando) return; // o cliente de um agendamento não muda
    _cliente = c;
    _erroSalvar = null;
    notifyListeners();
  }

  void selecionarServico(int? id) {
    _servicoId = id;
    _erroSalvar = null;
    notifyListeners();
  }

  void selecionarStatus(StatusAgendamento s) {
    _status = s;
    _erroSalvar = null;
    notifyListeners();
  }

  void selecionarHorario(String h) {
    _horario = h;
    _erroSalvar = null;
    notifyListeners();
  }

  Future<void> selecionarData(DateTime d) async {
    _data = DateTime(d.year, d.month, d.day);
    _horario = null;
    _erroSalvar = null;
    await carregarHorarios();
  }

  /// Horários livres (`disponibilidades`). Na edição, o horário atual do próprio
  /// agendamento (mesma data) também é oferecido: manter o horário não é conflito.
  Future<void> carregarHorarios() async {
    final req = ++_reqHorarios;
    _carregandoHorarios = true;
    _erroHorarios = null;
    notifyListeners();
    try {
      final livres = await _agendamentoApi.disponibilidades(_data);
      if (req != _reqHorarios) return;
      final e = args.existente;
      final lista = {...livres};
      if (e != null && e.data == _data) lista.add(e.horario);
      // Na criação, nada de horário que já passou (o backend também filtra; aqui vale o relógio do app).
      if (e == null) lista.removeWhere(horarioJaPassou);
      _horarios = lista.toList()..sort();
      if (_horario != null && !_horarios.contains(_horario)) _horario = null;
    } catch (e) {
      if (req != _reqHorarios) return;
      _erroHorarios = ApiErrorMapper.deErro(e).mensagem;
      _horarios = const [];
    } finally {
      if (req == _reqHorarios) {
        _carregandoHorarios = false;
        notifyListeners();
      }
    }
  }

  /// Salva. Retorna `true` em caso de sucesso. Em 409 mostra a mensagem do backend
  /// ("Horário indisponível") e recarrega os horários livres.
  Future<bool> salvar() async {
    if (!podeSalvar) return false;
    _salvando = true;
    _erroSalvar = null;
    notifyListeners();
    try {
      final e = args.existente;
      if (e == null) {
        await _adminApi.criar(
          clienteId: _cliente!.id,
          servicoId: _servicoId!,
          data: _data,
          horario: _horario!,
          status: _status,
        );
      } else {
        await _adminApi.atualizar(
          e.id,
          servicoId: _servicoId,
          data: _data,
          horario: _horario,
          // Status desconhecido (não escolhido pelo admin) não é reenviado: o backend o mantém.
          status: _status == StatusAgendamento.desconhecido ? null : _status,
        );
      }
      return true;
    } catch (e) {
      final erro = ApiErrorMapper.deErro(e);
      _erroSalvar = erro.mensagem;
      if (erro.tipo == ApiErrorTipo.conflito) {
        _horario = null;
        _salvando = false;
        await carregarHorarios();
      }
      return false;
    } finally {
      _salvando = false;
      notifyListeners();
    }
  }
}
