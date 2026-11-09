import 'package:flutter/foundation.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/state/notificador_seguro.dart';
import '../../agendamento/domain/status_agendamento.dart';
import '../data/admin_agendamento_api.dart';
import '../domain/agendamento_admin.dart';

enum PeriodoAgenda { hoje, amanha, data }

/// Um horário da grade: o agendamento que ocupa o horário (se houver) e quantos
/// cancelados existem nele (cancelados não ocupam horário).
class SlotAgenda {
  const SlotAgenda({required this.horario, this.agendamento, this.cancelados = const []});

  final String horario;
  final AgendamentoAdmin? agendamento;
  final List<AgendamentoAdmin> cancelados;

  bool get disponivel => agendamento == null;
}

/// Resultado de uma ação da agenda (para o feedback da tela).
class ResultadoAcao {
  const ResultadoAcao.ok(this.mensagem) : sucesso = true, conflito = false;
  const ResultadoAcao.erro(this.mensagem, {this.conflito = false}) : sucesso = false;

  final bool sucesso;
  final bool conflito;
  final String mensagem;
}

/// Estado da Agenda Admin. Os dados vêm sempre do servidor (`GET /agendamento/admin?data=`);
/// filtro de status e busca por nome são aplicados localmente sobre o dia carregado.
class AgendaAdminController extends ChangeNotifier with NotificadorSeguro {
  AgendaAdminController(this._api, {DateTime Function()? relogio})
      : _relogio = relogio ?? DateTime.now {
    _dia = hoje;
  }

