// features/items/item_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/app_exception.dart';
import '../../core/app_svgs.dart';
import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../models/item.dart';
import '../../models/lookup.dart';
import '../../providers/providers.dart';

class ItemFormPage extends ConsumerStatefulWidget {
  const ItemFormPage({super.key, this.itemId});

  /// null = create, otherwise edit this item.
  final String? itemId;

  @override
  ConsumerState<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends ConsumerState<ItemFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _serial = TextEditingController();
  final _name = TextEditingController();
  final _image = TextEditingController();
  final _desc = TextEditingController();
  final _size = TextEditingController();
  final _variation = TextEditingController();

  Lookup? _brand;
  Lookup? _category;
  bool _loading = false;
  bool _busy = false;
  Object? _loadError;

  bool get _isEdit => widget.itemId != null;

  @override
  void initState() {
    super.initState();
    _loading = _isEdit;
    if (_isEdit) _load();
  }

  @override
  void dispose() {
    for (final c in [_serial, _name, _image, _desc, _size, _variation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final item = await ref.read(itemRepositoryProvider).fetchItem(widget.itemId!);
      if (!mounted) return;
      setState(() {
        _serial.text = item.itemSerial ?? '';
        _name.text = item.name;
        _image.text = item.imageUrl ?? '';
        _desc.text = item.shortDesc;
        _size.text = item.size;
        _variation.text = item.variation;
        _brand = item.brandId == null ? null : Lookup(id: item.brandId!, name: item.brandName ?? '');
        _category = item.categoryId == null ? null : Lookup(id: item.categoryId!, name: item.categoryName ?? '');
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e;
          _loading = false;
        });
      }
    }
  }

  Future<_PickResult?> _openLookup({
    required String noun,
    required Future<List<Lookup>> Function() load,
    required Future<Lookup> Function(String) create,
    required String? currentId,
    required bool startInCreateMode,
  }) async {
    try {
      final options = await load();
      if (!mounted) return null;
      return showDialog<_PickResult>(
        context: context,
        builder: (_) => _LookupDialog(
          noun: noun,
          options: options,
          create: create,
          currentId: currentId,
          startInCreateMode: startInCreateMode,
        ),
      );
    } catch (e) {
      if (mounted) showMessage(context, errorMessage(e), isError: true);
      return null;
    }
  }

  Future<void> _pickBrand({bool create = false}) async {
    final repo = ref.read(itemRepositoryProvider);
    final r = await _openLookup(
      noun: 'brand',
      load: repo.fetchBrands,
      create: repo.createBrand,
      currentId: _brand?.id,
      startInCreateMode: create,
    );
    if (r != null) {
      setState(() => _brand = r.lookup);
      ref.invalidate(brandsProvider);
    }
  }

