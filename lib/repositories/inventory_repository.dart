// repositories/inventory_repository.dart
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../models/inventory_entry.dart';

class InventoryRepository {
  InventoryRepository(this._db);
  final SupabaseClient _db;

  static const _entrySelect =
      '*, app_users(display_name), '
      'inventory_entry_lines(id, quantity_change, item_id, items(name,size,variation))';

  static final _dateFormat = DateFormat('yyyy-MM-dd');
  static String _date(DateTime d) => _dateFormat.format(d);

  static String? _clean(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  /// quantities: itemId -> quantity.
  /// Supply and sale: positive numbers. Manual: signed (+ or -).
  Future<void> createEntry({
    required String userId,
    required EntryType type,
    required DateTime entryDate,
    required Map<String, int> quantities,
    String? referenceNo,
    String? note,
  }) async {
    await _db.rpc(
      'create_inventory_entry',
      params: {
        'p_user_id': userId,
        'p_entry_type': type.name,
        'p_reference_no': _clean(referenceNo),
        'p_entry_date': _date(entryDate),
        'p_note': _clean(note),
        'p_lines': quantities.entries.map((e) => {'item_id': e.key, 'quantity': e.value}).toList(),
      },
    );
  }

  Future<List<InventoryEntry>> fetchEntries({
    DateTime? from,
    DateTime? to,
    EntryType? type,
    int limit = 200,
  }) async {
    var query = _db.from('inventory_entries').select(_entrySelect);
    if (from != null) query = query.gte('entry_date', _date(from));
    if (to != null) query = query.lte('entry_date', _date(to));
    if (type != null) query = query.eq('entry_type', type.name);

    final rows = await query.order('entry_date', ascending: false).order('created_at', ascending: false).limit(limit);
    return rows.map((r) => InventoryEntry.fromJson(r)).toList();
  }

  Future<List<ItemHistoryRow>> fetchItemHistory(String itemId) async {
    final rows = await _db
        .from('inventory_entry_lines')
        .select(
          'quantity_change, '
          'inventory_entries(entry_type, reference_no, note, entry_date, created_at, '
          'app_users(display_name))',
        )
        .eq('item_id', itemId)
        .limit(500);

    final list = rows.map((r) => ItemHistoryRow.fromJson(r)).toList();
    list.sort((a, b) {
      final byDate = b.entryDate.compareTo(a.entryDate);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  /// Deletes a record and puts the stock back.
  /// Fails with a clear message if the stock would go below 0.
  Future<void> deleteEntry({required String userId, required String entryId}) async {
    await _db.rpc(
      'delete_inventory_entry',
      params: {'p_user_id': userId, 'p_entry_id': entryId},
    );
  }

  /// Raw report rows from the database (one row per item per date).
  Future<List<Map<String, dynamic>>> fetchStockReportRows(DateTime from, DateTime to) async {
    final res = await _db.rpc(
      'get_stock_report',
      params: {'p_from': _date(from), 'p_to': _date(to)},
    );
    final list = (res as List?) ?? const [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
