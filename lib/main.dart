import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  runApp(const ProviderScope(child: IkariamApp()));
}

/// Root application widget.
///
/// [IkariamApp] is a [ConsumerWidget] so it can read [appRouterProvider] from
/// Riverpod and pass it to [MaterialApp.router].
class IkariamApp extends ConsumerWidget {
  const IkariamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Ikariam',
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
