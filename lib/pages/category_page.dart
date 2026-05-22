import 'package:flutter/material.dart';

import '../app_store.dart';
import '../main.dart';
import '../models.dart';
import '../widgets/common.dart';
import '../widgets/item_card.dart';

const defaultCategoryIcon = '🏷️';

const categoryIconOptions = [
  '🍔', '🥛', '🍎', '💄', '🧴', '💊', '🧻', '🧼', '💻', '🔌',
  '🏠', '👕', '🎒', '📚', '⚽', '🎁', '🐱', '🚗', '🧰', defaultCategoryIcon,
];

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final _name = TextEditingController();
  String _selectedIcon = defaultCategoryIcon;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: '新增分类',
              children: [
                Row(
                  children: [
                    IconPreviewButton(
                      icon: _selectedIcon,
                      onPressed: () async {
                        final icon = await showCategoryIconPicker(
                            context, _selectedIcon);
                        if (icon != null) setState(() => _selectedIcon = icon);
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextField(
                            controller: _name,
                            decoration:
                                const InputDecoration(labelText: '分类名称'))),
                    const SizedBox(width: 12),
                    IconButton.filled(
                      onPressed: () async {
                        try {
                          await store.addCategory(_name.text, _selectedIcon);
                          _name.clear();
                          setState(() => _selectedIcon = defaultCategoryIcon);
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
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: store.categories.length,
              onReorder: (oldIndex, newIndex) async {
                try {
                  await store.reorderCategory(oldIndex, newIndex);
                } catch (error) {
                  if (context.mounted) showSnack(context, error.toString());
                }
              },
              itemBuilder: (context, index) {
                final category = store.categories[index];
                final listTile = ListTile(
                  leading: CircleAvatar(
                      child: Text(category.icon ?? defaultCategoryIcon)),
                  title: Text(category.name),
                  subtitle: Text(category.isPreset ? '预置分类' : '自定义分类'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (category.isPreset) const Icon(Icons.lock_outline),
                      IconButton(
                        tooltip: '编辑分类',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          await showCategoryEditDialog(context, category, store);
                        },
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    ],
                  ),
                );
                Widget tile = Card(
                  child: category.isPreset
                      ? listTile
                      : Dismissible(
                          key: ValueKey('category-dismiss-${category.id}'),
                          direction: DismissDirection.endToStart,
                          background: const SizedBox.shrink(),
                          secondaryBackground:
                              const SwipeDeleteBackground(label: '删除'),
                          confirmDismiss: (_) async {
                            final confirmed = await showConfirm(
                                context, '删除分类', '确定删除「${category.name}」吗？');
                            if (!confirmed) return false;
                            try {
                              await store.deleteCategory(category);
                            } catch (error) {
                              if (context.mounted) {
                                showSnack(context, error.toString());
                              }
                            }
                            return false;
                          },
                          child: listTile,
                        ),
                );
                return Padding(
                  key: ValueKey('category-row-${category.id}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: tile,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class IconPreviewButton extends StatelessWidget {
  const IconPreviewButton(
      {super.key, required this.icon, required this.onPressed});

  final String icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer.withAlpha(95),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Center(
            child: Text(icon, style: const TextStyle(fontSize: 24)),
          ),
        ),
      ),
    );
  }
}

Future<void> showCategoryEditDialog(
    BuildContext context, Category category, AppStore store) async {
  final controller = TextEditingController(text: category.name);
  var selectedIcon = category.icon ?? defaultCategoryIcon;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('编辑分类'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconPreviewButton(
                icon: selectedIcon,
                onPressed: () async {
                  final icon =
                      await showCategoryIconPicker(context, selectedIcon);
                  if (icon != null) setState(() => selectedIcon = icon);
                },
              ),
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: '分类名称'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                await store.renameCategory(
                    category, controller.text, selectedIcon);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
}

Future<String?> showCategoryIconPicker(
    BuildContext context, String selectedIcon) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('选择分类图标',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 232,
              child: GridView.builder(
                itemCount: categoryIconOptions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final icon = categoryIconOptions[index];
                  final selected = icon == selectedIcon;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context, icon),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: selected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(icon, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
