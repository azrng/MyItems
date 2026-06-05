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
            titleSpacing: 0,
            shape: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.primaryContainer
                    .withAlpha(90),
              ),
            ),
            title: const Row(
              children: [
                Text('🗃️', style: TextStyle(fontSize: 18)),
                SizedBox(width: 8),
                Text(
                  '极简物品管理',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withAlpha(90),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withAlpha(35),
                      ),
                    ),
                    child: Text(
                      _title,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
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
        );
      },
    );
  }

  String get _title => switch (_index) {
        0 => '主页',
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
      width: 292,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withAlpha(120),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🥛 美学整理指南',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                    '物归原位，优先处理临期物品，保持库存轻盈可见。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                children: [
                  _DrawerAction(
                    icon: Icons.add_box_outlined,
                    title: '添加',
                    onTap: () => onNavigate(DrawerTarget.add),
                  ),
                  _DrawerAction(
                    icon: Icons.storage_outlined,
                    title: '存储管理',
                    onTap: () => onNavigate(DrawerTarget.storage),
                  ),
                  _DrawerAction(
                    icon: Icons.place_outlined,
                    title: '存放位置',
                    onTap: () => onNavigate(DrawerTarget.locations),
                  ),
                  _DrawerAction(
                    icon: Icons.archive_outlined,
                    title: '耗尽归档',
                    onTap: () => onNavigate(DrawerTarget.archived),
                  ),
                  _DrawerAction(
                    icon: Icons.history_outlined,
                    title: '消耗记录',
                    onTap: () => onNavigate(DrawerTarget.consumptionRecords),
                  ),
                  _DrawerAction(
                    icon: Icons.info_outline,
                    title: '关于',
                    onTap: () => onNavigate(DrawerTarget.about),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerAction extends StatelessWidget {
  const _DrawerAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: Theme.of(context).colorScheme.surfaceContainerHighest
            .withAlpha(70),
        onTap: onTap,
      ),
    );
  }
}
