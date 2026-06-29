import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';

void _log(String msg) => debugPrint('[OneSaverAds] $msg');

/// Gerencia o anúncio recompensado (rewarded) exibido antes do download.
///
/// Filosofia "fail-open": se não houver anúncio carregado ou ele falhar ao
/// exibir, o download é liberado mesmo assim — nunca travamos o usuário por
/// causa de infraestrutura de anúncio.
class AdsService {
  RewardedAd? _ad;
  bool _loading = false;
  bool _initialized = false;

  /// Inicializa o SDK e pré-carrega o primeiro anúncio.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _log('init: inicializando MobileAds…');
    final status = await MobileAds.instance.initialize();
    final adapters = status.adapterStatuses.entries
        .map((e) => '${e.key}=${e.value.state}')
        .join(', ');
    _log('init: MobileAds pronto. unit=${AppConfig.rewardedAdUnitId} '
        'testAds=${AppConfig.useTestAds} adapters=[$adapters]');
    _preload();
  }

  void _preload() {
    if (_ad != null || _loading) return;
    _loading = true;
    _log('preload: solicitando rewarded…');
    RewardedAd.load(
      adUnitId: AppConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
          _log('preload: CARREGOU ✓');
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          _loading = false;
          _log('preload: FALHOU code=${error.code} '
              'domain=${error.domain} msg=${error.message}');
        },
      ),
    );
  }

  /// Exibe o anúncio recompensado e resolve `true` quando o usuário pode
  /// baixar: ou porque assistiu até ganhar a recompensa, ou porque não havia
  /// anúncio disponível (fail-open). Resolve `false` apenas quando o usuário
  /// fechou o anúncio antes do fim.
  Future<bool> showRewarded() async {
    final ad = _ad;
    if (ad == null) {
      _log('showRewarded: sem anúncio pronto → fail-open (libera download)');
      _preload(); // tenta deixar pronto para a próxima vez
      return true; // fail-open: não bloqueia o download
    }
    _log('showRewarded: exibindo anúncio…');
    _ad = null;

    final completer = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _preload();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _preload();
        if (!completer.isCompleted) completer.complete(true); // fail-open
      },
    );
    ad.show(onUserEarnedReward: (_, __) => earned = true);
    return completer.future;
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
