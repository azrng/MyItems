import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_store.dart';
import 'models.dart';
import 'pages.dart';
import 'repository.dart';

void main() {
  runApp(MyItemsApp(store: AppStore(ItemRepository())));
}

class MyItemsApp extends StatefulWidget {
  const MyItemsApp({super.key, required this.store});

  final AppStore store;

  @override
  State<MyItemsApp> createState() => _MyItemsAppState();
}

class _MyItemsAppState extends State<MyItemsApp> {
  @override
  void initState() {
    super.initState();
    widget.store.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF6B6B),
      primary: const Color(0xFFFF6B6B),
      secondary: const Color(0xFF4ECDC4),
      surface: const Color(0xFFF8FAFC),
    );
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF8A80),
      brightness: Brightness.dark,
      primary: const Color(0xFFFF8A80),
      secondary: const Color(0xFF4ECDC4),
      surface: const Color(0xFF111827),
    );

    return AppScope(
      store: widget.store,
      child: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          return MaterialApp(
            title: '我的物品',
            debugShowCheckedModeBanner: false,
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [
              Locale('zh', 'CN'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: _themeModeOf(widget.store.themePreference),
            theme: _buildTheme(lightColorScheme, const Color(0xFFF8FAFC)),
            darkTheme: _buildTheme(darkColorScheme, const Color(0xFF0F172A)),
            home: const RootPage(),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(ColorScheme colorScheme, Color scaffoldBackground) {
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scaffoldBackground,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );
  }

  ThemeMode _themeModeOf(ThemePreference preference) {
    return switch (preference) {
      ThemePreference.system => ThemeMode.system,
      ThemePreference.light => ThemeMode.light,
      ThemePreference.dark => ThemeMode.dark,
    };
  }
}

class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({
    super.key,
    required AppStore store,
    required super.child,
  }) : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.notifier!;
  }
}
