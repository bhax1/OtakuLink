import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routes/app_router.dart';
import 'shared/themes/app_theme.dart';
import 'package:otakulink/features/settings/providers/settings_provider.dart';

class OtakuLinkApp extends ConsumerWidget {
  const OtakuLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'OtakuLink',
      darkTheme: AppTheme.darkTheme,
      theme: AppTheme.lightTheme,
      themeMode: settings.themeMode,
      builder: BotToastInit(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
