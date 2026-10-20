// features/inventory/order_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_exception.dart';
import '../../core/app_svgs.dart';
import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../models/inventory_entry.dart';
import '../../models/item.dart';
import '../../providers/providers.dart';

/// One row in the order: an item and the quantity typed for it.
class _Line {
  _Line(this.item, String initial) : controller = TextEditingController(text: initial);

  final Item item;
  final TextEditingController controller;

  int get qty => int.tryParse(controller.text.trim()) ?? 0;
}

class OrderFormPage extends ConsumerStatefulWidget {
  const OrderFormPage({super.key, required this.type, this.presetItemId});

  final EntryType type;

  /// When opened from Item Detail, this item is added automatically.
  final String? presetItemId;

  @override
  ConsumerState<OrderFormPage> createState() => _OrderFormPageState();
}

class _OrderFormPageState extends ConsumerState<OrderFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _reference = TextEditingController();
  final _note = TextEditingController();
  final Map<String, _Line> _lines = {};
  final List<TextEditingController> _removed = [];
  DateTime _date = _today();
  bool _busy = false;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _isManual => widget.type == EntryType.manual;
  bool get _isSale => widget.type == EntryType.sale;

  String get _title => switch (widget.type) {
    EntryType.supply => 'New supply order',
    EntryType.sale => 'New sale order',
    EntryType.manual => 'Adjust stock',
  };

  String get _hint => switch (widget.type) {
    EntryType.supply => 'Items you received. Stock goes up.',
    EntryType.sale => 'Items sold. Stock goes down.',
    EntryType.manual => 'Enter how much to add (+) or remove (-) for each item.',
  };

  String get _saveLabel => switch (widget.type) {
    EntryType.supply => 'Save supply order',
    EntryType.sale => 'Save sale order',
    EntryType.manual => 'Save adjustment',
  };

  @override
  void initState() {
    super.initState();
    final id = widget.presetItemId;
    if (id != null && id.isNotEmpty) _loadPreset(id);
  }

  @override
  void dispose() {
    _reference.dispose();
    _note.dispose();
    for (final l in _lines.values) {
      l.controller.dispose();
    }
    for (final c in _removed) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPreset(String id) async {
    try {
      final item = await ref.read(itemRepositoryProvider).fetchItem(id);
      if (!mounted) return;
      setState(() => _addLine(item));
    } catch (_) {
      // If the item cannot load, the user can still add items manually.
    }
  }

  void _addLine(Item item) {
    _lines.putIfAbsent(item.id, () => _Line(item, _isManual ? '' : '1'));
  }

  void _removeLine(String id) {
    final line = _lines.remove(id);
    if (line != null) _removed.add(line.controller);
  }

  void _toggle(Item item) {
    setState(() {
      if (_lines.containsKey(item.id)) {
        _removeLine(item.id);
      } else {
        _addLine(item);
      }
    });
  }

  /// Stock change this line will cause.
  int _delta(_Line l) => switch (widget.type) {
    EntryType.supply => l.qty,
    EntryType.sale => -l.qty,
    EntryType.manual => l.qty,
  };

  /// Quick check on screen. The database does the final check.
  String? _lineError(_Line l) {
    final q = l.qty;
    switch (widget.type) {
      case EntryType.supply:
        if (q <= 0) return 'Enter a quantity above 0';
      case EntryType.sale:
        if (q <= 0) return 'Enter a quantity above 0';
        if (q > l.item.stock) return 'Only ${l.item.stock} in stock';
      case EntryType.manual:
        if (q == 0) return 'Enter an amount (+ or -)';
        if (l.item.stock + q < 0) {
          return 'Stock cannot go below 0 (now ${l.item.stock})';
        }
    }
    return null;
  }

  bool get _canSave => _lines.isNotEmpty && _lines.values.every((l) => _lineError(l) == null);

  void _step(_Line l, int by) {
    var next = l.qty + by;
    if (!_isManual && next < 1) next = 1;
    setState(() => l.controller.text = '$next');
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: _today(),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _openPicker() {
    return showDialog<void>(
      context: context,
      builder: (_) => _ItemPickerDialog(
        type: widget.type,
        isAdded: (id) => _lines.containsKey(id),
        onToggle: _toggle,
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = ref.read(authProvider);
    if (user == null || !_canSave) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .createEntry(
            userId: user.id,
            type: widget.type,
            entryDate: _date,
            quantities: {for (final l in _lines.values) l.item.id: l.qty},
            referenceNo: _isManual ? null : _reference.text,
            note: _note.text,
          );
      refreshAll(ref);
      if (!mounted) return;
      showMessage(context, 'Saved');
      goBackOr(context, '/');
    } catch (e) {
      if (mounted) showMessage(context, errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _lines.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => goBackOr(context, '/'),
          icon: AppIcon(AppSvgs.chevronLeftIcon, color: AppColors.text),
        ),
        title: Text(_title),
      ),
      body: SingleChildScrollView(
        child: PageContainer(
          maxWidth: 760,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_hint, style: const TextStyle(color: AppColors.textSoft)),
                const SizedBox(height: 16),
                if (!_isManual) ...[
                  TextFormField(
                    controller: _reference,
                    decoration: InputDecoration(
                      labelText: _isSale ? 'Voucher number' : 'Invoice / slip number (optional)',
                    ),
                    validator: _isSale ? (v) => (v == null || v.trim().isEmpty) ? 'Voucher number is required' : null : null,
                  ),
                  const SizedBox(height: 14),
                ],
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date',
                      suffixIcon: Padding(
                        padding: const EdgeInsets.all(14),
                        child: AppIcon(
                          AppSvgs.calendarIcon,
                          size: 20,
                          color: AppColors.textSoft,
                        ),
                      ),
                    ),
                    child: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _note,
                  decoration: InputDecoration(
                    labelText: _isManual ? 'Reason (optional)' : 'Note (optional)',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Items',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openPicker,
                      icon: AppIcon(AppSvgs.addIcon, size: 18, color: AppColors.primary),
                      label: const Text('Add items'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_lines.isEmpty)
                  const AppCard(
                    child: Center(
                      child: Text(
                        'No items yet. Tap "Add items".',
                        style: TextStyle(color: AppColors.textSoft),
                      ),
                    ),
                  )
                else
                  for (final l in _lines.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _lineCard(l),
                    ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_busy || !_canSave) ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          count == 0 ? _saveLabel : '$_saveLabel ($count ${count == 1 ? 'item' : 'items'})',
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lineCard(_Line l) {
    final err = _lineError(l);
    final showErr = err != null && l.controller.text.trim().isNotEmpty;
    final stockText = l.qty != 0 ? 'Stock: ${l.item.stock}  →  ${l.item.stock + _delta(l)}' : 'Stock: ${l.item.stock}';

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ItemThumb(url: l.item.imageUrl, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (l.item.subtitle.isNotEmpty)
                      Text(
                        l.item.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSoft,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      stockText,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSoft),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: () => setState(() => _removeLine(l.item.id)),
                icon: AppIcon(AppSvgs.closeIcon, size: 18, color: AppColors.textSoft),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: showErr
                    ? Text(
                        err,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.danger,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              _StepButton(label: '-', onTap: () => _step(l, -1)),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: TextField(
                  controller: l.controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.numberWithOptions(signed: _isManual),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(_isManual ? r'[0-9-]' : r'[0-9]'),
                    ),
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '0',
                    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StepButton(label: '+', onTap: () => _step(l, 1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

/// Tap items to add or remove them. The dialog stays open so you can add many.
class _ItemPickerDialog extends ConsumerStatefulWidget {
  const _ItemPickerDialog({
    required this.type,
    required this.isAdded,
    required this.onToggle,
  });

  final EntryType type;
  final bool Function(String id) isAdded;
  final void Function(Item item) onToggle;

  @override
  ConsumerState<_ItemPickerDialog> createState() => _ItemPickerDialogState();
}

class _ItemPickerDialogState extends ConsumerState<_ItemPickerDialog> {
  String _q = '';

  bool _matches(Item i) {
    if (_q.isEmpty) return true;
    final text = [
      i.name,
      i.itemSerial ?? '',
      i.brandName ?? '',
      i.categoryName ?? '',
      i.variation,
      i.size,
    ].join(' ').toLowerCase();
    return text.contains(_q);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(itemsProvider);

    return Dialog(
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select items',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search items',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(14),
                    child: AppIcon(
                      AppSvgs.searchIcon,
                      size: 20,
                      color: AppColors.textSoft,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: async.when(
                  loading: () => const LoadingView(),
                  error: (e, _) => ErrorState(
                    error: e,
                    onRetry: () => ref.invalidate(itemsProvider),
                  ),
                  data: (items) {
                    final list = items.where(_matches).toList();
                    if (list.isEmpty) {
                      return const EmptyState(message: 'No items found.');
                    }
                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final item = list[i];
                        final added = widget.isAdded(item.id);
                        final blocked = widget.type == EntryType.sale && item.stock == 0;
                        final sub = [item.subtitle, item.brandName ?? ''].where((s) => s.isNotEmpty).join(' · ');

                        return ListTile(
                          enabled: !blocked || added,
                          leading: ItemThumb(url: item.imageUrl, size: 40),
                          title: Text(item.name),
                          subtitle: sub.isEmpty ? null : Text(sub),
                          trailing: Text(
                            added ? 'Added' : '${item.stock}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: added ? AppColors.success : (item.stock == 0 ? AppColors.danger : AppColors.text),
                            ),
                          ),
                          onTap: () {
                            widget.onToggle(item);
                            setState(() {});
                          },
                        );
                      },
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
}
