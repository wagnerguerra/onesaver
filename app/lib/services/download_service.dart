import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../models/media.dart';

/// Baixa a mídia para arquivo temporário e salva na galeria do dispositivo.
class DownloadService {
  DownloadService([Dio? dio]) : _dio = dio ?? Dio();
  final Dio _dio;

  /// Faz o download de [media], reportando progresso em 0.0–1.0.
  /// Retorna o caminho temporário salvo. Lança em caso de falha.
  Future<String> download(
    MediaItem media, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${dir.path}/onesaver_$stamp.${media.ext}';

    await _dio.download(
      media.url,
      path,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    // Garante permissão e salva na galeria (Movies/álbum OneSaver).
    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      await Gal.requestAccess();
    }
    await Gal.putVideo(path, album: 'OneSaver');
    return path;
  }
}
