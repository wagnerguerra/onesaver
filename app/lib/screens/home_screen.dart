import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../config.dart';
import '../models/media.dart';
import '../state/providers.dart';
import '../utils/instagram_url.dart';
import 'downloads_screen.dart';
import 'preview_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  StreamSubscription<List<SharedMediaFile>>? _shareSub;
  String? _lastHandled; // evita reprocessar o mesmo link

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initShareIntent();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // --- Share sheet (receive_sharing_intent) ---

  void _initShareIntent() {
    // App já aberto: stream de compartilhamentos.
    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleShared,
      onError: (Object _) {},
    );
    // App aberto a partir de um compartilhamento.
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _handleShared(files);
      // Libera o intent inicial para não reprocessar em hot-restart.
      ReceiveSharingIntent.instance.reset();
    });
  }

  void _handleShared(List<SharedMediaFile> files) {
    for (final f in files) {
      // Para texto/URL compartilhados, o conteúdo vem em `path`.
      final url = extractInstagramUrl(f.path);
      if (url != null) {
        _consumeUrl(url);
        return;
      }
    }
  }

  // --- Clipboard (fallback) ---

  // Android só permite ler o clipboard com o app em foco (onWindowFocusChanged).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkClipboard();
  }

  Future<void> _checkClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null) return;
    final url = extractInstagramUrl(text);
    if (url != null && url != _lastHandled && mounted) {
      setState(() => _controller.text = url);
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() => _controller.text = data!.text!.trim());
    }
  }

  // --- Resolução ---

  /// Preenche o campo com [url] e dispara a resolução automaticamente.
  void _consumeUrl(String url) {
    if (url == _lastHandled) return;
    _lastHandled = url;
    _controller.text = url;
    // Garante que rode após o frame atual (pode vir do initial intent).
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    FocusScope.of(context).unfocus();
    await ref.read(resolveControllerProvider.notifier).resolve(url);

    final state = ref.read(resolveControllerProvider);
    if (!mounted) return;
    state.when(
      data: (result) {
        if (result != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PreviewScreen(result: result)),
          );
        }
      },
      error: (err, _) => _showError(err),
      loading: () {},
    );
  }

  void _showError(Object err) {
    final msg =
        err is ResolveException ? err.message : 'Erro ao resolver o link.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(resolveControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OneSaver'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_done_outlined),
            tooltip: 'Downloads',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DownloadsScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Compartilhe um reel pelo Instagram (Compartilhar → OneSaver) '
              'ou cole o link abaixo.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'https://www.instagram.com/reel/...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste),
                  tooltip: 'Colar',
                  onPressed: _paste,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: isLoading ? null : _resolve,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(isLoading ? 'Buscando...' : 'Buscar vídeo'),
            ),
            const Spacer(),
            if (AppConfig.useStub)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.science_outlined, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Modo STUB ativo: dados de exemplo, sem backend real.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
