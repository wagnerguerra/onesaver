import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../models/media.dart';
import '../state/providers.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({super.key, required this.result});
  final ResolveResult result;

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  late MediaItem _selected = widget.result.best;
  double? _progress; // null = ocioso

  Future<void> _download() async {
    setState(() => _progress = 0);
    try {
      final path = await ref.read(downloadServiceProvider).download(
            _selected,
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
      ref.read(downloadsProvider.notifier).add(
            DownloadEntry(
              title: widget.result.title ?? widget.result.shortcode,
              quality: _selected.quality,
              filePath: path,
              thumbnail: widget.result.thumbnail,
            ),
          );
      // Reproduz o arquivo baixado no player do sistema.
      final opened = await OpenFilex.open(path, type: 'video/mp4');
      if (mounted) {
        final ok = opened.type == ResultType.done;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? 'Salvo na galeria. Abrindo o vídeo…'
                : 'Salvo na galeria. Não abriu: ${opened.message}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha no download: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final downloading = _progress != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Pré-visualização')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              children: [
          if (r.thumbnail != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: Image.network(
                  r.thumbnail!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.black12,
                    child: const Icon(Icons.image_not_supported, size: 48),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            r.title ?? r.shortcode,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (r.author != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('@${r.author}',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          const SizedBox(height: 20),
          Text('Qualidade', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          ...r.medias.map(
            (m) => RadioListTile<MediaItem>(
              value: m,
              groupValue: _selected,
              onChanged: downloading
                  ? null
                  : (v) => setState(() => _selected = v!),
              title: Text('${m.quality} • ${m.ext.toUpperCase()}'),
              subtitle: m.readableSize.isEmpty ? null : Text(m.readableSize),
              dense: true,
            ),
          ),
              ],
            ),
          ),
          // Área de ação fixa no rodapé, acima da barra de navegação do sistema.
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (downloading) ...[
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                          '${((_progress ?? 0) * 100).toStringAsFixed(0)}%'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: downloading ? null : _download,
                      icon: const Icon(Icons.download),
                      label: Text(
                          downloading ? 'Baixando...' : 'Baixar na galeria'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
