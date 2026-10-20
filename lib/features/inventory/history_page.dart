// features/inventory/history_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_exception.dart';
import '../../core/app_svgs.dart';
import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../models/inventory_entry.dart';
import '../../providers/providers.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// One supply, sale, or manual entry with its item lines.
/// Pass [onDelete] to show a delete button (used on the History screen).
class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.entry,
    this.showDate = false,
    this.onDelete,
    this.deleting = false,
  });

  final InventoryEntry entry;
  final bool showDate;
  final VoidCallback? onDelete;
  final bool deleting;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final refLabel = switch (e.type) {
      EntryType.sale => 'Voucher',
      EntryType.supply => 'Invoice / slip',
      EntryType.manual => 'Ref',
    };
    final meta = [
      if (showDate) DateFormat('d MMM yyyy').format(e.entryDate),
      'by ${e.createdByName}',
      DateFormat('h:mm a').format(e.createdAt),
    ].join(' · ');
    final hasRef = e.referenceNo != null && e.referenceNo!.isNotEmpty;
    final hasNote = e.note != null && e.note!.isNotEmpty;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TypeChip(e.type),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasRef ? '$refLabel ${e.referenceNo}' : '',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${e.lines.length} ${e.lines.length == 1 ? 'item' : 'items'}',
                style: const TextStyle(color: AppColors.textSoft, fontSize: 12),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Delete record',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: deleting ? null : onDelete,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: deleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : AppIcon(AppSvgs.deleteIcon, size: 18, color: AppColors.danger),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            meta,
            style: const TextStyle(color: AppColors.textSoft, fontSize: 12),
          ),
          const Divider(height: 20),
          for (final l in e.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.itemSubtitle.isEmpty ? l.itemName : '${l.itemName} (${l.itemSubtitle})',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    signed(l.quantityChange),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: l.quantityChange > 0 ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          if (hasNote)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                e.note!,
                style: const TextStyle(
                  color: AppColors.textSoft,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  static const _limit = 200;
  static final _fmt = DateFormat('d MMM yyyy');

  EntryType? _type;
  // Default: last 30 days. Use "Clear dates" to see everything.
  DateTime? _from = _dateOnly(DateTime.now().subtract(const Duration(days: 30)));
  DateTime? _to;
  String? _busyId; // record that is being deleted

  Future<void> _pickRange() async {
    final today = _dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange: _from == null ? null : DateTimeRange(start: _from!, end: _to ?? today),
    );
    if (picked != null) {
      setState(() {
        _from = _dateOnly(picked.start);
        _to = _dateOnly(picked.end);
      });
    }
  }

  Future<bool?> _confirmDelete(InventoryEntry e) {
    final what = switch (e.type) {
      EntryType.sale => 'sale',
      EntryType.supply => 'supply',
      EntryType.manual => 'manual adjustment',
    };

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Delete this $what record?'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('The record will be removed and the stock will be changed back:'),
                const SizedBox(height: 12),
                for (final l in e.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.itemSubtitle.isEmpty ? l.itemName : '${l.itemName} (${l.itemSubtitle})',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          signed(-l.quantityChange),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: -l.quantityChange > 0 ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(InventoryEntry e) async {
    final ok = await _confirmDelete(e);
    if (ok != true || !mounted) return;

    final user = ref.read(authProvider);
    if (user == null) return;

    setState(() => _busyId = e.id);
    try {
      await ref.read(inventoryRepositoryProvider).deleteEntry(userId: user.id, entryId: e.id);
      refreshAll(ref);
      if (mounted) showMessage(context, 'Record deleted. Stock updated.');
    } catch (err) {
      if (mounted) showMessage(context, errorMessage(err), isError: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = (type: _type, from: _from, to: _to);
    final async = ref.watch(historyProvider(query));

    return PageContainer(
      maxWidth: 900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(title: 'Inventory History'),
          const SizedBox(height: 16),
          _filters(),
          const SizedBox(height: 12),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorState(
                error: e,
                onRetry: () => ref.invalidate(historyProvider(query)),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return const EmptyState(message: 'No entries found.');
                }
                // Insert a date heading whenever the date changes
                final rows = <Object>[];
                DateTime? last;
                for (final e in entries) {
                  if (last == null || e.entryDate != last) {
                    rows.add(e.entryDate);
                    last = e.entryDate;
                  }
                  rows.add(e);
                }
                final showLimitNote = entries.length >= _limit;

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: rows.length + (showLimitNote ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == rows.length) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Showing the latest 200 entries. Narrow the dates to see older ones.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSoft),
                        ),
                      );
                    }
                    final row = rows[i];
                    if (row is DateTime) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: Text(
                          DateFormat('EEEE, d MMM yyyy').format(row),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSoft,
                          ),
                        ),
                      );
                    }
                    final entry = row as InventoryEntry;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: EntryCard(
                        entry: entry,
                        deleting: _busyId == entry.id,
                        onDelete: _busyId == null ? () => _delete(entry) : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    final dateLabel = _from == null ? 'All dates' : '${_fmt.format(_from!)} - ${_to == null ? 'today' : _fmt.format(_to!)}';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in [null, ...EntryType.values])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(t?.label ?? 'All'),
                selected: _type == t,
                showCheckmark: false,
                selectedColor: AppColors.primarySoft,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: _type == t ? AppColors.primary : AppColors.border,
                ),
                onSelected: (_) => setState(() => _type = t),
              ),
            ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: AppIcon(
              AppSvgs.calendarIcon,
              size: 16,
              color: AppColors.textSoft,
            ),
            label: Text(dateLabel),
            backgroundColor: Colors.white,
            side: const BorderSide(color: AppColors.border),
            onPressed: _pickRange,
          ),
          if (_from != null) ...[
            const SizedBox(width: 8),
            ActionChip(
              label: const Text('Clear dates'),
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.border),
              onPressed: () => setState(() {
                _from = null;
                _to = null;
              }),
            ),
          ],
        ],
      ),
    );
  }
}
