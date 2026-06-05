import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_store.dart';
import 'models.dart';
import 'pages.dart';
import 'repository.dart';

void main() {
  runApp(MyItemsApp(store: AppStore(SqliteItemRepository())));
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
      seedColor: const Color(0xFF0EA5E9),
      primary: const Color(0xFF0EA5E9),
      secondary: const Color(0xFF22C55E),
      tertiary: const Color(0xFFF59E0B),
      surface: const Color(0xFFFFFFFF),
    );
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF38BDF8),
      brightness: Brightness.dark,
      primary: const Color(0xFF38BDF8),
      secondary: const Color(0xFF4ADE80),
      tertiary: const Color(0xFFFBBF24),
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
            theme: _buildTheme(lightColorScheme, const Color(0xFFFAFBFD)),
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
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: colorScheme.surface.withAlpha(245),
        indicatorColor: colorScheme.primaryContainer.withAlpha(150),
        labelTextStyle: MaterialStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withAlpha(100),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
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
