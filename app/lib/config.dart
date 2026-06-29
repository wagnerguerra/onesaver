/// Configuração de build do app.
class AppConfig {
  /// Quando `true`, usa o [StubResolveService] (dados falsos, sem backend).
  /// Troque para `false` (ou passe --dart-define) quando o backend estiver pronto.
  static const bool useStub =
      bool.fromEnvironment('USE_STUB', defaultValue: true);

  /// Base URL do backend. No emulador Android, o host da máquina é 10.0.2.2.
  /// Em device físico, use o IP da sua máquina na rede local.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Chave enviada no header X-API-Key quando o backend exige (ONESAVER_API_KEY).
  /// Vazia = não envia o header.
  static const String apiKey = String.fromEnvironment('API_KEY', defaultValue: '');

  // --- Anúncios (AdMob) ---

  /// Quando `true`, usa os blocos de teste oficiais do Google (não geram
  /// receita e são seguros para desenvolvimento). Para o release de verdade,
  /// passe `--dart-define USE_TEST_ADS=false` junto com os IDs reais.
  static const bool useTestAds =
      bool.fromEnvironment('USE_TEST_ADS', defaultValue: true);

  /// ID real do bloco recompensado (rewarded), do painel do AdMob.
  static const String _rewardedReal =
      String.fromEnvironment('ADMOB_REWARDED_ID', defaultValue: '');

  /// Bloco recompensado em uso. Cai no ID de teste oficial do Google (Android)
  /// quando em modo de teste ou sem ID real configurado.
  static String get rewardedAdUnitId => useTestAds || _rewardedReal.isEmpty
      ? 'ca-app-pub-3940256099942544/5224354917' // teste oficial Android
      : _rewardedReal;

  // --- Compra: remover anúncios (compra única vitalícia) ---

  /// ID do produto não-consumível configurado no Google Play Console.
  static const String removeAdsProductId =
      String.fromEnvironment('REMOVE_ADS_PRODUCT_ID', defaultValue: 'remove_ads');

  /// Preço exibido como fallback quando a loja ainda não retorna o produto
  /// (ex.: em dev, sem produto publicado). A loja é sempre a fonte da verdade.
  static const String removeAdsFallbackPrice =
      String.fromEnvironment('REMOVE_ADS_PRICE', defaultValue: r'R$ 5,90');
}
