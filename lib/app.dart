import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/actions.dart';
import 'providers/core_providers.dart';
import 'providers/settings_provider.dart';
import 'router/app_router.dart';

/// WarmPantry 应用根：MaterialApp.router + 浅色/深色奶油暖盘主题。
class WarmPantryApp extends ConsumerStatefulWidget {
  const WarmPantryApp({super.key});

  @override
  ConsumerState<WarmPantryApp> createState() => _WarmPantryAppState();
}

class _WarmPantryAppState extends ConsumerState<WarmPantryApp> {
  @override
  void initState() {
    super.initState();
    // 首帧后初始化平台服务与启动钩子，避免阻塞启动
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final router = ref.read(appRouterProvider);
    await ref.read(notificationServiceProvider).init(
          onNotificationTap: (String payload) {
            if (payload.isNotEmpty) router.push(payload);
          },
        );
    await ref.read(inventoryActionsProvider).onAppStart();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp.router(
      title: '暖仓 WarmPantry',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
