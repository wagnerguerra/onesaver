/// Utilidades para reconhecer/extrair URLs de post/reel/tv do Instagram.

final _igUrlRegExp = RegExp(
  r'https?://(?:www\.)?instagram\.com/(?:[^/\s]+/)?(?:p|reel|reels|tv)/[A-Za-z0-9_-]+',
  caseSensitive: false,
);

/// Extrai a primeira URL do Instagram de um texto qualquer (ex.: conteúdo
/// compartilhado que vem com texto extra). Retorna `null` se não houver.
String? extractInstagramUrl(String text) {
  final match = _igUrlRegExp.firstMatch(text);
  return match?.group(0);
}

/// Indica se o texto contém uma URL de post/reel/tv do Instagram.
bool isInstagramUrl(String text) => _igUrlRegExp.hasMatch(text);
