// features/reports/reports_page.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_exception.dart';
import '../../core/app_svgs.dart';
import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../models/stock_report.dart';
import '../../providers/providers.dart';
import 'report_exporter.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

int _daysBetween(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

enum _Preset { today, yesterday, last7, thisMonth, custom }

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  static const _maxDays = 93;
  static final _dayFormat = DateFormat('d MMM yyyy');

  _Preset _preset = _Preset.today;
  late DateTime _from = _dateOnly(DateTime.now());
  late DateTime _to = _from;
  int _sheetIndex = 0;
  bool _onlyMovement = false;

  String get _rangeLabel => _from == _to ? DateFormat('EEE, d MMM yyyy').format(_from) : '${_dayFormat.format(_from)} - ${_dayFormat.format(_to)}';

  void _applyPreset(_Preset p) {
    final today = _dateOnly(DateTime.now());
    final (from, to) = switch (p) {
      _Preset.today => (today, today),
      _Preset.yesterday => (_addDays(today, -1), _addDays(today, -1)),
      _Preset.last7 => (_addDays(today, -6), today),
      _Preset.thisMonth => (DateTime(today.year, today.month, 1), today),
      _Preset.custom => (_from, _to),
    };
    setState(() {
      _preset = p;
      _from = from;
      _to = to;
      _sheetIndex = 0;
    });
  }

  Future<void> _pickRange() async {
    final today = _dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: 'Select report dates',
    );
    if (picked == null) return;

    final from = _dateOnly(picked.start);
    final to = _dateOnly(picked.end);

    if (_daysBetween(from, to) + 1 > _maxDays) {
      if (mounted) {
        showMessage(context, 'Please choose $_maxDays days or fewer.', isError: true);
      }
      return;
    }

    setState(() {
      _preset = _Preset.custom;
      _from = from;
      _to = to;
      _sheetIndex = 0;
    });
  }

  void _export(List<ReportSheet> sheets) {
    try {
      ReportExporter.exportAndDownload(sheets);
      showMessage(
        context,
        sheets.length == 1 ? 'Excel file downloaded' : 'Excel file with ${sheets.length} sheets downloaded',
      );
    } catch (e, st) {
      debugPrint('Export failed: $e\n$st'); // visible in the browser console
      showMessage(context, 'Export failed: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = (from: _from, to: _to);
    final async = ref.watch(stockReportProvider(query));
    final mobile = MediaQuery.sizeOf(context).width < 700;

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Reports',
            subtitle: _rangeLabel,
            trailing: FilledButton.icon(
              onPressed: async.hasValue ? () => _export(async.requireValue) : null,
              icon: AppIcon(AppSvgs.downloadIcon, size: 18, color: Colors.white),
              label: Text(mobile ? 'Export' : 'Export Excel'),
            ),
          ),
          const SizedBox(height: 14),
          _presetChips(),
          const SizedBox(height: 14),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorState(
                error: e,
                onRetry: () => ref.invalidate(stockReportProvider(query)),
              ),
              data: _content,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Widget? avatar,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        avatar: avatar,
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.primarySoft,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _presetChips() {
    const presets = <(_Preset, String)>[
      (_Preset.today, 'Today'),
      (_Preset.yesterday, 'Yesterday'),
      (_Preset.last7, 'Last 7 days'),
      (_Preset.thisMonth, 'This month'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (preset, label) in presets)
            _chip(
              label: label,
              selected: _preset == preset,
              onTap: () => _applyPreset(preset),
            ),
          _chip(
            label: _preset == _Preset.custom ? _rangeLabel : 'Pick dates',
            selected: _preset == _Preset.custom,
            onTap: _pickRange,
            avatar: AppIcon(
              AppSvgs.calendarIcon,
              size: 16,
              color: _preset == _Preset.custom ? AppColors.primary : AppColors.textSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(List<ReportSheet> sheets) {
    final index = math.min(_sheetIndex, sheets.length - 1);
    final sheet = sheets[index];
    final rows = _onlyMovement ? sheet.rows.where((r) => r.hasMovement).toList() : sheet.rows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Totals of the selected date
        Row(
          children: [
            Expanded(child: _MiniStat('Opening', sheet.totalOpening, AppColors.text)),
            const SizedBox(width: 8),
            Expanded(child: _MiniStat('Supplied', sheet.totalSupply, AppColors.success)),
            const SizedBox(width: 8),
            Expanded(child: _MiniStat('Sold', sheet.totalSale, AppColors.primary)),
            const SizedBox(width: 8),
            Expanded(child: _MiniStat('Closing', sheet.totalClosing, AppColors.text)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('EEEE, d MMM yyyy').format(sheet.date),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            FilterChip(
              label: const Text('With movement'),
              selected: _onlyMovement,
              showCheckmark: false,
              selectedColor: AppColors.primarySoft,
              backgroundColor: Colors.white,
              side: BorderSide(color: _onlyMovement ? AppColors.primary : AppColors.border),
              onSelected: (v) => setState(() => _onlyMovement = v),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: rows.isEmpty
              ? EmptyState(
                  message: _onlyMovement ? 'No stock movement on this day.' : 'No items yet.',
                )
              : _SheetTable(
                  key: ValueKey(sheet.date),
                  sheet: sheet,
                  rows: rows,
                  filtered: _onlyMovement,
                ),
        ),
        if (sheets.length > 1) ...[
          const SizedBox(height: 10),
          _SheetTabs(
            sheets: sheets,
            selected: index,
            onSelect: (i) => setState(() => _sheetIndex = i),
          ),
        ],
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(fontSize: 11, color: AppColors.textSoft),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$value',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Excel-like table. The item name column and the header row stay in place
/// while you scroll, so it also works on a phone.
class _SheetTable extends StatefulWidget {
  const _SheetTable({
    super.key,
    required this.sheet,
    required this.rows,
    required this.filtered,
  });

  final ReportSheet sheet;
  final List<ReportRow> rows;

  /// True when some items are hidden. The total row still counts all items.
  final bool filtered;

  @override
  State<_SheetTable> createState() => _SheetTableState();
}

class _SheetTableState extends State<_SheetTable> {
  static const double _rowH = 52;
  static const double _headH = 46;

  final _head = ScrollController();
  final _body = ScrollController();

  @override
  void initState() {
    super.initState();
    _body.addListener(_syncHeader);
  }

  /// Keeps the header columns in line with the body when scrolling sideways.
  void _syncHeader() {
    if (!_head.hasClients) return;
    final target = _body.offset.clamp(0.0, _head.position.maxScrollExtent).toDouble();
    if ((_head.offset - target).abs() > 0.5) _head.jumpTo(target);
  }

  @override
  void dispose() {
    _body.removeListener(_syncHeader);
    _head.dispose();
    _body.dispose();
    super.dispose();
  }

  Widget _cell(
    String text,
    double width, {
    double height = _rowH,
    bool right = false,
    bool bold = false,
    Color? color,
    Color? bg,
    int maxLines = 1,
    double fontSize = 13,
  }) {
    return Container(
      width: width,
      height: height,
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          right: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.2,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color ?? AppColors.text,
        ),
      ),
    );
  }

  Widget _num(int v, double width, {Color? hot, bool bold = false, Color? bg}) {
    return _cell(
      '$v',
      width,
      right: true,
      bold: bold,
      bg: bg,
      color: v == 0 ? AppColors.textSoft : (hot ?? AppColors.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final mobile = c.maxWidth < 700;
        final nameW = mobile ? 150.0 : 300.0;
        final numW = mobile ? 78.0 : 112.0;
        final remarkMin = mobile ? 190.0 : 280.0;
        final rightW = math.max(c.maxWidth - nameW - 2, numW * 4 + remarkMin);
        final remarkW = rightW - numW * 4;

        const head = AppColors.muted;
        final s = widget.sheet;

        Widget headerRow() => Row(
          children: [
            _cell('Opening Stock', numW, height: _headH, right: true, bold: true, bg: head, fontSize: 12),
            _cell('Supply Qty', numW, height: _headH, right: true, bold: true, bg: head, fontSize: 12),
            _cell('Sale Qty', numW, height: _headH, right: true, bold: true, bg: head, fontSize: 12),
            _cell('Closing Stock', numW, height: _headH, right: true, bold: true, bg: head, fontSize: 12),
            _cell('Remark', remarkW, height: _headH, bold: true, bg: head, fontSize: 12),
          ],
        );

        Widget dataRow(ReportRow r) => Row(
          children: [
            _num(r.opening, numW),
            _num(r.supply, numW, hot: AppColors.success),
            _num(r.sale, numW, hot: AppColors.primary),
            _num(r.closing, numW, bold: true),
            _cell(r.remark, remarkW, maxLines: 2, color: AppColors.textSoft, fontSize: 12),
          ],
        );

        Widget totalRow() => Row(
          children: [
            _num(s.totalOpening, numW, bold: true, bg: head),
            _num(s.totalSupply, numW, hot: AppColors.success, bold: true, bg: head),
            _num(s.totalSale, numW, hot: AppColors.primary, bold: true, bg: head),
            _num(s.totalClosing, numW, bold: true, bg: head),
            _cell('', remarkW, bg: head),
          ],
        );

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              // Header (stays on top)
              Row(
                children: [
                  _cell('Item Name', nameW, height: _headH, bold: true, bg: head, fontSize: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _head,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: headerRow(),
                    ),
                  ),
                ],
              ),
              // Body
              Expanded(
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item names stay in place when scrolling sideways
                      Column(
                        children: [
                          for (final r in widget.rows) _cell(r.displayName, nameW, maxLines: 2),
                          _cell(
                            widget.filtered ? 'Total (all items)' : 'Total',
                            nameW,
                            bold: true,
                            bg: head,
                          ),
                        ],
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _body,
                          scrollDirection: Axis.horizontal,
                          child: Column(
                            children: [
                              for (final r in widget.rows) dataRow(r),
                              totalRow(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Sheet tabs at the bottom, like Excel. One tab per date.
class _SheetTabs extends StatefulWidget {
  const _SheetTabs({
    required this.sheets,
    required this.selected,
    required this.onSelect,
  });

  final List<ReportSheet> sheets;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  State<_SheetTabs> createState() => _SheetTabsState();
}

class _SheetTabsState extends State<_SheetTabs> {
  static const double _tabW = 84;
  final _ctrl = ScrollController();

  @override
  void didUpdateWidget(covariant _SheetTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _reveal();
  }

  /// Scrolls so the selected tab is in the middle.
  void _reveal() {
    if (!_ctrl.hasClients) return;
    final pos = _ctrl.position;
    final target = widget.selected * _tabW - (pos.viewportDimension - _tabW) / 2;
    _ctrl.animateTo(
      target.clamp(0.0, pos.maxScrollExtent).toDouble(),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _arrow(String icon, bool enabled, VoidCallback onTap) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: enabled ? onTap : null,
      icon: AppIcon(icon, size: 18, color: enabled ? AppColors.text : AppColors.border),
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = widget.sheets.length - 1;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _arrow(
            AppSvgs.chevronLeftIcon,
            widget.selected > 0,
            () => widget.onSelect(widget.selected - 1),
          ),
          Expanded(
            child: ListView.builder(
              controller: _ctrl,
              scrollDirection: Axis.horizontal,
              itemCount: widget.sheets.length,
              itemBuilder: (context, i) {
                final isSelected = i == widget.selected;
                final date = widget.sheets[i].date;
                return SizedBox(
                  width: _tabW,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                    child: Material(
                      color: isSelected ? Colors.white : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => widget.onSelect(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('d MMM').format(date),
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.2,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? AppColors.primary : AppColors.text,
                              ),
                            ),
                            Text(
                              DateFormat('EEE').format(date),
                              style: const TextStyle(
                                fontSize: 10,
                                height: 1.2,
                                color: AppColors.textSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _arrow(
            AppSvgs.chevronRightIcon,
            widget.selected < last,
            () => widget.onSelect(widget.selected + 1),
          ),
        ],
      ),
    );
  }
}
