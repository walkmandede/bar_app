// features/inventory/adjust_stock_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_exception.dart';
import '../../core/app_svgs.dart';
import '../../core/app_theme.dart';
import '../../core/sorting.dart';
import '../../core/widgets.dart';
import '../../models/inventory_entry.dart';
import '../../models/item.dart';
import '../../providers/providers.dart';

enum _Kind { meta, header, message, item }

/// One line of the list: the date/reason card, a heading, a message, or an item.
class _Row {
  const _Row._(this.kind, {this.item, this.text = '', this.reset = false});
  const _Row.meta() : this._(_Kind.meta);
  const _Row.header(String text, {bool reset = false}) : this._(_Kind.header, text: text, reset: reset);
  const _Row.message(String text) : this._(_Kind.message, text: text);
  const _Row.item(Item item) : this._(_Kind.item, item: item);

  final _Kind kind;
  final Item? item;
  final String text;
  final bool reset;
}

class AdjustStockPage extends ConsumerStatefulWidget {
  const AdjustStockPage({super.key, this.presetItemId});

  /// When opened from Item Detail, the search box starts with this item.
  final String? presetItemId;

  @override
  ConsumerState<AdjustStockPage> createState() => _AdjustStockPageState();
}

class _AdjustStockPageState extends ConsumerState<AdjustStockPage> {
  /// Changed items move to the top after this short pause, so a row does not
  /// jump away while you are still tapping + or -.
  static const _repinDelay = Duration(milliseconds: 700);

  final _search = TextEditingController();
  final _note = TextEditingController();
  final Map<String, TextEditingController> _ctrls = {};

  List<Item>? _items; // sorted by code. Taken once when the page opens.
  Set<String> _pinned = {}; // items shown in the "Changed" section
  Timer? _repinTimer;
  DateTime _date = _today();
  bool _busy = false;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _repinTimer?.cancel();
    _search.dispose();
    _note.dispose();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- Values ----------

  TextEditingController _ctrl(Item item) => _ctrls.putIfAbsent(item.id, () => TextEditingController(text: '${item.stock}'));

  /// The stock typed in the box. An empty box means "no change".
  int _newOf(Item item) => int.tryParse(_ctrls[item.id]?.text.trim() ?? '') ?? item.stock;

  bool _isChanged(Item item) => _newOf(item) != item.stock;

  int get _changedCount => _items == null ? 0 : _items!.where(_isChanged).length;

  void _onEdited() {
    setState(() {});
    _repinTimer?.cancel();
    _repinTimer = Timer(_repinDelay, () {
      if (!mounted) return;
      setState(() {
        _pinned = {
          for (final i in _items ?? const <Item>[])
            if (_isChanged(i)) i.id,
        };
      });
    });
  }

  void _step(Item item, int by) {
    final next = (_newOf(item) + by).clamp(0, 999999).toInt();
    _ctrl(item).value = TextEditingValue(
      text: '$next',
      selection: TextSelection.collapsed(offset: '$next'.length),
    );
    _onEdited();
  }

  void _resetAll() {
    for (final i in _items ?? const <Item>[]) {
      _ctrls[i.id]?.text = '${i.stock}';
    }
    _repinTimer?.cancel();
    setState(() => _pinned = {});
  }

  // ---------- Setup ----------

