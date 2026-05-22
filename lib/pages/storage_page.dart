import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_store.dart';
import '../main.dart';
import '../widgets/common.dart';

class StoragePage extends StatefulWidget {
  const StoragePage({super.key});

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  String? _selectedBackupPath;
  String? _selectedImportPath;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('存储管理')),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                        child: Text('💾', style: TextStyle(fontSize: 52))),
                    const SizedBox(height: 8),
                    Center(
                      child: Text('管理你的数据，随时导入导出',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                    ),
                    const SizedBox(height: 18),
                    SectionCard(
                      title: '完整备份与恢复',
                      children: [
                        StorageActionTile(
                          icon: '📤',
                          title: '导出完整备份',
                          subtitle: '一键导出分类、存放位置、物品、消耗记录和设置',
                          buttonText: '导出备份',
                          onPressed: () async {
                            try {
                              final backup = await store.buildBackupFile();
                              await const MethodChannel('my_items/system')
                                  .invokeMethod<String>(
                                'saveBackupToDownloads',
                                {
                                  'fileName': backup.$1,
                                  'content': backup.$2,
                                },
                              );
                              if (context.mounted) {
                                showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('导出成功'),
                                    content: const Text(
                                      '备份已保存到：\nDownload/MyItems\n\n'
                                      '请在系统文件管理器的「下载」中查找。',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('知道了'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } catch (error) {
                              if (context.mounted) {
                                showSnack(context, '导出备份失败：$error');
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: const ['json'],
                              dialogTitle: '选择我的物品备份文件',
                            );
                            final path = result?.files.single.path;
                            if (path == null || path.trim().isEmpty) return;
                            setState(() => _selectedBackupPath = path);
                          },
                          icon: const Icon(Icons.folder_open_outlined),
                          label: const Text('选择备份文件'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedBackupPath ?? '尚未选择备份文件',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        StorageActionTile(
                          icon: '📥',
                          title: '恢复完整备份',
                          subtitle: '将备份恢复到当前手机，现有数据会被备份内容覆盖',
                          buttonText: '恢复备份',
                          onPressed: () async {
                            final path = _selectedBackupPath?.trim() ?? '';
                            if (path.isEmpty) {
                              showSnack(context, '请先选择备份文件');
                              return;
                            }
                            final confirmed = await showConfirm(
                                context, '恢复备份', '将用备份文件覆盖当前手机数据，确认继续？');
                            if (!confirmed) return;
                            if (!context.mounted) return;
                            final secondConfirmed = await showConfirm(
                                context, '二次确认', '恢复后当前数据会被替换，真的继续吗？');
                            if (!secondConfirmed) return;
                            try {
                              final result = await store.importBackup(path);
                              if (context.mounted) {
                                showSnack(context,
                                    '恢复完成：成功 ${result.$1} 条，失败 ${result.$2} 条');
                              }
                            } catch (error) {
                              if (context.mounted) {
                                showSnack(context, '恢复失败：$error');
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SectionCard(
                      title: 'CSV 兼容工具',
                      children: [
                        StorageActionTile(
                          icon: '📄',
                          title: '导出 CSV',
                          subtitle: '导出物品和分类表格，适合人工查看，不作为完整迁移备份',
                          buttonText: '导出 CSV',
                          onPressed: () async {
                            try {
                              final path = await store.exportToCsv();
                              if (context.mounted) {
                                showSnack(context, '已导出：$path');
                              }
                            } catch (error) {
                              if (context.mounted) {
                                showSnack(context, '导出 CSV 失败：$error');
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: const ['csv'],
                              dialogTitle: '选择 CSV 文件',
                            );
                            final path = result?.files.single.path;
                            if (path == null || path.trim().isEmpty) return;
                            setState(() => _selectedImportPath = path);
                          },
                          icon: const Icon(Icons.folder_open_outlined),
                          label: const Text('选择 CSV 文件'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedImportPath ?? '尚未选择 CSV 文件',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        StorageActionTile(
                          icon: '📥',
                          title: '导入 CSV',
                          subtitle: '兼容导入旧 CSV 数据，不包含消耗记录和设置',
                          buttonText: '导入 CSV',
                          onPressed: () async {
                            final path = _selectedImportPath?.trim() ?? '';
                            if (path.isEmpty) {
                              showSnack(context, '请先选择 CSV 文件');
                              return;
                            }
                            final confirmed = await showConfirm(
                                context, '导入 CSV', '将从 CSV 文件导入物品数据，确认继续？');
                            if (!confirmed) return;
                            try {
                              final result = await store.importFromCsv(path);
                              if (context.mounted) {
                                showSnack(context,
                                    '导入完成：成功 ${result.$1} 条，失败 ${result.$2} 条');
                              }
                            } catch (error) {
                              if (context.mounted) {
                                showSnack(context, '导入 CSV 失败：$error');
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SectionCard(
                      title: '危险操作',
                      children: [
                        StorageActionTile(
                          icon: '🗑️',
                          title: '清空所有数据',
                          subtitle: '删除所有物品和自定义分类，此操作不可恢复',
                          buttonText: '清空数据',
                          danger: true,
                          onPressed: () async {
                            final confirmed = await showConfirm(
                                context, '清空数据', '将删除所有物品数据，此操作不可恢复。确定继续？');
                            if (!confirmed) return;
                            if (!context.mounted) return;
                            final secondConfirmed = await showConfirm(
                                context, '二次确认', '真的要清空所有数据吗？');
                            if (!secondConfirmed) return;
                            try {
                              await store.clearAllData();
                              if (context.mounted) {
                                showSnack(context, '所有数据已清空');
                              }
                            } catch (error) {
                              if (context.mounted) {
                                showSnack(context, '清空失败：$error');
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (store.isLoading) const LinearProgressIndicator(minHeight: 2),
            ],
          ),
        );
      },
    );
  }
}

class StorageActionTile extends StatelessWidget {
  const StorageActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
    this.danger = false,
  });

  final String icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = danger ? colorScheme.error : colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: danger
            ? colorScheme.errorContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: danger ? color : null)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: danger
                                ? colorScheme.onErrorContainer
                                : colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          danger
              ? FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: color),
                  onPressed: onPressed,
                  child: Text(buttonText),
                )
              : FilledButton.tonal(
                  onPressed: onPressed,
                  child: Text(buttonText),
                ),
        ],
      ),
    );
  }
}
