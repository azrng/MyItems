import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/actions.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/common.dart';
import 'cloud_sync_section.dart';

/// 存储与备份（requirement.md §5.11 / §7.1）。
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  ({int db, int images, int backups, int cache})? _usage;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    final usage = await ref.read(inventoryActionsProvider).storageUsage();
    if (mounted) setState(() => _usage = usage);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final settings = ref.watch(settingsProvider);
    final info = settings;
    final u = _usage;

    return SubPage(
      title: '存储与备份',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding, 10, AppTheme.pagePadding, 60),
        children: [
          // 本地占用卡片
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('本地占用',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    if (u != null)
                      Text(Fmt.bytes(u.db + u.images + u.backups + u.cache),
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: scheme.onPrimaryContainer)),
                  ],
                ),
                const SizedBox(height: 12),
                if (u == null)
                  const Center(child: CircularProgressIndicator())
                else
                  Column(
                    children: [
                      _usageRow('🗄 数据库与记录', u.db, scheme),
                      _usageRow('🖼 物品图片', u.images, scheme),
                      _usageRow('💾 自动备份', u.backups, scheme),
                      Row(
                        children: [
                          Expanded(child: _usageRow('🧹 缓存', u.cache, scheme)),
                          InkWell(
                            onTap: () async {
                              await ref
                                  .read(inventoryActionsProvider)
                                  .clearCache();
                              await _loadUsage();
                              if (context.mounted) showToast(context, '缓存已清理');
                            },
                            child: Text('一键清理',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: scheme.onPrimaryContainer)),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // 本地备份分区（§7.1 本机通道）
          _groupLabel('本地备份', c),
          SwitchRow(
            title: '自动备份',
            subtitle: '每日首次启动补做 + 变更后 30 秒防抖，写应用私有目录',
            value: settings.autoBackupEnabled,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setAutoBackup(enabled: v),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () async {
              final n = await _pickKeepCount(context, settings.backupKeepCount);
              if (n != null) {
                await ref
                    .read(settingsProvider.notifier)
                    .setAutoBackup(keepCount: n);
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  const Text('保留版本数',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('最近 ${settings.backupKeepCount} 份',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: scheme.onPrimaryContainer)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // 状态行
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: info.lastBackupOk
                  ? scheme.surfaceContainerLowest
                  : scheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: info.lastBackupOk
                      ? scheme.outlineVariant
                      : scheme.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Text(info.lastBackupOk ? '✓' : '✕',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: info.lastBackupOk ? c.olive : scheme.error)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    info.lastBackupOk
                        ? (info.lastBackupAt == null
                            ? '还没有本地备份'
                            : '上次本地备份：${Fmt.relative(info.lastBackupAt!, DateTime.now())}'
                                '${info.lastBackupSize == null ? '' : ' · ${Fmt.bytes(info.lastBackupSize!)}'} · 校验通过')
                        : (info.lastBackupError.isEmpty
                            ? '上次本地备份失败'
                            : '上次本地备份失败：${info.lastBackupError}'),
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: info.lastBackupOk ? c.inkFaint : scheme.error),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await ref
                        .read(inventoryActionsProvider)
                        .runAutoBackupNow();
                    if (context.mounted) showToast(context, '备份完成');
                  },
                  child: const Text('立即备份'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 导出按钮组
          FilledButton(
            onPressed: _exporting ? null : () => _export(context),
            child: _exporting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('完整备份（ZIP · 数据 + 图片）'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _exporting ? null : () => _export(context, share: true),
            child: const Text('分享给家人的其他设备'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _restore(context),
            child: const Text('从备份文件恢复'),
          ),
          const SizedBox(height: 18),
          // 云端备份分区（§7.2 云端通道）
          _groupLabel('云端备份（坚果云）', c),
          const CloudSyncSection(),
          const SizedBox(height: 18),
          Center(
            child: Text('🔒 备份默认仅存本地设备；仅在你配置坚果云后才会推送，且直连坚果云官方接口',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: c.inkFaint)),
          ),
        ],
      ),
    );
  }

  /// 分区标题，样式对齐我的页 `_groupLabel`（mine_page.dart）。
  Widget _groupLabel(String text, AppColors c) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 0, 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w900,
                color: c.inkFaint)),
      );

  Widget _usageRow(String label, int bytes, ColorScheme scheme) {
    final total = (_usage == null
            ? 1
            : (_usage!.db + _usage!.images + _usage!.backups + _usage!.cache))
        .clamp(1, 1 << 40);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 118,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: bytes / total,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor:
                    AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 56,
            child: Text(Fmt.bytes(bytes),
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, {bool share = false}) async {
    setState(() => _exporting = true);
    try {
      final file =
          await ref.read(inventoryActionsProvider).exportNow();
      if (share && context.mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: '暖仓完整备份（${Fmt.date(DateTime.now())}）',
        );
      } else if (context.mounted) {
        showToast(context, '已导出：${file.path.split(Platform.pathSeparator).last}');
      }
    } catch (e) {
      if (context.mounted) showToast(context, '导出失败：$e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _restore(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: '从备份恢复？',
      content: '恢复会用备份内容覆盖当前手机数据。\n覆盖前会自动导出一份当前数据的备份作为后悔药。',
      confirmText: '选择备份文件',
      danger: true,
    );
    if (!ok) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (picked == null || picked.files.single.path == null) return;
    try {
      await ref
          .read(inventoryActionsProvider)
          .restore(File(picked.files.single.path!));
      if (context.mounted) showToast(context, '恢复完成，数据已覆盖');
    } catch (e) {
      if (context.mounted) showToast(context, '恢复失败：$e');
    }
  }

  Future<int?> _pickKeepCount(BuildContext context, int current) {
    return showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        title: const Text('保留最近几份备份',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        children: [
          for (final n in [3, 5, 7, 10])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, n),
              child: Text(
                n == current ? '✓ 最近 $n 份' : '最近 $n 份',
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}
