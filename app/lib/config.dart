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
}