  /// Grade de atendimento (igual ao backend): 08:00 a 19:30, de 30 em 30 minutos.
  static final List<String> grade = [
    for (var m = 8 * 60; m <= 19 * 60 + 30; m += 30)
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}',
  ];

  final AdminAgendamentoApi _api;
  final DateTime Function() _relogio;

  late DateTime _dia;
  PeriodoAgenda _periodo = PeriodoAgenda.hoje;
  List<AgendamentoAdmin> _agendamentos = const [];
  bool _isLoading = false;
  bool _carregou = false;
  String? _erro;
  StatusAgendamento? _filtroStatus;
  String _busca = '';
  bool _executando = false;
  int _requisicao = 0;

  DateTime get hoje {
    final a = _relogio();
    return DateTime(a.year, a.month, a.day);
  }

  DateTime get dia => _dia;

  /// Amanhã (dia civil seguinte a [hoje]); soma por campos de data, sem `Duration`,
  /// para não cair no dia anterior numa borda de horário de verão.
  DateTime get amanha {
    final h = hoje;
    return DateTime(h.year, h.month, h.day + 1);
  }

  /// Primeiro dia do calendário "Data": o menor entre o dia exibido e hoje-365.
  /// Garante `firstDate <= initialDate` mesmo depois da virada da meia-noite.
  DateTime get primeiroDiaCalendario {
    final h = hoje;
    final limite = DateTime(h.year, h.month, h.day - 365);
    return _dia.isBefore(limite) ? _dia : limite;
  }

  /// Último dia do calendário "Data": o maior entre o dia exibido e hoje+365.
  DateTime get ultimoDiaCalendario {
    final h = hoje;
    final limite = DateTime(h.year, h.month, h.day + 365);
    return _dia.isAfter(limite) ? _dia : limite;
  }

  /// Dia inicial do calendário: o dia exibido limitado a [primeiroDiaCalendario, ultimoDiaCalendario].
  DateTime get diaInicialCalendario {
    final primeiro = primeiroDiaCalendario;
    final ultimo = ultimoDiaCalendario;
    if (_dia.isBefore(primeiro)) return primeiro;
    if (_dia.isAfter(ultimo)) return ultimo;
    return _dia;
  }

  /// `true` se [horario] ("HH:mm") no dia exibido já passou (data+horário antes de agora,
  /// mesma regra do backend). Horário passado não pode receber agendamento novo.
  bool horarioPassou(String horario) {
    final partes = horario.split(':');
    final h = int.tryParse(partes.first);
    final m = partes.length > 1 ? int.tryParse(partes[1]) : 0;
    if (h == null || m == null) return false;
    return DateTime(_dia.year, _dia.month, _dia.day, h, m).isBefore(_relogio());
  }
  PeriodoAgenda get periodo => _periodo;
  bool get isLoading => _isLoading;
  bool get carregou => _carregou;
  String? get erro => _erro;
  StatusAgendamento? get filtroStatus => _filtroStatus;
  String get busca => _busca;
  bool get executando => _executando;

  /// Todos os agendamentos do dia (sem filtro).
  List<AgendamentoAdmin> get agendamentos => _agendamentos;

  bool get temFiltro => _filtroStatus != null || _busca.trim().isNotEmpty;

  int contar(StatusAgendamento s) => _agendamentos.where((a) => a.status == s).length;
  int get total => _agendamentos.length;

  /// Agendamentos que passam no filtro de status e na busca por nome.
  List<AgendamentoAdmin> get filtrados {
    final termo = _busca.trim().toLowerCase();
    return _agendamentos
        .where((a) => _filtroStatus == null || a.status == _filtroStatus)
        .where((a) => termo.isEmpty || a.nomeCliente.toLowerCase().contains(termo))
        .toList();
  }

  /// Grade completa do dia. Num horário com um ativo e cancelados, mostra o ativo.
  /// Horários fora da grade (dados antigos) também aparecem.
  List<SlotAgenda> get slots {
    final horarios = {...grade, ..._agendamentos.map((a) => a.horario)}.toList()..sort();
    return [
      for (final h in horarios)
        SlotAgenda(
          horario: h,
          agendamento: _agendamentos
              .where((a) => a.horario == h && a.status.ocupaHorario)
              .firstOrNull,
          cancelados: _agendamentos
              .where((a) => a.horario == h && !a.status.ocupaHorario)
              .toList(),
        ),
    ];
  }

  Future<void> selecionarHoje() => _irPara(PeriodoAgenda.hoje, hoje);

  Future<void> selecionarAmanha() => _irPara(PeriodoAgenda.amanha, amanha);

  Future<void> selecionarData(DateTime d) {
    final dia = DateTime(d.year, d.month, d.day);
    if (dia == hoje) return selecionarHoje();
    if (dia == amanha) return selecionarAmanha();
    return _irPara(PeriodoAgenda.data, dia);
  }

  Future<void> _irPara(PeriodoAgenda periodo, DateTime dia) {
    _periodo = periodo;
    _dia = dia;
    _agendamentos = const [];
    _carregou = false;
    return carregar();
  }

  void filtrarStatus(StatusAgendamento? status) {
    _filtroStatus = status;
    notifyListeners();
  }

  void buscar(String termo) {
    _busca = termo;
    notifyListeners();
  }

  /// Busca a agenda do dia no servidor (sempre, nada de cache).
  /// Nos períodos "Hoje" e "Amanhã" o dia é recalculado pelo relógio a cada carga,
  /// para a tela aberta antes da meia-noite não continuar no dia anterior.
  Future<void> carregar() async {
    final DateTime? recalculado = switch (_periodo) {
      PeriodoAgenda.hoje => hoje,
      PeriodoAgenda.amanha => amanha,
      PeriodoAgenda.data => null,
    };
    if (recalculado != null && recalculado != _dia) {
      // o dia virou: descarta a lista do dia anterior antes de buscar o novo
      _dia = recalculado;
      _agendamentos = const [];
      _carregou = false;
    }
    final requisicao = ++_requisicao;
    _isLoading = true;
    _erro = null;
    notifyListeners();
    try {
      final lista = await _api.listar(_dia);
      if (requisicao != _requisicao) return; // resposta de um dia antigo
      _agendamentos = lista;
      _carregou = true;
    } catch (e) {
      if (requisicao != _requisicao) return;
      _erro = ApiErrorMapper.deErro(e).mensagem;
    } finally {
      if (requisicao == _requisicao) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<ResultadoAcao> confirmar(AgendamentoAdmin a) => _acao(
        () => _api.atualizar(a.id, status: StatusAgendamento.confirmado),
        'Agendamento confirmado.',
      );

  Future<ResultadoAcao> marcarRealizado(AgendamentoAdmin a) => _acao(
        () => _api.atualizar(a.id, status: StatusAgendamento.realizado),
        'Agendamento marcado como realizado.',
      );

  Future<ResultadoAcao> cancelar(AgendamentoAdmin a) =>
      _acao(() => _api.cancelar(a.id), 'Agendamento cancelado.');

  Future<ResultadoAcao> excluir(AgendamentoAdmin a) =>
      _acao(() => _api.excluir(a.id), 'Agendamento excluído.');

  /// Executa a ação e SEMPRE recarrega a agenda depois (sucesso ou erro).
  Future<ResultadoAcao> _acao(Future<Object?> Function() chamada, String sucesso) async {
    if (_executando) return const ResultadoAcao.erro('Aguarde a ação em andamento.');
    _executando = true;
    notifyListeners();
    ResultadoAcao resultado;
    try {
      await chamada();
      resultado = ResultadoAcao.ok(sucesso);
    } catch (e) {
      final erro = ApiErrorMapper.deErro(e);
      resultado = ResultadoAcao.erro(erro.mensagem, conflito: erro.tipo == ApiErrorTipo.conflito);
    }
    _executando = false;
    if (!descartado) await carregar();
    return resultado;
  }
}