  Future<void> _pickCategory({bool create = false}) async {
    final repo = ref.read(itemRepositoryProvider);
    final r = await _openLookup(
      noun: 'category',
      load: repo.fetchCategories,
      create: repo.createCategory,
      currentId: _category?.id,
      startInCreateMode: create,
    );
    if (r != null) {
      setState(() => _category = r.lookup);
      ref.invalidate(categoriesProvider);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = ref.read(authProvider);
    if (user == null) return;

    setState(() => _busy = true);
    try {
      final input = ItemInput(
        itemSerial: _serial.text,
        name: _name.text,
        brandId: _brand?.id,
        categoryId: _category?.id,
        imageUrl: _image.text,
        shortDesc: _desc.text,
        size: _size.text,
        variation: _variation.text,
      );
      final repo = ref.read(itemRepositoryProvider);
      if (_isEdit) {
        await repo.updateItem(widget.itemId!, user.id, input);
      } else {
        await repo.createItem(user.id, input);
      }
      refreshAll(ref);
      if (!mounted) return;
      showMessage(context, _isEdit ? 'Item updated' : 'Item created');
      goBackOr(context, '/items');
    } catch (e) {
      if (!mounted) return;
      final msg = (e is PostgrestException && e.code == '23505') ? 'This item serial is already used.' : errorMessage(e);
      showMessage(context, msg, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? v, String what) => (v == null || v.trim().isEmpty) ? '$what is required' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => goBackOr(context, '/items'),
          icon: AppIcon(AppSvgs.chevronLeftIcon, color: AppColors.text),
        ),
        title: Text(_isEdit ? 'Edit item' : 'New item'),
      ),
      body: _loadError != null
          ? ErrorState(error: _loadError!)
          : _loading
          ? const LoadingView()
          : SingleChildScrollView(
              child: PageContainer(
                maxWidth: 640,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ItemThumb(url: _image.text, size: 72),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _image,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                labelText: 'Image URL (optional)',
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                final t = (v ?? '').trim().toLowerCase();
                                if (t.isEmpty) return null;
                                return t.startsWith('http') ? null : 'Must start with http:// or https://';
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _serial,
                        decoration: const InputDecoration(labelText: 'Item serial (optional)'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (v) => _required(v, 'Name'),
                      ),
                      const SizedBox(height: 14),
                      _LookupRow(
                        label: 'Brand',
                        value: _brand?.name,
                        onPick: _pickBrand,
                        onAdd: () => _pickBrand(create: true),
                      ),
                      const SizedBox(height: 14),
                      _LookupRow(
                        label: 'Category',
                        value: _category?.name,
                        onPick: _pickCategory,
                        onAdd: () => _pickCategory(create: true),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _size,
                              decoration: const InputDecoration(
                                labelText: 'Size',
                                hintText: '1L, 350g, 500ml, 1pcs',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _variation,
                              decoration: const InputDecoration(
                                labelText: 'Variation',
                                hintText: 'strawberry, menthol',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _desc,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Short description (optional)',
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_isEdit ? 'Save changes' : 'Create item'),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// A brand/category field plus a "+" button to create a new one.
class _LookupRow extends StatelessWidget {
  const _LookupRow({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onAdd,
  });

  final String label;
  final String? value;
  final VoidCallback onPick;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _PickerField(label: label, value: value, onTap: onPick),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'New ${label.toLowerCase()}',
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onAdd,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: AppIcon(AppSvgs.addIcon, size: 22, color: AppColors.primary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Looks like a text field, opens the picker when tapped.
class _PickerField extends StatelessWidget {
  const _PickerField({required this.label, required this.value, required this.onTap});

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: Padding(
            padding: const EdgeInsets.all(14),
            child: RotatedBox(
              quarterTurns: 1,
              child: AppIcon(
                AppSvgs.chevronRightIcon,
                size: 16,
                color: AppColors.textSoft,
              ),
            ),
          ),
        ),
        child: Text(
          value ?? 'None',
          style: TextStyle(
            color: value == null ? AppColors.textSoft : AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _PickResult {
  const _PickResult(this.lookup);

  /// null means "None" was chosen.
  final Lookup? lookup;
}

/// Pick an existing brand/category, or create a new one.
/// Creating a name that already exists just selects the existing one.
class _LookupDialog extends StatefulWidget {
  const _LookupDialog({
    required this.noun,
    required this.options,
    required this.create,
    required this.currentId,
    this.startInCreateMode = false,
  });

  /// "brand" or "category"
  final String noun;
  final List<Lookup> options;
  final Future<Lookup> Function(String name) create;
  final String? currentId;
  final bool startInCreateMode;

  @override
  State<_LookupDialog> createState() => _LookupDialogState();
}

class _LookupDialogState extends State<_LookupDialog> {
  final _search = TextEditingController();
  final _newName = TextEditingController();
  late bool _creating = widget.startInCreateMode;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    _newName.dispose();
    super.dispose();
  }

  String get _noun => widget.noun;
  String get _nounTitle => _noun[0].toUpperCase() + _noun.substring(1);

  List<Lookup> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return widget.options.where((o) => q.isEmpty || o.name.toLowerCase().contains(q)).toList();
  }

  void _startCreate() {
    setState(() {
      _newName.text = _search.text.trim();
      _error = null;
      _creating = true;
    });
  }

  Future<void> _create() async {
    final name = _newName.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }

    // Already exists? Just select it.
    for (final o in widget.options) {
      if (o.name.toLowerCase() == name.toLowerCase()) {
        Navigator.pop(context, _PickResult(o));
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await widget.create(name);
      if (mounted) Navigator.pop(context, _PickResult(created));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorMessage(e);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _creating ? _createView() : _listView();
  }

  Widget _createView() {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text('New $_noun'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _newName,
              autofocus: true,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _create(),
              decoration: InputDecoration(labelText: '$_nounTitle name'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () {
                  if (widget.startInCreateMode) {
                    Navigator.pop(context);
                  } else {
                    setState(() {
                      _creating = false;
                      _error = null;
                    });
                  }
                },
          child: Text(widget.startInCreateMode ? 'Cancel' : 'Back'),
        ),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text('Add $_noun'),
        ),
      ],
    );
  }

  Widget _listView() {
    final list = _filtered;
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Select $_noun'),
      content: SizedBox(
        width: 360,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: 'Search $_noun'),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: AppIcon(AppSvgs.addIcon, color: AppColors.primary),
                    title: Text(
                      'New $_noun',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: _startCreate,
                  ),
                  ListTile(
                    title: const Text('None'),
                    onTap: () => Navigator.pop(context, const _PickResult(null)),
                  ),
                  for (final o in list)
                    ListTile(
                      title: Text(o.name),
                      selected: o.id == widget.currentId,
                      selectedColor: AppColors.primary,
                      onTap: () => Navigator.pop(context, _PickResult(o)),
                    ),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No $_noun found. Tap "New $_noun" to add one.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSoft),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
