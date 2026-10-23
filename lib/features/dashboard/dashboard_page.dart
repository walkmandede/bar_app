// features/dashboard/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/app_svgs.dart';
import '../../core/app_theme.dart';
import '../../core/responsive.dart';
import '../../core/widgets.dart';
import '../../models/inventory_entry.dart';
import '../../providers/providers.dart';
import '../inventory/history_page.dart' show EntryCard;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  late DateTime _selected = _dateOnly(DateTime.now());
  late DateTime _focused = _selected;
  CalendarFormat _format = CalendarFormat.week;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final mobile = Responsive.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('Bar Inventory (1.0.4)', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(width: 8),
            EnvBadge(),
          ],
        ),
        actions: [
          if (!mobile && user != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  user.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Log out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: AppIcon(AppSvgs.logoutIcon, color: AppColors.text),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: PageContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Dashboard',
                subtitle: DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
              ),
              const SizedBox(height: 20),
              const _Actions(),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, c) {
                  final calendar = _calendar();
                  final log = _log();
                  if (c.maxWidth < 900) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [calendar, const SizedBox(height: 20), log],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 380, child: calendar),
                      const SizedBox(width: 20),
                      Expanded(child: log),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _calendar() {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: TableCalendar(
        firstDay: DateTime(2020),
        lastDay: DateTime(2100),
        focusedDay: _focused,
        calendarFormat: _format,
        startingDayOfWeek: StartingDayOfWeek.monday,
        availableCalendarFormats: const {
          CalendarFormat.week: 'Month',
          CalendarFormat.month: 'Week',
        },
        selectedDayPredicate: (d) => isSameDay(d, _selected),
        onDaySelected: (selected, focused) => setState(() {
          _selected = _dateOnly(selected);
          _focused = focused;
        }),
        onFormatChanged: (f) => setState(() => _format = f),
        onPageChanged: (focused) => _focused = focused,
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonShowsNext: false,
          titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        calendarStyle: const CalendarStyle(
          outsideDaysVisible: false,
          selectedDecoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _log() {
    final isToday = isSameDay(_selected, DateTime.now());
    final async = ref.watch(entriesByDayProvider(_selected));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isToday ? 'Today' : DateFormat('EEE, d MMM yyyy').format(_selected),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            if (!isToday)
              TextButton(
                onPressed: () => setState(() {
                  _selected = _dateOnly(DateTime.now());
                  _focused = _selected;
                }),
                child: const Text('Go to today'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        async.when(
          loading: () => const SizedBox(height: 120, child: LoadingView()),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(entriesByDayProvider(_selected)),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return const EmptyState(message: 'No sales or supplies on this day.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _summary(entries),
                const SizedBox(height: 12),
                for (final e in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: EntryCard(entry: e),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _summary(List<InventoryEntry> entries) {
    var supply = 0;
    var sale = 0;
    var manual = 0;
    for (final e in entries) {
      switch (e.type) {
        case EntryType.supply:
          supply += e.totalUnits;
        case EntryType.sale:
          sale += e.totalUnits;
        case EntryType.manual:
          manual += 1;
      }
    }
    return Row(
      children: [
        Expanded(child: _Stat('Supplied', '$supply', AppColors.success)),
        const SizedBox(width: 10),
        Expanded(child: _Stat('Sold', '$sale', AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(child: _Stat('Adjustments', '$manual', AppColors.info)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSoft),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// The home actions. Every other screen is opened from here.
class _Actions extends StatelessWidget {
  const _Actions();

  @override
  Widget build(BuildContext context) {
    final actions = <({String label, String icon, Color color, Color soft, VoidCallback onTap})>[
      (
        label: 'Items',
        icon: AppSvgs.itemsIcon,
        color: AppColors.text,
        soft: AppColors.muted,
        onTap: () => context.push('/items'),
      ),
      (
        label: 'Inventory History',
        icon: AppSvgs.historyIcon,
        color: AppColors.text,
        soft: AppColors.muted,
        onTap: () => context.push('/history'),
      ),
      (
        label: 'Reports',
        icon: AppSvgs.reportIcon,
        color: AppColors.text,
        soft: AppColors.muted,
        onTap: () => context.push('/reports'),
      ),
      (
        label: 'New Supply Order',
        icon: AppSvgs.supplyIcon,
        color: AppColors.success,
        soft: AppColors.successSoft,
        onTap: () => context.push('/orders/supply'),
      ),
      (
        label: 'New Sale Order',
        icon: AppSvgs.saleIcon,
        color: AppColors.primary,
        soft: AppColors.primarySoft,
        onTap: () => context.push('/orders/sale'),
      ),
      (
        label: 'Adjust Stock',
        icon: AppSvgs.manualIcon,
        color: AppColors.info,
        soft: AppColors.infoSoft,
        onTap: () => context.push('/orders/manual'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        const gap = 12.0;
        final cols = c.maxWidth >= 1000 ? 6 : (c.maxWidth >= 560 ? 3 : 2);
        final tileWidth = (c.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final a in actions)
              SizedBox(
                width: tileWidth,
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  onTap: a.onTap,
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: a.soft,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: AppIcon(a.icon, size: 20, color: a.color),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          a.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
