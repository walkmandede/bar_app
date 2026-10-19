// models/inventory_entry.dart
import 'item.dart' show joinSubtitle;

enum EntryType {
  supply,
  sale,
  manual
  ;

  String get label => switch (this) {
    EntryType.supply => 'Supply',
    EntryType.sale => 'Sale',
    EntryType.manual => 'Manual',
  };
}

class EntryLine {
  const EntryLine({
    required this.itemId,
    required this.itemName,
    required this.itemSubtitle,
    required this.quantityChange,
  });

  final String itemId;
  final String itemName;
  final String itemSubtitle;
  final int quantityChange;

  factory EntryLine.fromJson(Map<String, dynamic> j) {
    final item = (j['items'] as Map<String, dynamic>?) ?? const {};
    return EntryLine(
      itemId: j['item_id'] as String,
      itemName: (item['name'] as String?) ?? 'Unknown item',
      itemSubtitle: joinSubtitle(
        (item['variation'] as String?) ?? '',
        (item['size'] as String?) ?? '',
      ),
      quantityChange: j['quantity_change'] as int,
    );
  }
}

class InventoryEntry {
  const InventoryEntry({
    required this.id,
    required this.type,
    required this.entryDate,
    required this.createdByName,
    required this.createdAt,
    required this.lines,
    this.referenceNo,
    this.note,
  });

  final String id;
  final EntryType type;
  final String? referenceNo;
  final String? note;
  final DateTime entryDate;
  final String createdByName;
  final DateTime createdAt;
  final List<EntryLine> lines;

  int get totalUnits => lines.fold(0, (sum, l) => sum + l.quantityChange.abs());

  factory InventoryEntry.fromJson(Map<String, dynamic> j) {
    final user = j['app_users'] as Map<String, dynamic>?;
    final rawLines = (j['inventory_entry_lines'] as List?) ?? const [];
    return InventoryEntry(
      id: j['id'] as String,
      type: EntryType.values.byName(j['entry_type'] as String),
      referenceNo: j['reference_no'] as String?,
      note: j['note'] as String?,
      entryDate: DateTime.parse(j['entry_date'] as String),
      createdByName: (user?['display_name'] as String?) ?? 'Unknown',
      createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      lines: rawLines.map((l) => EntryLine.fromJson(l as Map<String, dynamic>)).toList(),
    );
  }
}

/// One stock change for one item, used in Item Detail history.
class ItemHistoryRow {
  const ItemHistoryRow({
    required this.type,
    required this.quantityChange,
    required this.entryDate,
    required this.createdAt,
    required this.createdByName,
    this.referenceNo,
    this.note,
  });

  final EntryType type;
  final int quantityChange;
  final DateTime entryDate;
  final DateTime createdAt;
  final String createdByName;
  final String? referenceNo;
  final String? note;

  factory ItemHistoryRow.fromJson(Map<String, dynamic> j) {
    final e = j['inventory_entries'] as Map<String, dynamic>;
    final user = e['app_users'] as Map<String, dynamic>?;
    return ItemHistoryRow(
      type: EntryType.values.byName(e['entry_type'] as String),
      quantityChange: j['quantity_change'] as int,
      entryDate: DateTime.parse(e['entry_date'] as String),
      createdAt: DateTime.parse(e['created_at'] as String).toLocal(),
      createdByName: (user?['display_name'] as String?) ?? 'Unknown',
      referenceNo: e['reference_no'] as String?,
      note: e['note'] as String?,
    );
  }
}
