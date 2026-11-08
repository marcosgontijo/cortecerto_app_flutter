import 'package:intl/intl.dart';

/// Formatação de datas e valores para exibição (pt-BR).
class Formatters {
  Formatters._();

  static final _moeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: r'R$',
    decimalDigits: 2,
  );

  /// `25.0` → `R$ 25,00` (o espaço é normalizado para um espaço comum).
  static String moeda(num valor) =>
      _moeda.format(valor).replaceAll(' ', ' ');

  /// Preço vindo do backend como texto (`"35.00"`, `"35,00"`). Se não der para
  /// interpretar, mostra o texto como veio.
  static String precoTexto(String? preco) {
    final bruto = (preco ?? '').trim();
    if (bruto.isEmpty) return 'Preço a consultar';
    final valor = double.tryParse(bruto.replaceAll(',', '.'));
    if (valor == null) return bruto;
    return moeda(valor);
  }

  /// `dd/MM/aaaa`.
  static String data(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  /// `AAAA-MM-DD`, formato aceito pela API.
  static String dataApi(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
}
