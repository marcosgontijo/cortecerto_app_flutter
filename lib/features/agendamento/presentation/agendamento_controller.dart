import 'package:flutter/foundation.dart';

import '../../../core/state/notificador_seguro.dart';

import '../../../core/errors/api_exception.dart';
import '../../servicos/domain/servico.dart';
import '../data/agendamento_api.dart';
import '../domain/agendamento_confirmado.dart';

class AgendamentoController extends ChangeNotifier with NotificadorSeguro {
  AgendamentoController(this._api);

  static const msgHorarioReservado =
      'Horário acabou de ser reservado. Escolha outro horário.';

  final AgendamentoApi _api;

  DateTime? _dia;
  List<String> _horarios = const [];
  bool _carregandoHorarios = false;
  String? _erroHorarios;
  String? _horario;
  bool _enviando = false;
  String? _erroEnvio;
  String? _aviso;
  int _requisicao = 0;

  DateTime? get diaSelecionado => _dia;
  List<String> get horarios => _horarios;
  bool get carregandoHorarios => _carregandoHorarios;
  String? get erroHorarios => _erroHorarios;
  String? get horarioSelecionado => _horario;
  bool get enviando => _enviando;
  String? get erroEnvio => _erroEnvio;

  /// Aviso não fatal (ex.: horário reservado por outra pessoa).
  String? get aviso => _aviso;

  bool get podeConfirmar => _dia != null && _horario != null && !_enviando;

  Future<void> selecionarDia(DateTime dia) async {
    _dia = DateTime(dia.year, dia.month, dia.day);
    _horario = null;
    _aviso = null;
    _erroEnvio = null;
    await _carregarHorarios();
  }

  Future<void> recarregarHorarios() async {
    if (_dia == null) return;
    await _carregarHorarios();
  }

  void selecionarHorario(String horario) {
    _horario = horario;
    _erroEnvio = null;
    notifyListeners();
  }

  /// Envia o agendamento. Retorna o resumo em caso de sucesso, ou `null`.
  Future<AgendamentoConfirmado?> confirmar(Servico servico) async {
    final dia = _dia;
    final horario = _horario;
    if (dia == null || horario == null || _enviando) return null;
    _enviando = true;
    _erroEnvio = null;
    _aviso = null;
    notifyListeners();
    try {
      await _api.agendar(data: dia, horario: horario, servico: servico);
      return AgendamentoConfirmado(
        servico: servico.tipoServico,
        data: dia,
        horario: horario,
      );
    } catch (e) {
      final erro = ApiErrorMapper.deErro(e);
      if (erro.tipo == ApiErrorTipo.conflito) {
        _aviso = msgHorarioReservado;
        _horario = null;
        _enviando = false;
        await _carregarHorarios();
      } else {
        _erroEnvio = erro.mensagem;
      }
      return null;
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }

  Future<void> _carregarHorarios() async {
    final dia = _dia;
    if (dia == null) return;
    final requisicao = ++_requisicao;
    _carregandoHorarios = true;
    _erroHorarios = null;
    _horarios = const [];
    notifyListeners();
    try {
      final horarios = await _api.disponibilidades(dia);
      if (requisicao != _requisicao) return; // resposta de um dia antigo
      _horarios = horarios;
    } catch (e) {
      if (requisicao != _requisicao) return;
      _erroHorarios = ApiErrorMapper.deErro(e).mensagem;
    } finally {
      if (requisicao == _requisicao) {
        _carregandoHorarios = false;
        notifyListeners();
      }
    }
  }
}
