import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Gerencia a compra única "remover anúncios" e sua restauração.
///
/// O estado premium é persistido localmente ([SharedPreferences]) para resposta
/// imediata, e reconciliado com a Play Store no início (auto-restore silencioso)
/// e a cada atualização do [InAppPurchase.purchaseStream]. A restauração é
/// nativa, atrelada à conta Google — não exige backend nem login próprio.
class PurchaseService {
  PurchaseService(this._onPremiumChanged);

  /// Chamado sempre que o status premium muda (para refletir no estado do app).
  final void Function(bool premium) _onPremiumChanged;

  static const String _prefKey = 'premium_remove_ads';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;
  bool _premium = false;
  bool _storeAvailable = false;

  bool get isPremium => _premium;
  bool get storeAvailable => _storeAvailable;
  ProductDetails? get product => _product;

  /// Preço a exibir: o da loja, se disponível; senão, o fallback do config.
  String get price => _product?.price ?? AppConfig.removeAdsFallbackPrice;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _premium = prefs.getBool(_prefKey) ?? false;
    _onPremiumChanged(_premium);

    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) return;

    _sub = _iap.purchaseStream.listen(_onPurchaseUpdate, onError: (_) {});
    await _loadProduct();
    // Reconcilia silenciosamente com a loja (caso já tenha comprado antes).
    await _iap.restorePurchases();
  }

  Future<void> _loadProduct() async {
    final resp = await _iap.queryProductDetails({AppConfig.removeAdsProductId});
    if (resp.productDetails.isNotEmpty) {
      _product = resp.productDetails.first;
    }
  }

  /// Inicia a compra. Retorna `false` se o produto não estiver disponível.
  /// O resultado real chega depois pelo [purchaseStream] → [_onPurchaseUpdate].
  Future<bool> buy() async {
    final p = _product;
    if (p == null) return false;
    return _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
  }

  /// Restaura compras anteriores (botão "Restaurar compra").
  Future<void> restore() => _iap.restorePurchases();

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final pd in purchases) {
      if (pd.productID == AppConfig.removeAdsProductId &&
          (pd.status == PurchaseStatus.purchased ||
              pd.status == PurchaseStatus.restored)) {
        await _setPremium(true);
      }
      // Finaliza qualquer compra pendente para a loja não reentregar.
      if (pd.pendingCompletePurchase) {
        await _iap.completePurchase(pd);
      }
    }
  }

  Future<void> _setPremium(bool value) async {
    if (_premium == value) return;
    _premium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    _onPremiumChanged(value);
  }

  void dispose() => _sub?.cancel();
}
