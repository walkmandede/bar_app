// models/stock_report.dart
import 'package:intl/intl.dart';

import 'item.dart';

/// One item row of a daily stock sheet.
class ReportRow {
  const ReportRow({
    required this.itemId,
    required this.name,
    required this.subtitle,
    required this.opening,
    required this.supply,
    required this.sale,
    required this.closing,
    this.remark = '',
  });

  final String itemId;
  final String name;
  final String subtitle;
  final int opening;
  final int supply;
  final int sale;
  final int closing;
  final String remark;

  String get displayName => subtitle.isEmpty ? name : '$name ($subtitle)';

  /// True when something happened to this item on that day.
  bool get hasMovement => supply != 0 || sale != 0 || remark.isNotEmpty;

  factory ReportRow.fromJson(Map<String, dynamic> j) => ReportRow(
    itemId: j['item_id'] as String,
    name: (j['name'] as String?) ?? 'Unknown item',
    subtitle: joinSubtitle(
      (j['variation'] as String?) ?? '',
      (j['size'] as String?) ?? '',
    ),
    opening: (j['opening'] as num).toInt(),
    supply: (j['supply_qty'] as num).toInt(),
    sale: (j['sale_qty'] as num).toInt(),
    closing: (j['closing'] as num).toInt(),
    remark: (j['remark'] as String?) ?? '',
  );
}

/// One sheet = one date.
class ReportSheet {
  const ReportSheet({required this.date, required this.rows});

  final DateTime date;
  final List<ReportRow> rows;

  int get totalOpening => rows.fold(0, (sum, r) => sum + r.opening);
  int get totalSupply => rows.fold(0, (sum, r) => sum + r.supply);
  int get totalSale => rows.fold(0, (sum, r) => sum + r.sale);
  int get totalClosing => rows.fold(0, (sum, r) => sum + r.closing);
}

/// Builds one sheet per date. The database only sends rows that have stock or
/// movement. Active items that are missing are added here with zeros.
List<ReportSheet> buildReportSheets({
  required DateTime from,
  required DateTime to,
  required List<Map<String, dynamic>> serverRows,
  required List<Item> activeItems,
}) {
  final keyFormat = DateFormat('yyyy-MM-dd');

  final byDate = <String, Map<String, ReportRow>>{};
  for (final j in serverRows) {
    final row = ReportRow.fromJson(j);
    (byDate[j['date'] as String] ??= {})[row.itemId] = row;
  }

  final sheets = <ReportSheet>[];
  var day = DateTime(from.year, from.month, from.day);
  final last = DateTime(to.year, to.month, to.day);

  while (!day.isAfter(last)) {
    final rows = Map<String, ReportRow>.from(byDate[keyFormat.format(day)] ?? const {});

    for (final item in activeItems) {
      // Do not list items that were created after this date
      final created = DateTime(item.createdAt.year, item.createdAt.month, item.createdAt.day);
      if (created.isAfter(day)) continue;

      rows.putIfAbsent(
        item.id,
        () => ReportRow(
          itemId: item.id,
          name: item.name,
          subtitle: item.subtitle,
          opening: 0,
          supply: 0,
          sale: 0,
          closing: 0,
        ),
      );
    }

    final list = rows.values.toList()
      ..sort((a, b) {
        final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return byName != 0 ? byName : a.subtitle.toLowerCase().compareTo(b.subtitle.toLowerCase());
      });

    sheets.add(ReportSheet(date: day, rows: list));
    day = DateTime(day.year, day.month, day.day + 1);
  }
  return sheets;
}
