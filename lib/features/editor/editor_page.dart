import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../providers/actions.dart';
import '../../providers/core_providers.dart';
import '../../providers/inventory_providers.dart';
import '../../providers/settings_provider.dart';
import '../../core/utils/result.dart';
import '../../widgets/common.dart';
import '../../widgets/app_feedback.dart';
import 'location_quick_sheet.dart';

/// 添加 / 编辑物品（requirement.md §5.6、§4.6；编辑复用表单 §4.7）。
class EditorPage extends ConsumerStatefulWidget {
  final String? editItemId;

  const EditorPage({super.key, this.editItemId});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _spec = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _customUnit = TextEditingController();
  final _price = TextEditingController();
  final _notes = TextEditingController();

  String? _categoryId;
  String? _locationId;
  String _unit = '袋';
  bool _customUnitMode = false;
  bool _isConsumable = true;
  bool _reminderEnabled = true;
  DateTime? _expiry;
  DateTime? _purchaseDate;
  String? _pickedImage;
  bool _initialized = false;

  bool get _editing => widget.editItemId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (_editing) {
      final item = await ref.read(inventoryRepositoryProvider).getItem(widget.editItemId!);
      if (item == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      final batches = await ref.read(inventoryRepositoryProvider).getBatchesOfItems([item.id]);
      final primary = batches.isEmpty ? null : batches.first;
      _name.text = item.name;
      _spec.text = item.spec ?? '';
      _categoryId = item.categoryId;
      _locationId = primary?.locationId ?? item.lastLocationId;
      _unit = primary?.unit ?? '袋';
      _isConsumable = item.isConsumable;
      _reminderEnabled = item.reminderEnabled;
      _expiry = primary?.expiryDate;
      _purchaseDate = primary?.purchaseDate;
      _price.text = primary?.purchasePrice == null ? '' : '${primary!.purchasePrice}';
      _notes.text = primary?.notes ?? '';
      _pickedImage = primary?.imagePath;
    } else {
      // 默认带出上次使用的单位与位置（§4.6）
      final settings = ref.read(settingsProvider);
      if (settings.lastUsedUnit != null) _unit = settings.lastUsedUnit!;
      final items = ref.read(itemsProvider).value ?? const <Item>[];
      if (items.isNotEmpty) _locationId = items.first.lastLocationId;

      // 「再买一次」预填：extra 携带归档物品 id（§4.4）
      final extra = GoRouterState.of(context).extra;
      if (extra is String) {
        final item = await ref.read(inventoryRepositoryProvider).getItem(extra);
        if (item != null) {
          final batches = await ref.read(inventoryRepositoryProvider).getBatchesOfItems([item.id]);
          final last = batches.isEmpty ? null : batches.first;
          _name.text = item.name;
          _spec.text = item.spec ?? '';
          _categoryId = item.categoryId;
          _locationId = last?.locationId ?? item.lastLocationId;
          _unit = last?.unit ?? _unit;
          _isConsumable = item.isConsumable;
          _expiry = last?.expiryDate;
          _qty.text = Fmt.quantity(last?.initialQuantity ?? 1);
        }
      }

      await _restoreDraft();
    }
    if (mounted) setState(() => _initialized = true);
  }

  Future<void> _restoreDraft() async {
    final raw = await ref.read(inventoryRepositoryProvider).getSetting(SettingKeys.draft);
    if (raw == null || raw.isEmpty) return;
    try {
      final d = jsonDecode(raw) as Map<String, dynamic>;
      _name.text = d['name'] ?? '';
      _spec.text = d['spec'] ?? '';
      _qty.text = '${d['qty'] ?? 1}';
      _categoryId = d['categoryId'];
      _locationId = d['locationId'];
      _unit = d['unit'] ?? _unit;
      _isConsumable = d['isConsumable'] ?? true;
      _expiry = d['expiry'] == null ? null : DateTime.tryParse(d['expiry']);
    } catch (_) {
      // 草稿损坏时直接忽略，不阻断录入
    }
  }

