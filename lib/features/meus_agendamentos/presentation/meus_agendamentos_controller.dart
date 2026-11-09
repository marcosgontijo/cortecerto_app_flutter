import 'package:flutter/foundation.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/state/notificador_seguro.dart';
import '../../agendamento/data/agendamento_api.dart';
import '../../agendamento/domain/status_agendamento.dart';
import '../domain/meu_agendamento.dart';

/// Meus Agendamentos do cliente. Sem cache: cada [carregar] busca no servidor.
class MeusAgendamentosController extends ChangeNotifier with NotificadorSeguro {
  MeusAgendamentosController(this._api, {DateTime Function()? relogio})
      : _relogio = relogio ?? DateTime.now;

  final AgendamentoApi _api;
  final DateTime Function() _relogio;

  List<MeuAgendamento> _itens = const [];
  bool _isLoading = false;
  bool _carregou = false;
  String? _erro;
  int? _cancelando;
  int _requisicao = 0;

  bool get isLoading => _isLoading;
  bool get carregou => _carregou;
  String? get erro => _erro;
  List<MeuAgendamento> get itens => _itens;

  /// Id do agendamento sendo cancelado (para desabilitar o botão).
  int? get cancelando => _cancelando;

  bool _ehProximo(MeuAgendamento a) =>
      !a.dataHoraInicio.isBefore(_relogio()) &&
      (a.status == StatusAgendamento.pendente || a.status == StatusAgendamento.confirmado);

  /// Futuros ainda ativos, do mais próximo para o mais distante.
  List<MeuAgendamento> get proximos =>
      _itens.where(_ehProximo).toList()..sort((a, b) => a.dataHoraInicio.compareTo(b.dataHoraInicio));

  /// Passados, cancelados e realizados, mais recentes primeiro.
  List<MeuAgendamento> get historico =>
      _itens.where((a) => !_ehProximo(a)).toList()
        ..sort((a, b) => b.dataHoraInicio.compareTo(a.dataHoraInicio));

  /// O cliente só cancela o próprio agendamento futuro e ainda ativo (regra do backend).
  bool podeCancelar(MeuAgendamento a) => _ehProximo(a);

  Future<void> carregar() async {
    final req = ++_requisicao;
    _isLoading = true;
    _erro = null;
    notifyListeners();
    try {
      final lista = await _api.meus();
      if (req != _requisicao) return;
      _itens = lista;
      _carregou = true;
    } catch (e) {
      if (req != _requisicao) return;
      _erro = ApiErrorMapper.deErro(e).mensagem;
    } finally {
      if (req == _requisicao) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Mensagem devolvida quando já há um cancelamento em andamento (nada foi cancelado).
  static const mensagemAguarde = 'Aguarde o cancelamento em andamento.';

  /// Cancela e recarrega a lista. Retorna a mensagem de erro, ou `null` se deu certo.
  /// Com outro cancelamento em andamento não chama a API e devolve [mensagemAguarde].
  Future<String?> cancelar(MeuAgendamento a) async {
    if (_cancelando != null) return mensagemAguarde;
    _cancelando = a.id;
    notifyListeners();
    String? erro;
    try {
      await _api.cancelar(a.id);
    } catch (e) {
      erro = ApiErrorMapper.deErro(e).mensagem;
    }
    _cancelando = null;
    if (!descartado) await carregar();
    return erro;
  }
}
