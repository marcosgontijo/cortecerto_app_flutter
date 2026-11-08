import 'dart:convert';

/// Claims do JWT emitido pelo backend: `{id, role, name, sub, iat, exp}`.
class JwtPayload {
  const JwtPayload({this.id, this.role, this.name, this.exp});

  final int? id;
  final String? role;
  final String? name;

  /// Expiração (UTC). `null` quando o token não tem `exp`.
  final DateTime? exp;

  /// Decodifica o payload (sem validar assinatura; isso é papel do backend).
  /// Retorna `null` se o token estiver malformado.
  static JwtPayload? tryParse(String token) {
    final partes = token.split('.');
    if (partes.length != 3) return null;
    try {
      final json = utf8.decode(base64Url.decode(base64Url.normalize(partes[1])));
      final mapa = jsonDecode(json);
      if (mapa is! Map<String, dynamic>) return null;
      final exp = mapa['exp'];
      final id = mapa['id'] ?? int.tryParse('${mapa['sub']}');
      return JwtPayload(
        id: id is int ? id : (id is num ? id.toInt() : null),
        role: mapa['role']?.toString(),
        name: mapa['name']?.toString(),
        exp: exp is num
            ? DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true)
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Token sem `exp` é tratado como expirado (não dá para confiar nele).
  bool isExpired(DateTime agora) {
    final e = exp;
    if (e == null) return true;
    return !agora.toUtc().isBefore(e);
  }
}
