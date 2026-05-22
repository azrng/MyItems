import 'package:flutter/material.dart';

import '../app_store.dart';
import '../main.dart';
import '../models.dart';
import 'add_item_page.dart';
import 'about_page.dart';
import 'archived_page.dart';
import 'category_page.dart';
import 'consumption_records_page.dart';
import 'expiring_page.dart';
import 'home_page.dart';
import 'library_page.dart';
import 'location_page.dart';
import 'storage_page.dart';
import '../widgets/common.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final pages = [
      const HomePage(),
      const ExpiringPage(),
      const LibraryPage(),
      const CategoryPage(),
    ];

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_title),
            actions: [
              if (_index == 0)
                IconButton(
                  tooltip: '添加物品',
                  icon: const Icon(Icons.add),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AddItemPage())),
                ),
            ],
          ),
          drawer: AppDrawer(onNavigate: (target) {
            Navigator.pop(context);
            if (target == DrawerTarget.add) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddItemPage()));
            } else if (target == DrawerTarget.storage) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const StoragePage()));
            } else if (target == DrawerTarget.locations) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LocationPage()));
            } else if (target == DrawerTarget.archived) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ArchivedItemsPage()));
            } else if (target == DrawerTarget.consumptionRecords) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ConsumptionRecordsPage()));
            } else {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AboutPage()));
            }
          }),
          body: Stack(
            children: [
              pages[_index],
              if (store.isLoading) const LinearProgressIndicator(minHeight: 2),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: '主页'),
              NavigationDestination(
                  icon: Icon(Icons.notifications_none),
                  selectedIcon: Icon(Icons.notifications),
                  label: '临期'),
              NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: '物品库'),
              NavigationDestination(
                  icon: Icon(Icons.category_outlined),
                  selectedIcon: Icon(Icons.category),
                  label: '分类'),
            ],
          ),
          floatingActionButton: _index == 2
              ? FloatingActionButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AddItemPage())),
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }

  String get _title => switch (_index) {
        0 => '我的物品',
        1 => '临期提醒',
        2 => '物品库',
        _ => '分类管理',
      };
}

enum DrawerTarget {
  add,
  storage,
  locations,
  archived,
  consumptionRecords,
  about
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.onNavigate});

  final ValueChanged<DrawerTarget> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: Theme.of(context).colorScheme.primary,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📦 我的物品',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text('物品管理助手', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('添加'),
              onTap: () => onNavigate(DrawerTarget.add),
            ),
            ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: const Text('存储管理'),
              onTap: () => onNavigate(DrawerTarget.storage),
            ),
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: const Text('存放位置'),
              onTap: () => onNavigate(DrawerTarget.locations),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('耗尽归档'),
              onTap: () => onNavigate(DrawerTarget.archived),
            ),
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text('消耗记录'),
              onTap: () => onNavigate(DrawerTarget.consumptionRecords),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('关于'),
              onTap: () => onNavigate(DrawerTarget.about),
            ),
          ],
        ),
      ),
    );
  }
}
