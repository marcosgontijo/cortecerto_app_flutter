import 'package:flutter/foundation.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/state/notificador_seguro.dart';
import '../data/admin_agendamento_api.dart';
import '../domain/faturamento.dart';
import '../domain/periodo_faturamento.dart';

/// Estado da tela Faturamento (FASE 5). Abre em **Dia = hoje**. Os dados são sempre
/// buscados no servidor: trocar de período, voltar a um período já visto, "Tentar novamente"
/// e o pull-to-refresh chamam a API de novo (sem cache).
class FaturamentoController extends ChangeNotifier with NotificadorSeguro {
  FaturamentoController(this._api, {DateTime Function()? relogio}) : _relogio = relogio ?? DateTime.now {
    _referencia = hoje;
    _periodo = PeriodoFaturamento.contendo(TipoPeriodo.dia, _referencia);
  }

  final AdminAgendamentoApi _api;
  final DateTime Function() _relogio;

  /// Data de referência: o período exibido é o do tipo escolhido que contém esta data.
  late DateTime _referencia;
  late PeriodoFaturamento _periodo;
  Faturamento? _faturamento;
  bool _isLoading = false;
  String? _erro;
  int _requisicao = 0;

  DateTime get hoje {
    final a = _relogio();
    return DateTime(a.year, a.month, a.day);
  }

  PeriodoFaturamento get periodo => _periodo;
  TipoPeriodo get tipo => _periodo.tipo;
  Faturamento? get faturamento => _faturamento;
  bool get isLoading => _isLoading;
  String? get erro => _erro;

  /// Troca Dia/Semana/Mês mantendo a data de referência (ex.: Dia 05/11 → Semana 03/11–09/11).
  Future<void> selecionarTipo(TipoPeriodo tipo) {
    if (tipo == _periodo.tipo) return carregar();
    return _irPara(PeriodoFaturamento.contendo(tipo, _referencia));
  }

  /// Período anterior: dia − 1, semana − 7 dias, mês − 1.
  Future<void> anterior() => _deslocar(-1);

  /// Próximo período: dia + 1, semana + 7 dias, mês + 1.
  Future<void> proximo() => _deslocar(1);

  Future<void> _deslocar(int passos) {
    final r = _referencia;
    switch (_periodo.tipo) {
      case TipoPeriodo.dia:
        _referencia = DateTime(r.year, r.month, r.day + passos);
      case TipoPeriodo.semana:
        _referencia = DateTime(r.year, r.month, r.day + 7 * passos);
      case TipoPeriodo.mes:
        // mesmo dia no mês vizinho, limitado ao último dia dele (31/01 → 28 ou 29/02)
        final ultimo = DateTime(r.year, r.month + passos + 1, 0).day;
        _referencia = DateTime(r.year, r.month + passos, r.day > ultimo ? ultimo : r.day);
    }
    return _irPara(PeriodoFaturamento.contendo(_periodo.tipo, _referencia));
  }

  Future<void> _irPara(PeriodoFaturamento p) {
    _periodo = p;
    if (!p.contem(_referencia)) _referencia = p.inicio;
    _faturamento = null; // não mostra os números de outro período enquanto carrega
    return carregar();
  }

  /// Busca o faturamento do período exibido (sempre no servidor).
  Future<void> carregar() async {
    final requisicao = ++_requisicao;
    final periodo = _periodo;
    _isLoading = true;
    _erro = null;
    notifyListeners();
    try {
      final f = await _api.faturamento(periodo.inicio, periodo.fim);
      if (requisicao != _requisicao) return; // resposta de um período antigo
      _faturamento = f;
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
}
