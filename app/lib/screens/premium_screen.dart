import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme.dart';

/// Tela do plano "Remover anúncios" — compra única vitalícia + restauração.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _busy = false;

  Future<void> _buy() async {
    setState(() => _busy = true);
    try {
      final ok = await ref.read(purchaseServiceProvider).buy();
      if (!ok && mounted) {
        _snack('Compra indisponível no momento. Tente novamente mais tarde.');
      }
    } catch (_) {
      if (mounted) _snack('Não foi possível iniciar a compra.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      await ref.read(purchaseServiceProvider).restore();
      if (mounted && !ref.read(premiumProvider)) {
        _snack('Nenhuma compra anterior encontrada nesta conta Google.');
      }
    } catch (_) {
      if (mounted) _snack('Não foi possível restaurar agora.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final premium = ref.watch(premiumProvider);
    final svc = ref.read(purchaseServiceProvider);

    // Ao virar premium, confirma e volta para a tela anterior.
    ref.listen<bool>(premiumProvider, (prev, next) {
      if (next && (prev == false) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anúncios removidos. Obrigado! 💜')),
        );
        Navigator.of(context).maybePop();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Remover anúncios')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Center(child: BrandLogo(size: 80)),
              const SizedBox(height: 24),
              Text(
                premium ? 'Você já é premium 💜' : 'OneSaver sem anúncios',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                premium
                    ? 'Obrigado pelo apoio! Seus downloads são liberados na hora, '
                        'sem anúncios.'
                    : 'Pague uma vez e baixe sempre direto, sem precisar assistir '
                        'anúncios. Vale para sempre nesta conta Google.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 28),
              _benefit(context, Icons.block, 'Zero anúncios antes do download'),
              _benefit(context, Icons.bolt, 'Downloads liberados na hora'),
              _benefit(context, Icons.favorite, 'Apoia o desenvolvimento do app'),
              _benefit(context, Icons.all_inclusive,
                  'Compra única, vitalícia — sem mensalidade'),
              const SizedBox(height: 32),
              if (!premium) ...[
                GradientButton(
                  onPressed: _busy ? null : _buy,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Remover anúncios — ${svc.price}'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy ? null : _restore,
                  child: const Text('Já comprei — restaurar compra'),
                ),
                const SizedBox(height: 8),
                Text(
                  'A restauração recupera sua compra automaticamente se você '
                  'trocar de aparelho ou reinstalar o app, usando a mesma '
                  'conta Google.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ] else
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Voltar'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _benefit(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
