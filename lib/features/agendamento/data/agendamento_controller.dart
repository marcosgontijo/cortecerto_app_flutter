import 'package:flutter/material.dart';
import '../data/agendamento_api.dart';
import '../../servicos/domain/servico.dart';
import '../domain/dia_horario_disponivel.dart';

class AgendamentoController extends ChangeNotifier {

  final AgendamentoApi _api = AgendamentoApi();

  List<DiaHorarioDisponivel> disponibilidades = [];

  bool isLoading = false;
  String? error;

  DateTime? diaSelecionado;
  String? horarioSelecionado;

  List<String> horariosDisponiveis = [];

  Future<void> carregarDisponibilidades() async {
    try {
      isLoading = true;
      notifyListeners();

      final data = await _api.listarDisponibilidades();

      disponibilidades = data
          .map<DiaHorarioDisponivel>(
              (json) => DiaHorarioDisponivel.fromJson(json))
          .toList();

    } catch (e) {
      error = "Erro ao carregar disponibilidades";
      print("ERRO DISPONIBILIDADES: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selecionarDia(DateTime data) {
    diaSelecionado = data;
    horarioSelecionado = null;

    final dia = disponibilidades
        .where((d) => isSameDay(d.data, data))
        .firstOrNull;

    horariosDisponiveis = dia?.horarios ?? [];

    notifyListeners();
  }

  void selecionarHorario(String horario) {
    horarioSelecionado = horario;
    notifyListeners();
  }

  Future<void> confirmarAgendamento(Servico servico) async {
    if (diaSelecionado == null || horarioSelecionado == null) return;

    try {
      await _api.enviarAgendamento(
        data: diaSelecionado!,
        horario: horarioSelecionado!,
        servico: servico,
      );

      print("Agendamento realizado com sucesso");

    } catch (e) {
      print("Erro ao confirmar agendamento: $e");
    }
  }

  bool isSameDay(DateTime a, DateTime? b) {
    if (b == null) return false;

    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  bool get podeConfirmar =>
      diaSelecionado != null && horarioSelecionado != null;
}
