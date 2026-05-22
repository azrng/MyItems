import 'package:flutter/material.dart';

import '../app_store.dart';
import '../main.dart';
import '../models.dart';
import '../widgets/common.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('存放位置')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: '新增位置',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _name,
                          decoration: const InputDecoration(labelText: '位置名称'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        onPressed: () async {
                          try {
                            await store.addLocation(_name.text);
                            _name.clear();
                          } catch (error) {
                            if (context.mounted) {
                              showSnack(context, error.toString());
                            }
                          }
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...store.locations.map(
                (location) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(location.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '重命名',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              await showLocationEditDialog(
                                context,
                                location,
                                store,
                              );
                            },
                          ),
                          IconButton(
                            tooltip: '删除',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final confirmed = await showConfirm(
                                  context, '删除位置', '确定删除「${location.name}」吗？');
                              if (!confirmed) return;
                              await store.deleteLocation(location);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> showLocationEditDialog(
    BuildContext context, StorageLocation location, AppStore store) async {
  final controller = TextEditingController(text: location.name);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('重命名位置'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: '位置名称'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消')),
        FilledButton(
          onPressed: () async {
            await store.renameLocation(location, controller.text);
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
  controller.dispose();
}
