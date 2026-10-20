// features/reports/report_exporter.dart
import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';

import '../../core/app_exception.dart';
import '../../core/file_download.dart';
import '../../models/stock_report.dart';

/// Builds an .xlsx file with one sheet per date and downloads it.
/// Google Sheets can open .xlsx files (Drive > Upload > Open with Google Sheets).
class ReportExporter {
  static const _headers = [
    'Item Name',
    'Opening Stock',
    'Supply Qty',
    'Sale Qty',
    'Closing Stock',
    'Remark',
  ];

  static const _mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  static void exportAndDownload(List<ReportSheet> sheets) {
    if (sheets.isEmpty) throw const AppException('Nothing to export.');

    final bytes = build(sheets);
    final f = DateFormat('yyyy-MM-dd');
    final first = f.format(sheets.first.date);
    final last = f.format(sheets.last.date);
    final name = sheets.length == 1 ? 'stock_report_$first.xlsx' : 'stock_report_${first}_to_$last.xlsx';

    downloadBytes(bytes, name, mimeType: _mime);
  }

  static Uint8List build(List<ReportSheet> sheets) {
    final excel = xl.Excel.createExcel();
    final defaultName = excel.tables.keys.first; // empty "Sheet1" made by the library
    final nameFormat = DateFormat('d MMM yyyy'); // e.g. "12 Oct 2026"

    for (final sheet in sheets) {
      _writeSheet(excel[nameFormat.format(sheet.date)], sheet);
    }
    excel.delete(defaultName);

    final bytes = excel.encode();
    if (bytes == null) throw const AppException('Could not create the Excel file.');
    return Uint8List.fromList(bytes);
  }

  static void _writeSheet(xl.Sheet s, ReportSheet sheet) {
    xl.CellIndex at(int col, int row) => xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row);

    final grey = xl.ExcelColor.fromHexString('#F3F3F5');
    final titleStyle = xl.CellStyle(bold: true, fontSize: 14);
    final headLeft = xl.CellStyle(bold: true, backgroundColorHex: grey);
    final headRight = xl.CellStyle(
      bold: true,
      backgroundColorHex: grey,
      horizontalAlign: xl.HorizontalAlign.Right,
    );
    final number = xl.CellStyle(horizontalAlign: xl.HorizontalAlign.Right);
    final totalLeft = xl.CellStyle(bold: true, backgroundColorHex: grey);
    final totalRight = xl.CellStyle(
      bold: true,
      backgroundColorHex: grey,
      horizontalAlign: xl.HorizontalAlign.Right,
    );

    // Row 1: title
    s.updateCell(
      at(0, 0),
      xl.TextCellValue('Stock report - ${DateFormat('EEEE, d MMM yyyy').format(sheet.date)}'),
      cellStyle: titleStyle,
    );

    // Row 3: column headers
    const headerRow = 2;
    for (var c = 0; c < _headers.length; c++) {
      s.updateCell(
        at(c, headerRow),
        xl.TextCellValue(_headers[c]),
        cellStyle: (c == 0 || c == 5) ? headLeft : headRight,
      );
    }

    // Item rows
    var r = headerRow + 1;
    for (final row in sheet.rows) {
      s.updateCell(at(0, r), xl.TextCellValue(row.displayName));
      s.updateCell(at(1, r), xl.IntCellValue(row.opening), cellStyle: number);
      s.updateCell(at(2, r), xl.IntCellValue(row.supply), cellStyle: number);
      s.updateCell(at(3, r), xl.IntCellValue(row.sale), cellStyle: number);
      s.updateCell(at(4, r), xl.IntCellValue(row.closing), cellStyle: number);
      if (row.remark.isNotEmpty) {
        s.updateCell(at(5, r), xl.TextCellValue(row.remark));
      }
      r++;
    }

    // Total row
    s.updateCell(at(0, r), xl.TextCellValue('Total'), cellStyle: totalLeft);
    s.updateCell(at(1, r), xl.IntCellValue(sheet.totalOpening), cellStyle: totalRight);
    s.updateCell(at(2, r), xl.IntCellValue(sheet.totalSupply), cellStyle: totalRight);
    s.updateCell(at(3, r), xl.IntCellValue(sheet.totalSale), cellStyle: totalRight);
    s.updateCell(at(4, r), xl.IntCellValue(sheet.totalClosing), cellStyle: totalRight);

    s.setColumnWidth(0, 44);
    for (var c = 1; c <= 4; c++) {
      s.setColumnWidth(c, 16);
    }
    s.setColumnWidth(5, 44);
  }
}
