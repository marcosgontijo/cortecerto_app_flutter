import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

import 'exportador_arquivo.dart';

/// Implementação real do [ExportadorArquivo] com o `share_plus` (o único arquivo de `lib/`
/// que importa o pacote).
///
/// O arquivo vai em memória ([XFile.fromData]); o próprio plugin grava a cópia temporária no
/// cache do app (`cache/share_plus`) e a entrega pelo `FileProvider` dele, então não é preciso
/// `path_provider` nem permissão de armazenamento. O nome do arquivo vem de `fileNameOverrides`
/// (o `name` do `XFile.fromData` é ignorado pelo plugin).
class ExportadorSharePlus extends ExportadorArquivo {
  const ExportadorSharePlus();

  @override
  Future<void> compartilhar({
    required String nomeArquivo,
    required Uint8List bytes,
    required String mimeType,
    required String assunto,
    Rect? origem,
  }) async {
    // success, dismissed (usuário fechou a folha) e unavailable (a plataforma não informa o
    // resultado) não são erro; falha de verdade chega como exceção.
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: mimeType, name: nomeArquivo)],
      fileNameOverrides: [nomeArquivo],
      subject: assunto,
      title: assunto,
      sharePositionOrigin: origem,
    ));
  }
}
