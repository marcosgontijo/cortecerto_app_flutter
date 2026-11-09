import 'package:flutter/foundation.dart';

/// Evita `notifyListeners()` depois do `dispose()`: a tela pode ser fechada enquanto uma
/// requisição ainda está em andamento e, quando ela termina, o controller já foi descartado.
mixin NotificadorSeguro on ChangeNotifier {
  bool _descartado = false;

  /// `true` depois do `dispose()`.
  bool get descartado => _descartado;

  @override
  void notifyListeners() {
    if (_descartado) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
