import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_store.dart';
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
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF6B6B),
      primary: const Color(0xFFFF6B6B),
      secondary: const Color(0xFF4ECDC4),
      surface: const Color(0xFFF8FAFC),
    );

    return AppScope(
      store: widget.store,
      child: MaterialApp(
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
        theme: ThemeData(
          colorScheme: colorScheme,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          appBarTheme: AppBarTheme(
            centerTitle: false,
            elevation: 0,
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          cardTheme: const CardThemeData(
            elevation: 0,
            color: Colors.white,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          ),
        ),
        home: const RootPage(),
      ),
    );
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