  Future<void> _saveDraft() async {
    final draft = jsonEncode({
      'name': _name.text,
      'spec': _spec.text,
      'qty': double.tryParse(_qty.text) ?? 1,
      'categoryId': _categoryId,
      'locationId': _locationId,
      'unit': _unit,
      'isConsumable': _isConsumable,
      'expiry': _expiry?.toIso8601String(),
    });
    await ref.read(inventoryRepositoryProvider).setSetting(SettingKeys.draft, draft);
    if (mounted) showToast(context, '草稿已保存，下次进入自动恢复');
  }

  Future<void> _submit({required bool continueNext}) async {
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_categoryId == null) {
      showToast(context, '请选择分类');
      return;
    }
    if (_locationId == null) {
      showToast(context, '请选择存放位置');
      return;
    }
    final qty = double.tryParse(_qty.text) ?? 0;
    if (!_editing && qty <= 0) {
      showToast(context, '数量需要大于 0');
      return;
    }

    final actions = ref.read(inventoryActionsProvider);
    final price = double.tryParse(_price.text);

    if (_editing) {
      final repo = ref.read(inventoryRepositoryProvider);
      final batches =
          await repo.getBatchesOfItems([widget.editItemId!]);
      if (batches.isEmpty) {
        if (mounted) showToast(context, '批次缺失，无法保存');
        return;
      }
      final result = await actions.saveEdits(
        itemId: widget.editItemId!,
        batchId: batches.first.id,
        name: _name.text,
        spec: _spec.text.isEmpty ? null : _spec.text,
        categoryId: _categoryId!,
        icon: _categoryIcon,
        isConsumable: _isConsumable,
        reminderEnabled: _reminderEnabled,
        locationId: _locationId,
        expiryDate: _expiry,
        purchasePrice: price,
        purchaseDate: _purchaseDate,
        notes: _notes.text.isEmpty ? null : _notes.text,
        pickedImagePath: _pickedImageTempPath,
        oldImageName: _pickedImage,
      );
      if (result is Success<void>) {
        if (mounted) showToast(context, '已保存');
        if (mounted) context.pop();
      } else if (result is Failure<void> && mounted) {
        showToast(context, result.message);
      }
      return;
    }

    String? existingId;
    final same = await actions.findSameName(_name.text);
    if (same.isNotEmpty) {
      final attach = await _askSameName(same);
      if (attach == null) return; // 用户取消
      existingId = attach;
    }

    final result = await actions.saveIntake(
      existingItemId: existingId,
      name: _name.text,
      spec: _spec.text.isEmpty ? null : _spec.text,
      categoryId: _categoryId!,
      icon: _categoryIcon,
      isConsumable: _isConsumable,
      reminderEnabled: _reminderEnabled,
      locationId: _locationId!,
      quantity: qty,
      unit: _customUnitMode ? (_customUnit.text.trim().isEmpty ? _unit : _customUnit.text.trim()) : _unit,
      expiryDate: _expiry,
      purchasePrice: price,
      purchaseDate: _purchaseDate,
      notes: _notes.text.isEmpty ? null : _notes.text,
      pickedImagePath: _pickedImageTempPath,
    );
    // 清除草稿
    await ref.read(inventoryRepositoryProvider).setSetting(SettingKeys.draft, '');

