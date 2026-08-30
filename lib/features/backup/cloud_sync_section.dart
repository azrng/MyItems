import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/services/webdav_client.dart';
import '../../providers/actions.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/common.dart';

/// 坚果云 WebDAV 同步区块（requirement.md §7.2，交互对齐 SmartVault 数据页）：
/// 配置与测试连接 / 自动推送选项 / 立即推送 / 云端备份列表（恢复、删除）。
class CloudSyncSection extends ConsumerStatefulWidget {
  const CloudSyncSection({super.key});

  @override
  ConsumerState<CloudSyncSection> createState() => _CloudSyncSectionState();
}

class _CloudSyncSectionState extends ConsumerState<CloudSyncSection> {
  late final TextEditingController _url;
  late final TextEditingController _user;
  late final TextEditingController _token;
  SyncTestResult? _testResult;
  bool _saving = false;
  bool _testing = false;
  bool _pushing = false;
  bool _listLoading = false;
  String? _acting; // 正在恢复/删除的云端文件名，行内禁用互斥
  List<CloudBackupEntry>? _backups;
  String? _listError;
  bool _formOpen = false; // 配置表单默认折叠，点标题展开，避免密码框常驻被误触

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _url = TextEditingController(text: s.cloudSyncUrl);
    _user = TextEditingController(text: s.cloudSyncUser);
    _token = TextEditingController();
    // 已配置凭据时自动拉一次云端列表；未配置不拉，避免无谓的认证失败
    if (s.cloudSyncUser.trim().isNotEmpty && s.cloudSyncHasToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadBackups());
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _token.dispose();
    super.dispose();
  }

  bool get _credsReady {
    final s = ref.read(settingsProvider);
    return s.cloudSyncUser.trim().isNotEmpty && s.cloudSyncHasToken;
  }

  void _toggleForm() {
    FocusScope.of(context).unfocus();
    setState(() => _formOpen = !_formOpen);
  }

  Future<void> _save({bool silent = false}) async {
    setState(() => _saving = true);
    try {
      await ref.read(inventoryActionsProvider).saveCloudSyncConfig(
            url: _url.text,
            user: _user.text,
            token: _token.text,
          );
      _token.clear(); // 已保存后不再明文停留在输入框
      if (!silent && mounted) showToast(context, '配置已保存');
    } catch (e) {
      if (mounted) showToast(context, '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 先保存再测（对齐 SmartVault：测试针对已保存的凭据）。
  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      await _save(silent: true);
      final r = await ref.read(inventoryActionsProvider).testCloudSync();
      if (mounted) {
        setState(() {
          _testResult = SyncTestResult(r.ok, r.message);
          if (r.ok) _formOpen = false; // 测试通过即收起表单，回到摘要态
        });
        if (r.ok) FocusScope.of(context).unfocus();
        showToast(context, r.message);
        if (r.ok) await _loadBackups();
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _push() async {
    setState(() => _pushing = true);
    try {
      final r = await ref.read(inventoryActionsProvider).pushCloudBackup();
      if (mounted) {
        showToast(context, r.ok ? r.message : '推送失败：${r.message}');
        if (r.ok) await _loadBackups();
      }
    } finally {
      if (mounted) setState(() => _pushing = false);
    }
  }

  Future<void> _loadBackups() async {
    if (!_credsReady) return;
    setState(() {
      _listLoading = true;
      _listError = null;
    });
    try {
      final list = await ref.read(inventoryActionsProvider).loadCloudBackups();
      if (mounted) setState(() => _backups = list);
    } catch (e) {
      if (mounted) setState(() => _listError = '$e');
    } finally {
      if (mounted) setState(() => _listLoading = false);
    }
  }

  Future<void> _restore(CloudBackupEntry e) async {
    final ok = await confirmDialog(
      context,
      title: '从云端恢复？',
      content: '将下载该备份并覆盖当前手机数据。\n覆盖前会自动导出一份当前数据作为后悔药。',
      confirmText: '覆盖恢复',
      danger: true,
    );
    if (!ok) return;
    setState(() => _acting = e.name);
    try {
      await ref.read(inventoryActionsProvider).restoreCloudBackup(e.name);
      if (mounted) showToast(context, '恢复完成，数据已覆盖');
    } catch (err) {
      if (mounted) showToast(context, '恢复失败：$err');
    } finally {
      if (mounted) setState(() => _acting = null);
    }
  }

  Future<void> _delete(CloudBackupEntry e) async {
    final ok = await confirmDialog(
      context,
      title: '删除云端备份？',
      content: '删除「${e.name}」后将无法再从云端恢复这一份。',
      confirmText: '删除',
      danger: true,
    );
    if (!ok) return;
    setState(() => _acting = e.name);
    try {
      await ref.read(inventoryActionsProvider).deleteCloudBackup(e.name);
      await _loadBackups();
    } catch (err) {
      if (mounted) showToast(context, '删除失败：$err');
    } finally {
      if (mounted) setState(() => _acting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final s = ref.watch(settingsProvider);
    final configured = _credsReady;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- 配置卡（默认折叠为摘要，点标题展开表单） ----
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
              InkWell(
                onTap: _toggleForm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Text('☁️ 坚果云同步',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w900)),
                      const Spacer(),
                      _badge(scheme, c, s),
                      const SizedBox(width: 6),
                      Icon(
                        _formOpen
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 20,
                        color: c.inkFaint,
                      ),
                    ],
                  ),
                ),
              ),
              if (_formOpen) ...[
                const SizedBox(height: 10),
                _field(controller: _url, label: 'WebDAV 地址', hint: 'https://dav.jianguoyun.com/dav/'),
                const SizedBox(height: 8),
                _field(controller: _user, label: '账号', hint: '坚果云登录邮箱'),
                const SizedBox(height: 8),
                _field(
                  controller: _token,
                  label: '应用密码',
                  hint: s.cloudSyncHasToken ? '已设置，留空不修改' : '在坚果云网页生成应用密码',
                  obscure: true,
                ),
                const SizedBox(height: 10),
                Text(
                  '需在坚果云网页端「账户信息 → 安全选项 → 第三方应用管理」添加应用生成专用密码，'
                  '不能用登录密码。数据直连坚果云官方接口，不经过任何第三方服务器。',
                  style: TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w600, color: c.inkFaint),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving || _testing ? null : () => _save(),
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('保存配置'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving || _testing ? null : _test,
                        child: _testing
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('测试连接'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: _toggleForm,
                  child: configured
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('账号：${s.cloudSyncUser}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: c.inkFaint)),
                            const SizedBox(height: 2),
                            Text('地址：${s.cloudSyncUrl}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: c.inkFaint)),
                          ],
                        )
                      : Text(
                          '点按设置坚果云账号与应用密码，开启云端备份',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: c.inkFaint),
                        ),
                ),
              ],
            ],
          ),
        ),
        if (configured) ..._managedBody(scheme, c, s),
        if (!configured)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 0, 0),
            child: Text(
              '配置后可将本地备份自动推送到坚果云，并随时在其他设备从云端恢复',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: c.inkFaint),
            ),
          ),
      ],
    );
  }

  /// 已配置后的云端托管内容：自动推送开关 / 云端保留版本数 / 推送状态 / 云端备份列表。
  List<Widget> _managedBody(ColorScheme scheme, AppColors c, SettingsState s) {
    return [
      const SizedBox(height: 10),
      // ---- 自动推送选项 ----
      SwitchRow(
        title: '自动备份同时推送云端',
        subtitle: '每次本地自动备份成功后，同步上传一份到坚果云',
        value: s.cloudSyncAutoPush,
        onChanged: (v) => ref
            .read(inventoryActionsProvider)
            .setCloudSyncOptions(autoPush: v),
      ),
      const SizedBox(height: 10),
      InkWell(
        onTap: () async {
          final n = await _pickKeepCount(context, s.cloudSyncKeepCount);
          if (n != null) {
            await ref
                .read(inventoryActionsProvider)
                .setCloudSyncOptions(keepCount: n);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              const Text('云端保留版本数',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('最近 ${s.cloudSyncKeepCount} 份',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: scheme.onPrimaryContainer)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      // ---- 推送状态行 ----
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: s.cloudSyncLastAt == null || s.cloudSyncLastOk
              ? scheme.surfaceContainerLowest
              : scheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: s.cloudSyncLastAt == null || s.cloudSyncLastOk
                  ? scheme.outlineVariant
                  : scheme.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Text(
              s.cloudSyncLastAt == null ? '—' : (s.cloudSyncLastOk ? '✓' : '✕'),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: s.cloudSyncLastAt == null
                      ? c.inkFaint
                      : (s.cloudSyncLastOk ? c.olive : scheme.error)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                s.cloudSyncLastAt == null
                    ? '还没有推送过云端备份'
                    : s.cloudSyncLastOk
                        ? '上次推送：${Fmt.relative(s.cloudSyncLastAt!, DateTime.now())}'
                        : '上次推送失败：${s.cloudSyncLastError}',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: s.cloudSyncLastOk ? c.inkFaint : scheme.error),
              ),
            ),
            TextButton(
              onPressed: _pushing ? null : _push,
              child: const Text('立即推送'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      // ---- 云端备份列表 ----
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
                const Text('云端备份',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                const Spacer(),
                if (_listLoading)
                  const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _credsReady ? _loadBackups : null,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _buildListBody(scheme, c),
          ],
        ),
      ),
    ];
  }

  Widget _buildListBody(ColorScheme scheme, AppColors c) {
    if (!_credsReady) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('请先在上方配置账号与应用密码并保存',
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: c.inkFaint)),
      );
    }
    if (_listLoading && _backups == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
            child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (_listError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('读取云端列表失败：$_listError',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: scheme.error)),
      );
    }
    final list = _backups;
    if (list == null || list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('还没有云端备份，点「立即推送」上传第一份',
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: c.inkFaint)),
      );
    }
    return Column(
      children: [
        for (final e in list)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800)),
                      Text(
                        '${e.exportedAt == null ? '' : '${Fmt.date(e.exportedAt!)} ${Fmt.time(e.exportedAt!)} · '}'
                        '${Fmt.bytes(e.sizeBytes)}',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: c.inkFaint),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _acting == null ? () => _restore(e) : null,
                  child: const Text('恢复'),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _acting == null ? () => _delete(e) : null,
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 20, color: scheme.error),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _badge(ColorScheme scheme, AppColors c, SettingsState s) {
    final (String text, Color color) = switch (_badgeKind(s)) {
      _BadgeKind.unconfigured => ('未配置', c.inkFaint),
      _BadgeKind.untested => ('未测试', c.inkFaint),
      _BadgeKind.ok => ('已连接', c.olive),
      _BadgeKind.fail => ('连接失败', scheme.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w900, color: color)),
    );
  }

  _BadgeKind _badgeKind(SettingsState s) {
    if (s.cloudSyncUser.trim().isEmpty || !s.cloudSyncHasToken) {
      return _BadgeKind.unconfigured;
    }
    final r = _testResult;
    if (r == null) return _BadgeKind.untested;
    return r.ok ? _BadgeKind.ok : _BadgeKind.fail;
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      autofillHints: obscure ? null : const [AutofillHints.email],
      keyboardType: obscure ? TextInputType.visiblePassword : TextInputType.url,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
    );
  }

  Future<int?> _pickKeepCount(BuildContext context, int current) {
    return showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor:
            Theme.of(context).colorScheme.surfaceContainerLowest,
        title: const Text('云端保留最近几份备份',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        children: [
          for (final n in [3, 5, 7, 10])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, n),
              child: Text(
                n == current ? '✓ 最近 $n 份' : '最近 $n 份',
                style:
                    const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

enum _BadgeKind { unconfigured, untested, ok, fail }
