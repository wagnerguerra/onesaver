import '../models/media.dart';
import 'instagram_url.dart';

/// Traduz um erro de resolução em uma mensagem amigável para o usuário.
/// Usa o código vindo do backend ([ResolveException.code]) quando disponível.
String friendlyResolveError(Object err) {
  if (err is! ResolveException) {
    return 'Algo deu errado ao buscar o vídeo. Tente novamente.';
  }
  switch (err.code) {
    case 'invalid_url':
      return 'Esse link não é de um post, reel ou TV do Instagram. '
          'Confira e cole o endereço completo.';
    case 'no_media':
    case 'unavailable':
      return 'Não encontrei vídeo nesse link. Ele pode ser só foto, '
          'um story que expirou ou um conteúdo que saiu do ar.';
    case 'auth_required':
      return 'Esse conteúdo é privado ou exige login. Só consigo baixar '
          'vídeos de perfis públicos.';
    case 'rate_limited':
      return 'Muitas buscas em pouco tempo. Aguarde alguns segundos e '
          'tente de novo.';
    case 'extract_failed':
      return 'O Instagram não respondeu agora. Tente novamente em instantes.';
    case 'network':
      return 'Sem conexão com o servidor. Verifique sua internet e '
          'tente novamente.';
    default:
      return err.message.isNotEmpty
          ? err.message
          : 'Não consegui processar esse link. Tente outro.';
  }
}

/// Validação local (antes de ir à rede): o texto parece um link de vídeo do
/// Instagram? Retorna `null` se estiver ok, ou uma mensagem amigável se não.
String? validateInstagramInput(String text) {
  final t = text.trim();
  if (t.isEmpty) {
    return 'Cole um link do Instagram primeiro.';
  }
  if (!t.toLowerCase().contains('instagram.com')) {
    return 'Isso não parece um link do Instagram. Abra o reel, toque em '
        'compartilhar e copie o link.';
  }
  if (!isInstagramUrl(t)) {
    return 'Reconheci o Instagram, mas não um link de vídeo (reel, post ou TV). '
        'Copie o link diretamente do reel.';
  }
  return null;
}