    if (result is Success<Item>) {
      if (mounted) showToast(context, '已入库 🧾');
      if (continueNext) {
        _resetForNext();
      } else if (mounted) {
        context.pop();
      }
    } else if (result is Failure<Item> && mounted) {
      showToast(context, result.message);
    }
  }

  String? get _categoryIcon {
    final cats = ref.read(categoriesProvider).value ?? const <Category>[];
    return cats.where((c) => c.id == _categoryId).firstOrNull?.icon;
  }

  /// 同名检查（§4.6）：挂到已有物品作为新批次，或确认为新物品。
  Future<String?> _askSameName(List<Item> same) async {
    final scheme = Theme.of(context).colorScheme;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('已有同名物品',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: Text(
          '「${same.first.name}」已在库中。\n同一物品的每一批建议挂在它名下，方便多批次一起管理。',
          style: const TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'new'),
            child: const Text('作为新物品'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, same.first.id),
            child: const Text('挂到它名下'),
          ),
        ],
      ),
    );
    return action == 'new' ? null : action;
  }

  void _resetForNext() {
    _form.currentState?.reset();
    _name.clear();
    _spec.clear();
    _qty.text = '1';
    _price.clear();
    _notes.clear();
    _expiry = null;
    _purchaseDate = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final locations = ref.watch(locationsProvider).value ?? const <StorageLocation>[];
    final templateDays = _categoryId == null
        ? null
        : ref.watch(expiryTemplateByCategoryProvider)[_categoryId];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.pop(),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_editing ? '编辑物品' : '添加物品',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  if (!_editing)
                    TextButton(
                      onPressed: _saveDraft,
                      child: const Text('存草稿'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: !_initialized
                  ? const Center(child: CircularProgressIndicator())
                  : Form(
                      key: _form,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                            AppTheme.pagePadding, 8, AppTheme.pagePadding, 40),
                        children: [
                          _photoPicker(scheme, c),
                          _fieldLabel('物品名称', required: true),
                          TextFormField(
                            controller: _name,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? '名称不能为空' : null,
                          ),
                          _fieldLabel('规格（包装描述，选填）'),
                          TextFormField(
                            controller: _spec,
                            decoration:
                                const InputDecoration(hintText: '如 250ml×12 / 500g / 20片'),
                          ),
                          _fieldLabel('物品分类', required: true),
                          _categoryGrid(categories, c, scheme),
                          _fieldLabel('存放位置', required: true),
                          _locationGrid(locations, c, scheme),
                          if (!_editing) ...[
                            _fieldLabel('数量与计量单位', required: true),
                            _quantityRow(c, scheme),
                          ] else ...[
                            _fieldLabel('余量'),
                            Text('编辑不直接改数量；请到物品详情页用「校正」调整余量',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600, color: c.inkFaint)),
                          ],
                          _fieldLabel('到期日期（快捷选项按分类记忆）'),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          _expiry ?? DateTime.now().add(const Duration(days: 7)),
                                      firstDate: DateTime.now(),
                                      lastDate:
                                          DateTime.now().add(const Duration(days: 3650)),
                                    );
                                    if (d != null) setState(() => _expiry = d);
                                  },
                                  child: Text(_expiry == null
                                      ? '选择日期（可留空 = 无期限）'
                                      : Fmt.date(_expiry!)),
                                ),
                              ),
                              if (_expiry != null)
                                IconButton(
                                  onPressed: () => setState(() => _expiry = null),
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final d in [3, 7, 30, 90, 180])
                                ChoiceChip(
                                  label: Text(_quickLabel(d)),
                                  selected: _expiry != null &&
                                      _expiry!
                                          .difference(DateTime.now())
                                          .inDays
                                          .round() ==
                                          d,
                                  onSelected: (_) => setState(() {
                                    _expiry = DateTime.now().add(Duration(days: d));
                                  }),
                                ),
                              if (templateDays != null)
                                InputChip(
                                  label: Text('上次同类：$templateDays 天'),
                                  onPressed: () => setState(() {
                                    _expiry = DateTime.now()
                                        .add(Duration(days: templateDays));
                                  }),
                                ),
                            ],
                          ),
                          if (!_editing) ...[
                            _fieldLabel('单价与购买日期（仅记录，不做统计）'),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _price,
                                    keyboardType: const TextInputType.numberWithOptions(
                                        decimal: true),
                                    decoration:
                                        const InputDecoration(hintText: '¥ 选填'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      final d = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now()
                                            .add(const Duration(days: 365)),
                                      );
                                      if (d != null) {
                                        setState(() => _purchaseDate = d);
                                      }
                                    },
                                    child: Text(_purchaseDate == null
                                        ? '购买日期 选填'
                                        : Fmt.date(_purchaseDate!)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SwitchRow(
                              title: '计为耗材',
                              subtitle: '关闭后为耐用品：不参与余量消耗与用量提醒',
                              value: _isConsumable,
                              onChanged: (v) => setState(() => _isConsumable = v),
                            ),
                            const SizedBox(height: 10),
                            SwitchRow(
                              title: '临期提醒',
                              subtitle: '到期前按预警天数聚合提醒（默认开）',
                              value: _reminderEnabled,
                              onChanged: (v) => setState(() => _reminderEnabled = v),
                            ),
                          ],
                          _fieldLabel('备注'),
                          TextFormField(
                            controller: _notes,
                            maxLines: 2,
                            decoration: const InputDecoration(
                                hintText: '如 已开封，开封后 4 天内吃完'),
                          ),
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed: () => _submit(continueNext: false),
                            child: Text(_editing ? '保存' : '加入库存'),
                          ),
                          if (!_editing) ...[
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: () => _submit(continueNext: true),
                              child: const Text('保存并继续录入下一件'),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _quickLabel(int d) =>
      d == 3 ? '3 天' : d == 7 ? '7 天' : d == 30 ? '1 个月' : d == 90 ? '3 个月' : '6 个月';

  Widget _fieldLabel(String text, {bool required = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 0, 7),
      child: Row(
        children: [
          Text(text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          if (required)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text('*',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: scheme.onPrimaryContainer)),
            ),
        ],
      ),
    );
  }

  String? _pickedImageTempPath;

  Widget _photoPicker(ColorScheme scheme, AppColors c) {
    return InkWell(
      onTap: () async {
        final picker = ImagePicker();
        XFile? x = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 80,
        );
        x ??= await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 80,
        );
        if (x != null) {
          final path = x.path;
          setState(() => _pickedImageTempPath = path);
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: scheme.outlineVariant,
              strokeAlign: BorderSide.strokeAlignInside),
        ),
        child: _pickedImageTempPath == null
            ? Text('📷 拍照记录物品外观（选填）',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.inkFaint))
            : const Text('已选择照片（保存时入库）✓',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _categoryGrid(List<Category> categories, AppColors c, ColorScheme scheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final cat in categories)
          InkWell(
            onTap: () => setState(() {
              _categoryId = cat.id;
              // 分类切换时按分类记忆预填效期（模板 chips 在下方提供）
            }),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: _categoryId == cat.id
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _categoryId == cat.id ? scheme.primary : scheme.outline),
              ),
              child: Text('${cat.icon ?? ''} ${cat.name}',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _categoryId == cat.id
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface)),
            ),
          ),
      ],
    );
  }

  Widget _locationGrid(List<StorageLocation> locations, AppColors c, ColorScheme scheme) {
    final active = locations.where((l) => l.isActive).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final l in active)
          InkWell(
            onTap: () => setState(() => _locationId = l.id),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: _locationId == l.id
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _locationId == l.id ? scheme.primary : scheme.outline),
              ),
              child: Text('${l.icon ?? '📍'} ${l.name}',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _locationId == l.id
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface)),
            ),
          ),
        InkWell(
          onTap: () async {
            final created = await showLocationQuickSheet(context);
            if (created != null) setState(() => _locationId = created);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outline, style: BorderStyle.solid),
            ),
            child: Text('➕ 新增位置',
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w800, color: c.inkFaint)),
          ),
        ),
      ],
    );
  }

  Widget _quantityRow(AppColors c, ColorScheme scheme) {
    return Row(
      children: [
        _roundBtn(Icons.remove_rounded, () {
          final v = (double.tryParse(_qty.text) ?? 1) - 1;
          if (v >= 1) setState(() => _qty.text = Fmt.quantity(v));
        }, scheme),
        const SizedBox(width: 12),
        SizedBox(
          width: 64,
          child: TextFormField(
            controller: _qty,
            textAlign: TextAlign.center,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? '>0' : null,
          ),
        ),
        const SizedBox(width: 12),
        _roundBtn(Icons.add_rounded, () {
          final v = (double.tryParse(_qty.text) ?? 0) + 1;
          setState(() => _qty.text = Fmt.quantity(v));
        }, scheme),
        const SizedBox(width: 12),
        Expanded(
          child: _customUnitMode
              ? TextField(
                  controller: _customUnit,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: '自定义单位'),
                  onSubmitted: (_) => setState(() {
                    if (_customUnit.text.trim().isNotEmpty) {
                      _unit = _customUnit.text.trim();
                    }
                    _customUnitMode = false;
                  }),
                )
              : InkWell(
                  onTap: () => setState(() => _customUnitMode = true),
                  child: InputDecorator(
                    decoration: const InputDecoration(),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(_unit,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800)),
                        ),
                        Icon(Icons.expand_more_rounded,
                            size: 16, color: c.inkFaint),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap, ColorScheme scheme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 44,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
