import 'dart:typed_data';
import 'dart:ui' show Rect;

/// Compartilha um arquivo gerado no app pela folha de compartilhamento do sistema (FASE 6).
///
/// A tela recebe esta abstração por Provider (registrada em `lib/app.dart`), para os testes
/// usarem um fake. A implementação real ([ExportadorSharePlus]) é a única que conhece o
/// pacote `share_plus`.
abstract class ExportadorArquivo {
  const ExportadorArquivo();

  /// Abre a folha de compartilhamento com o arquivo [nomeArquivo] ([bytes], tipo [mimeType]).
  ///
  /// [assunto] vira o assunto/título da folha (e-mail etc.). [origem] é o retângulo do botão
  /// (âncora do popover no iPad), em coordenadas globais.
  ///
  /// Termina normalmente quando o usuário compartilha **ou fecha a folha** (fechar não é erro).
  /// Lança exceção se não foi possível gerar/compartilhar.
  Future<void> compartilhar({
    required String nomeArquivo,
    required Uint8List bytes,
    required String mimeType,
    required String assunto,
    Rect? origem,
  });
}
