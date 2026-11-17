import 'package:flutter/material.dart';

import '../models/saved_address.dart';
import '../services/address_book.dart';
import '../services/egypt_locations.dart';

/// دفتر العناوين المحفوظة — إضافة/تعديل/حذف وتعيين افتراضي.
/// يُفتح من صفحة الحساب. الحفظ على الخادم عند توفر نقطته،
/// وإلا محلياً (AddressBookService يسقط بهدوء دون عطل).
class AddressesPage extends StatefulWidget {
  const AddressesPage({
    super.key,
    required this.addressBook,
    required this.ownerKey,
  });

  final AddressBookService addressBook;

  /// مفتاح حساب العميل — يفصل التخزين المحلي بين الحسابات.
  final String ownerKey;

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  List<SavedAddress> _addresses = const <SavedAddress>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final addresses =
        await widget.addressBook.load(ownerKey: widget.ownerKey);
    if (!mounted) return;
    setState(() {
      _addresses = addresses;
      _loading = false;
    });
  }

  Future<void> _openEditor([SavedAddress? existing]) async {
    final saved = await showDialog<SavedAddress>(
      context: context,
      builder: (_) => _AddressEditorDialog(existing: existing),
    );
    if (saved == null) return;
    await widget.addressBook.save(ownerKey: widget.ownerKey, address: saved);
    await _load();
  }

  Future<void> _confirmDelete(SavedAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف العنوان'),
        content: Text('حذف عنوان «${address.label} — ${address.governorate}»؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.addressBook.delete(ownerKey: widget.ownerKey, id: address.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عناويني المحفوظة')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('إضافة عنوان'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'لا توجد عناوين محفوظة بعد.\nأضف عنوانك ليظهر بضغطة واحدة في إتمام الطلب.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: _addresses.length,
                  itemBuilder: (context, index) {
                    final address = _addresses[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          address.label == 'شغل'
                              ? Icons.work_outline
                              : address.label == 'بيت'
                                  ? Icons.home_outlined
                                  : Icons.location_on_outlined,
                        ),
                        title: Text(address.displayTitle),
                        subtitle: Text(
                          '${address.displayLine}\n${address.phone}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await _openEditor(address);
                            } else if (value == 'default') {
                              await widget.addressBook.setDefault(
                                ownerKey: widget.ownerKey,
                                id: address.id,
                              );
                              await _load();
                            } else if (value == 'delete') {
                              await _confirmDelete(address);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('تعديل'),
                            ),
                            if (!address.isDefault)
                              const PopupMenuItem(
                                value: 'default',
                                child: Text('تعيين كافتراضي'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('حذف'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

/// نافذة إضافة/تعديل عنوان: التسمية والمحافظة (قائمة الخادم المعتمدة
/// عند توفرها وإلا قائمة المحافظات الـ27) والمدينة والشارع والهاتف.
class _AddressEditorDialog extends StatefulWidget {
  const _AddressEditorDialog({this.existing});

  final SavedAddress? existing;

  @override
  State<_AddressEditorDialog> createState() => _AddressEditorDialogState();
}

class _AddressEditorDialogState extends State<_AddressEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _label;
  late String _governorate;
  late String _city;
  final _streetController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isDefault = false;
  List<String> _governorates = egyptGovernorates;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _label = existing?.label ?? 'بيت';
    _governorate = existing?.governorate ?? '';
    _city = existing?.city ?? '';
    _streetController.text = existing?.street ?? '';
    _phoneController.text = existing?.phone ?? '';
    _isDefault = existing?.isDefault ?? false;
    _loadLocations();
  }

  /// محافظات القائمة المعتمدة من الخادم عند توفرها؛ وإلا الـ27.
  Future<void> _loadLocations() async {
    final data = await EgyptLocations().load();
    if (!mounted) return;
    if (!data.isEmpty) {
      setState(() => _governorates = data.governorates);
    }
  }

  @override
  void dispose() {
    _streetController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      SavedAddress(
        id: widget.existing?.id ?? '',
        label: _label,
        governorate: _governorate,
        city: _city.trim(),
        street: _streetController.text.trim(),
        phone: _phoneController.text.trim(),
        isDefault: _isDefault,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'إضافة عنوان' : 'تعديل العنوان'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _label,
                decoration: const InputDecoration(labelText: 'التسمية'),
                items: addressLabels
                    .map(
                      (label) =>
                          DropdownMenuItem(value: label, child: Text(label)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _label = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _governorate.isEmpty ? null : _governorate,
                decoration: const InputDecoration(labelText: 'المحافظة'),
                items: _governorates
                    .map(
                      (gov) => DropdownMenuItem(value: gov, child: Text(gov)),
                    )
                    .toList(),
                validator: (value) =>
                    value == null || value.isEmpty ? 'اختر المحافظة' : null,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _governorate = value;
                    _city = '';
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _city,
                decoration: const InputDecoration(labelText: 'المدينة'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'أدخل المدينة'
                    : null,
                onChanged: (value) => _city = value,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(
                  labelText: 'الشارع ورقم المبنى',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'أدخل العنوان'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'هاتف التواصل'),
                keyboardType: TextInputType.phone,
                validator: (value) => value == null || value.trim().length < 10
                    ? 'أدخل رقم هاتف صحيح'
                    : null,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('عنوان افتراضي'),
                value: _isDefault,
                onChanged: (value) => setState(() => _isDefault = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('حفظ')),
      ],
    );
  }
}
