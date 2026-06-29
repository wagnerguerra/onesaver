import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/home_screen.dart';
import 'state/providers.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: OneSaverApp()));
}

class OneSaverApp extends ConsumerStatefulWidget {
  const OneSaverApp({super.key});

  @override
  ConsumerState<OneSaverApp> createState() => _OneSaverAppState();
}

class _OneSaverAppState extends ConsumerState<OneSaverApp> {
  @override
  void initState() {
    super.initState();
    // Inicializa anúncios e compras em segundo plano (não bloqueia a UI).
    // O PurchaseService faz auto-restore do premium ao iniciar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adsServiceProvider).init();
      ref.read(purchaseServiceProvider).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneSaver',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
