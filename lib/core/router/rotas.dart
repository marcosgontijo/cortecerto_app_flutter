/// Caminhos e nomes das rotas do app.
class Rotas {
  Rotas._();

  static const login = '/login';
  static const cadastro = '/cadastro';
  static const servicos = '/servicos';
  static const agendamento = '/agendamento';
  static const agendamentoConfirmado = '/agendamento/confirmado';
  static const produtos = '/produtos';
  static const admin = '/admin';
  static const adminAgenda = '/admin/agenda';
  static const adminAgendamentoForm = '/admin/agenda/form';
  static const adminFaturamento = '/admin/faturamento';
  static const meusAgendamentos = '/meus-agendamentos';

  static const nomeLogin = 'login';
  static const nomeCadastro = 'cadastro';
  static const nomeServicos = 'servicos';
  static const nomeAgendamento = 'agendamento';
  static const nomeAgendamentoConfirmado = 'agendamento-confirmado';
  static const nomeProdutos = 'produtos';
  static const nomeAdmin = 'admin';
  static const nomeAdminAgenda = 'admin-agenda';
  static const nomeAdminAgendamentoForm = 'admin-agendamento-form';
  static const nomeAdminFaturamento = 'admin-faturamento';
  static const nomeMeusAgendamentos = 'meus-agendamentos';

  static const publicas = {login, cadastro};

  /// `/admin` e tudo abaixo dele (`/admin/agenda`, ...): só ADMIN.
  static bool isAdmin(String local) => local == admin || local.startsWith('$admin/');
}
