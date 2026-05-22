import 'package:flutter/material.dart';

import '../app_store.dart';
import '../main.dart';
import '../models.dart';
import '../widgets/common.dart';

class AddItemPage extends StatefulWidget {
  const AddItemPage({super.key, this.item});

  final Item? item;

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  late final ItemFormData _form = widget.item == null
      ? ItemFormData()
      : ItemFormData.fromItem(widget.item!);
  late final TextEditingController _name =
      TextEditingController(text: _form.name);
  late final TextEditingController _brand =
      TextEditingController(text: _form.brand);
  late final TextEditingController _price =
      TextEditingController(text: _form.purchasePrice?.toString() ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: _form.notes);
  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final isEditing = widget.item != null;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        _selectInitialCategory(store);
        return Scaffold(
          appBar: AppBar(title: Text(isEditing ? '编辑物品' : '添加物品')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              SectionCard(
                title: '基础信息',
                children: [
                  TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: '物品名称 *')),
                  DropdownButtonFormField<String>(
                    value: _form.categoryId,
                    decoration: const InputDecoration(labelText: '分类 *'),
                    items: store.categories
                        .map<DropdownMenuItem<String>>(
                            (c) => DropdownMenuItem<String>(
                                  value: c.id,
                                  child: Text('${c.icon ?? '📦'} ${c.name}'),
                                ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _form.categoryId = value),
                  ),
                  TextField(
                      controller: _brand,
                      decoration: const InputDecoration(labelText: '品牌')),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: '批次信息',
                children: [
                  TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '单价')),
                  DropdownButtonFormField<String>(
                    value: _form.location?.trim().isEmpty ?? true
                        ? null
                        : _form.location,
                    decoration: const InputDecoration(labelText: '存放位置'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('未选择'),
                      ),
                      ...store.locations.map(
                        (location) => DropdownMenuItem<String>(
                          value: location.name,
                          child: Text(location.name),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _form.location = value ?? ''),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('购买日期'),
                    subtitle: Text(_form.purchaseDate == null
                        ? '未记录'
                        : formatDate(_form.purchaseDate!)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _form.purchaseDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _form.purchaseDate = picked);
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('无保质期'),
                    value: _form.noExpiry,
                    onChanged: (value) =>
                        setState(() => _form.noExpiry = value),
                  ),
                  if (!_form.noExpiry)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('保质期'),
                      subtitle: Text(formatDate(_form.expiryDate!)),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _form.expiryDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _form.expiryDate = picked);
                        }
                      },
                    ),
                  StepperRow(
                    label: '初始数量',
                    value: _form.quantity,
                    onChanged: (value) =>
                        setState(() => _form.quantity = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('记录日均成本'),
                    value: _form.trackDailyCost,
                    onChanged: (value) =>
                        setState(() => _form.trackDailyCost = value),
                  ),
                  TextField(
                      controller: _notes,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: '备注')),
                ],
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () async {
                try {
                  _form.name = _name.text;
                  _form.brand = _brand.text;
                  _form.purchasePrice = double.tryParse(_price.text);
                  _form.notes = _notes.text;
                  await store.saveItemFromForm(_form);
                  if (context.mounted) Navigator.pop(context);
                } catch (error) {
                  if (context.mounted) showSnack(context, error.toString());
                }
              },
              child: Text(isEditing ? '保存修改' : '保存'),
            ),
          ),
        );
      },
    );
  }

  void _selectInitialCategory(AppStore store) {
    if (_form.categoryId != null || store.categories.isEmpty) return;
    final firstCategory = store.categories.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _form.categoryId != null) return;
      setState(() => _form.categoryId = firstCategory.id);
    });
  }
}
