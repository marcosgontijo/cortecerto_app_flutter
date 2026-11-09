/// Grade de atendimento da barbearia (igual à do backend): 08:00 a 19:30, de 30 em 30 minutos.
///
/// Função pura usada pela Agenda Admin e pela tela de Agendamento do cliente (que
/// mostra a grade inteira e marca como indisponível o que a API não devolveu).
List<String> gerarGradeAtendimento() => [
      for (var m = 8 * 60; m <= 19 * 60 + 30; m += 30)
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}',
    ];

/// Junta a grade com os horários livres devolvidos pela API (que podem trazer algum
/// horário fora da grade) e devolve tudo em ordem.
List<String> gradeComLivres(Iterable<String> livres) =>
    {...gerarGradeAtendimento(), ...livres}.toList()..sort();
