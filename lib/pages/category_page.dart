import 'package:flutter/material.dart';

import '../app_store.dart';
import '../main.dart';
import '../models.dart';
import '../widgets/common.dart';
import '../widgets/item_card.dart';

const defaultCategoryIcon = '🏷️';

const categoryIconOptions = [
  '🍔', '🥛', '🍎', '💄', '🧻', '🧼', '💊', '💻', '🔌',
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
            SoftCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SoftSectionHeader(
                    title: '新增分类',
                    subtitle: '划分存储区块，支持自定义标签',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconPreviewButton(
                        icon: _selectedIcon,
                        onPressed: () async {
                          final icon = await showCategoryIconPicker(
                              context, _selectedIcon);
                          if (icon != null) {
                            setState(() => _selectedIcon = icon);
                          }
                        },
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _name,
                          decoration: const InputDecoration(
                            hintText: '分类名称',
                            border: UnderlineInputBorder(),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF0EA5E9)),
                            ),
                            filled: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton.filled(
                          onPressed: () async {
                            try {
                              await store.addCategory(
                                  _name.text, _selectedIcon);
                              _name.clear();
                              setState(
                                  () => _selectedIcon = defaultCategoryIcon);
                            } catch (error) {
                              if (context.mounted) {
                                showSnack(context, error.toString());
                              }
                            }
                          },
                          icon: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SoftCard(
              padding: EdgeInsets.zero,
              child: ReorderableListView.builder(
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
                  final listTile = _CategoryTile(
                    category: category,
                    onEdit: () async {
                      await showCategoryEditDialog(context, category, store);
                    },
                    dragHandle: ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  );
                  Widget tile = category.isPreset
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
                        );
                  return Container(
                    key: ValueKey('category-row-${category.id}'),
                    decoration: BoxDecoration(
                      border: index == store.categories.length - 1
                          ? null
                          : Border(
                              bottom: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withAlpha(120),
                              ),
                            ),
                        ),
                    child: tile,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onEdit,
    required this.dragHandle,
  });

  final Category category;
  final VoidCallback onEdit;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest
              .withAlpha(120),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          category.icon ?? defaultCategoryIcon,
          style: const TextStyle(fontSize: 21),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(category.isPreset ? '预置' : '自定义',
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      subtitle: Text(category.isPreset ? '预置分类' : '自定义分类'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (category.isPreset) const Icon(Icons.lock_outline, size: 19),
          IconButton(
            tooltip: '编辑分类',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
          dragHandle,
        ],
      ),
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
