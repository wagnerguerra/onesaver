/// Modelos espelhando a resposta do backend `POST /resolve`.

class MediaItem {
  const MediaItem({
    required this.quality,
    required this.ext,
    required this.url,
    this.width,
    this.height,
    this.filesize,
    this.hasAudio = true,
  });

  final String quality;
  final String ext;
  final String url;
  final int? width;
  final int? height;
  final int? filesize;
  final bool hasAudio;

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      quality: json['quality'] as String? ?? 'media',
      ext: json['ext'] as String? ?? 'mp4',
      url: json['url'] as String,
      width: json['width'] as int?,
      height: json['height'] as int?,
      filesize: json['filesize'] as int?,
      hasAudio: json['has_audio'] as bool? ?? true,
    );
  }

  /// Tamanho legível, ex.: "12.3 MB". Vazio quando desconhecido.
  String get readableSize {
    final bytes = filesize;
    if (bytes == null || bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size >= 100 || unit == 0 ? 0 : 1)} ${units[unit]}';
  }
}

class ResolveResult {
  const ResolveResult({
    required this.type,
    required this.shortcode,
    required this.medias,
    this.author,
    this.title,
    this.thumbnail,
  });

  final String type;
  final String shortcode;
  final List<MediaItem> medias;
  final String? author;
  final String? title;
  final String? thumbnail;

  /// Melhor qualidade disponível (o backend já ordena por altura desc).
  MediaItem get best => medias.first;

  factory ResolveResult.fromJson(Map<String, dynamic> json) {
    final list = (json['medias'] as List<dynamic>? ?? [])
        .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return ResolveResult(
      type: json['type'] as String? ?? 'unknown',
      shortcode: json['shortcode'] as String? ?? '',
      author: json['author'] as String?,
      title: json['title'] as String?,
      thumbnail: json['thumbnail'] as String?,
      medias: list,
    );
  }
}

/// Erro de domínio com código vindo do backend (ex.: 'auth_required').
class ResolveException implements Exception {
  const ResolveException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => message;
}