  List<Item> _prepare(List<Item> items) {
    final sorted = [...items]
      ..sort((a, b) {
        final byCode = compareCodes(a.itemSerial, b.itemSerial);
        if (byCode != 0) return byCode;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    // Opened from Item Detail: start with that item in the search box.
    final id = widget.presetItemId;
    if (id != null && id.isNotEmpty) {
      final match = sorted.where((i) => i.id == id);
      if (match.isNotEmpty) {
        final item = match.first;
        final text = (item.itemSerial != null && item.itemSerial!.trim().isNotEmpty) ? item.itemSerial! : item.name;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _search.text = text);
        });
      }
    }
    return sorted;
  }

  bool _matches(Item i, String q) {
    if (q.isEmpty) return true;
    final text = [
      i.itemSerial ?? '',
      i.name,
      i.brandName ?? '',
      i.categoryName ?? '',
      i.variation,
      i.size,
    ].join(' ').toLowerCase();
    return text.contains(q);
  }

  // ---------- Actions ----------

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

  Future<bool> _confirmLeave() async {
    final n = _changedCount;
    if (n == 0) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Discard changes?'),
        content: Text('You changed the stock of $n ${n == 1 ? 'item' : 'items'}. Leave without saving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _leave() async {
    if (await _confirmLeave() && mounted) goBackOr(context, '/');
  }

  Future<void> _save() async {
    final user = ref.read(authProvider);
    final items = _items;
    if (user == null || items == null) return;

    // Only the changed items are saved: new stock minus current stock.
    final changes = {
      for (final i in items)
        if (_isChanged(i)) i.id: _newOf(i) - i.stock,
    };
    if (changes.isEmpty) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .createEntry(
            userId: user.id,
            type: EntryType.manual,
            entryDate: _date,
            quantities: changes,
            note: _note.text,
          );
      refreshAll(ref);
      if (!mounted) return;
      showMessage(context, 'Stock updated for ${changes.length} ${changes.length == 1 ? 'item' : 'items'}');
      goBackOr(context, '/');
    } catch (e) {
      if (mounted) showMessage(context, errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(itemsProvider);
    final changed = _changedCount;

    return PopScope(
      // Blocks the browser back button / swipe when there are unsaved changes.
      canPop: changed == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _leave,
            icon: AppIcon(AppSvgs.chevronLeftIcon, color: AppColors.text),
          ),
          title: const Text('Adjust stock'),
        ),
        body: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(itemsProvider)),
          data: (items) {
            _items ??= _prepare(items);
            return _body(_items!);
          },
        ),
        bottomNavigationBar: SafeArea(
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (_busy || changed == 0) ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(changed == 0 ? 'Save adjustments' : 'Save adjustments ($changed)'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(List<Item> items) {
    final q = _search.text.trim().toLowerCase();

    // Number of each changed item, in code order: 1, 2, 3...
    final changed = items.where(_isChanged).toList();
    final rank = {
      for (var i = 0; i < changed.length; i++) changed[i].id: i + 1,
    };

    final top = items.where((i) => _pinned.contains(i.id)).toList();
    final rest = items.where((i) => !_pinned.contains(i.id) && _matches(i, q)).toList();

    final rows = <_Row>[
      const _Row.meta(),
      if (top.isNotEmpty) _Row.header('Changed items (${top.length})', reset: true),
      for (final i in top) _Row.item(i),
      _Row.header(top.isEmpty ? 'All items' : 'Other items (${rest.length})'),
      if (rest.isEmpty) _Row.message(items.isEmpty ? 'No items yet.' : 'No items match your search.'),
      for (final i in rest) _Row.item(i),
    ];

    final indexById = {
      for (var i = 0; i < rows.length; i++)
        if (rows[i].item != null) rows[i].item!.id: i,
    };

    return PageContainer(
      maxWidth: 820,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search code, name, brand...',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(14),
                child: AppIcon(AppSvgs.searchIcon, size: 20, color: AppColors.textSoft),
              ),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      onPressed: () => setState(_search.clear),
                      icon: AppIcon(AppSvgs.closeIcon, size: 18, color: AppColors.textSoft),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${items.length} items · ${changed.length} changed',
            style: const TextStyle(fontSize: 12, color: AppColors.textSoft),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: rows.length,
              findChildIndexCallback: (key) => key is ValueKey<String> ? indexById[key.value] : null,
              itemBuilder: (context, index) {
                final row = rows[index];
                switch (row.kind) {
                  case _Kind.meta:
                    return _metaCard();
                  case _Kind.header:
                    return Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.text,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (row.reset) TextButton(onPressed: _resetAll, child: const Text('Reset all')),
                        ],
                      ),
                    );
                  case _Kind.message:
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(row.text, style: const TextStyle(color: AppColors.textSoft)),
                      ),
                    );
                  case _Kind.item:
                    final item = row.item!;
                    return Padding(
                      key: ValueKey(item.id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AdjustRow(
                        item: item,
                        controller: _ctrl(item),
                        number: rank[item.id],
                        onChanged: _onEdited,
                        onStep: (by) => _step(item, by),
                      ),
                    );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, c) {
          final dateField = InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date',
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(14),
                  child: AppIcon(AppSvgs.calendarIcon, size: 20, color: AppColors.textSoft),
                ),
              ),
              child: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
            ),
          );
          final reason = TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Reason (optional)'),
          );

          if (c.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [dateField, const SizedBox(height: 10), reason],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: dateField),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: reason),
            ],
          );
        },
      ),
    );
  }
}

