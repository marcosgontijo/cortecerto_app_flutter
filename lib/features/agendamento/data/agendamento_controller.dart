import 'package:flutter/material.dart';
import '../data/agendamento_api.dart';
import '../../servicos/domain/servico.dart';

class AgendamentoController extends ChangeNotifier {

  final AgendamentoApi _api = AgendamentoApi();

  bool isLoading = false;
  String? error;

  DateTime? diaSelecionado;
  String? horarioSelecionado;

  List<String> horariosDisponiveis = [];

  // CARREGA HORÁRIOS DO DIA
  Future<void> carregarHorarios(DateTime dataSelecionada) async {
    try {
      isLoading = true;
      notifyListeners();

      final lista = await _api.listarDisponibilidades(dataSelecionada);

      horariosDisponiveis = lista;
      diaSelecionado = dataSelecionada;
      horarioSelecionado = null;

    } catch (e) {
      error = "Erro ao carregar horários";
      print("ERRO DISPONIBILIDADES: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selecionarHorario(String horario) {
    horarioSelecionado = horario;
    notifyListeners();
  }

  // CONFIRMAR
  Future<bool> confirmarAgendamento(Servico servico) async {
    if (diaSelecionado == null || horarioSelecionado == null) return false;

    try {
      await _api.enviarAgendamento(
        data: diaSelecionado!,
        horario: horarioSelecionado!,
        servico: servico,
      );

      return true;
    } catch (e) {
      print("Erro ao confirmar agendamento: $e");
      return false;
    }
  }

  bool get podeConfirmar =>
      diaSelecionado != null && horarioSelecionado != null;
}