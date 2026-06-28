import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../models/media.dart';
import '../services/download_service.dart';
import '../services/resolve_service.dart';
import '../services/stub_resolve_service.dart';

/// Dio configurado para o backend.
final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      headers: AppConfig.apiKey.isEmpty
          ? null
          : {'X-API-Key': AppConfig.apiKey},
    ),
  );
});

/// Seleciona stub ou backend real conforme [AppConfig.useStub].
final resolveServiceProvider = Provider<ResolveService>((ref) {
  if (AppConfig.useStub) {
    return StubResolveService();
  }
  return HttpResolveService(ref.watch(dioProvider));
});

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService();
});

/// Estado da resolução de um link na Home.
class ResolveController extends AsyncNotifier<ResolveResult?> {
  @override
  ResolveResult? build() => null;

  Future<void> resolve(String url) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(resolveServiceProvider).resolve(url.trim()),
    );
  }

  void clear() => state = const AsyncData(null);
}

final resolveControllerProvider =
    AsyncNotifierProvider<ResolveController, ResolveResult?>(
  ResolveController.new,
);

/// Item baixado, exibido na aba Downloads.
class DownloadEntry {
  const DownloadEntry({
    required this.title,
    required this.quality,
    required this.path,
  });
  final String title;
  final String quality;
  final String path;
}

class DownloadsNotifier extends Notifier<List<DownloadEntry>> {
  @override
  List<DownloadEntry> build() => [];

  void add(DownloadEntry entry) => state = [entry, ...state];
}

final downloadsProvider =
    NotifierProvider<DownloadsNotifier, List<DownloadEntry>>(
  DownloadsNotifier.new,
);