/// One item: [no] [code] [name] [- field +] [previous -> new stock]
class _AdjustRow extends StatelessWidget {
  const _AdjustRow({
    required this.item,
    required this.controller,
    required this.number,
    required this.onChanged,
    required this.onStep,
  });

  final Item item;
  final TextEditingController controller;

  /// Position among changed items. null when the item is not changed.
  final int? number;
  final VoidCallback onChanged;
  final void Function(int by) onStep;

  @override
  Widget build(BuildContext context) {
    final newValue = int.tryParse(controller.text.trim()) ?? item.stock;
    final changed = newValue != item.stock;
    final code = (item.itemSerial == null || item.itemSerial!.trim().isEmpty) ? '-' : item.itemSerial!;

    final badge = number == null ? null : _NumberBadge(number!);

    final nameBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (item.subtitle.isNotEmpty)
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textSoft),
          ),
      ],
    );

    final actions = _ActionBar(
      item: item,
      controller: controller,
      newValue: newValue,
      onChanged: onChanged,
      onStep: onStep,
    );

    final stock = _StockChange(prev: item.stock, next: newValue);

    return Material(
      color: changed ? AppColors.primarySoft : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: changed ? AppColors.primary : AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, c) {
            // Wide: one line. Narrow (phone): two lines.
            if (c.maxWidth >= 560) {
              return Row(
                children: [
                  SizedBox(width: 32, child: badge),
                  SizedBox(
                    width: 92,
                    child: Text(
                      code,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(child: nameBlock),
                  const SizedBox(width: 12),
                  actions,
                  const SizedBox(width: 14),
                  SizedBox(width: 92, child: stock),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (badge != null) ...[badge, const SizedBox(width: 8)],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            code,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSoft,
                            ),
                          ),
                          nameBlock,
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(children: [actions, const Spacer(), stock]),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
      child: Text(
        '$number',
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// previous -> new stock, with the difference below.
class _StockChange extends StatelessWidget {
  const _StockChange({required this.prev, required this.next});

  final int prev;
  final int next;

  @override
  Widget build(BuildContext context) {
    final changed = next != prev;
    final color = !changed ? AppColors.textSoft : (next > prev ? AppColors.success : AppColors.danger);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$prev', style: const TextStyle(color: AppColors.textSoft)),
            const Text(' → ', style: TextStyle(color: AppColors.textSoft)),
            Text(
              '$next',
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        if (changed)
          Text(
            signed(next - prev),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
      ],
    );
  }
}

/// [-] [ number ] [+]. The number cannot go below 0.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.item,
    required this.controller,
    required this.newValue,
    required this.onChanged,
    required this.onStep,
  });

  final Item item;
  final TextEditingController controller;
  final int newValue;
  final VoidCallback onChanged;
  final void Function(int by) onStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(icon: AppSvgs.minusIcon, enabled: newValue > 0, onTap: () => onStep(-1)),
        const SizedBox(width: 6),
        SizedBox(
          width: 72,
          child: Focus(
            // Left empty? Put the current stock back.
            onFocusChange: (hasFocus) {
              if (!hasFocus && controller.text.trim().isEmpty) {
                controller.text = '${item.stock}';
                onChanged();
              }
            },
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: const TextStyle(fontWeight: FontWeight.w700),
              onTap: () => controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: controller.text.length,
              ),
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 11, horizontal: 4),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        _StepButton(icon: AppSvgs.addIcon, enabled: true, onTap: () => onStep(1)),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.enabled, required this.onTap});

  final String icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: AppIcon(
            icon,
            size: 18,
            color: enabled ? AppColors.text : AppColors.border,
          ),
        ),
      ),
    );
  }
}
