import '../models/media.dart';
import 'resolve_service.dart';

/// Stub do /resolve: devolve dados falsos sem chamar o backend.
///
/// Os links de mídia apontam para um mp4 público de exemplo (Big Buck Bunny),
/// então o fluxo de download → salvar na galeria funciona de ponta a ponta
/// mesmo antes do backend estar pronto.
class StubResolveService implements ResolveService {
  static const _sampleMp4 =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

  @override
  Future<ResolveResult> resolve(String url) async {
    // Simula latência de rede.
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (!url.contains('instagram.com')) {
      throw const ResolveException(
        'invalid_url',
        'URL não é um post/reel do Instagram.',
      );
    }

    return const ResolveResult(
      type: 'reel',
      shortcode: 'STUB12345',
      author: 'stub_user',
      title: 'Vídeo de exemplo (stub) — backend ainda não conectado',
      thumbnail: 'https://picsum.photos/seed/onesaver/360/640',
      medias: [
        MediaItem(
          quality: '1080p',
          ext: 'mp4',
          url: _sampleMp4,
          width: 1920,
          height: 1080,
          filesize: 158008374,
        ),
        MediaItem(
          quality: '720p',
          ext: 'mp4',
          url: _sampleMp4,
          width: 1280,
          height: 720,
          filesize: 92000000,
        ),
      ],
    );
  }
}
