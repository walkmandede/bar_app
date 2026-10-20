// features/items/items_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_svgs.dart';
import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../models/item.dart';
import '../../providers/providers.dart';

enum _ViewMode { grid, list, table }

enum _Sort { nameAsc, nameDesc, stockLow, stockHigh, newest }

enum _StockFilter { all, inStock, outOfStock }

const _stockLabels = {
  _StockFilter.all: 'All',
  _StockFilter.inStock: 'In stock',
  _StockFilter.outOfStock: 'Out of stock',
};

const _sortLabels = {
  _Sort.nameAsc: 'Name A-Z',
  _Sort.nameDesc: 'Name Z-A',
  _Sort.stockLow: 'Stock low-high',
  _Sort.stockHigh: 'Stock high-low',
  _Sort.newest: 'Newest',
};

class ItemsPage extends ConsumerStatefulWidget {
  const ItemsPage({super.key});

  @override
  ConsumerState<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends ConsumerState<ItemsPage> {
  String _query = '';
  String _brandId = ''; // '' means all
  String _categoryId = '';
  _StockFilter _stock = _StockFilter.all;
  _Sort _sort = _Sort.nameAsc;
  _ViewMode _view = _ViewMode.grid;

  /// Search, filter, and sort on the device. Fine for a bar-sized item list.
  List<Item> _apply(List<Item> items) {
    final q = _query.trim().toLowerCase();
    final list = items.where((i) {
      if (_brandId.isNotEmpty && i.brandId != _brandId) return false;
      if (_categoryId.isNotEmpty && i.categoryId != _categoryId) return false;
      if (_stock == _StockFilter.inStock && i.stock == 0) return false;
      if (_stock == _StockFilter.outOfStock && i.stock != 0) return false;
      if (q.isEmpty) return true;
      final text = [
        i.name,
        i.itemSerial ?? '',
        i.brandName ?? '',
        i.categoryName ?? '',
        i.variation,
        i.size,
        i.shortDesc,
      ].join(' ').toLowerCase();
      return text.contains(q);
    }).toList();

    int byName(Item a, Item b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());

    switch (_sort) {
      case _Sort.nameAsc:
        list.sort(byName);
      case _Sort.nameDesc:
        list.sort((a, b) => byName(b, a));
      case _Sort.stockLow:
        list.sort((a, b) => a.stock.compareTo(b.stock));
      case _Sort.stockHigh:
        list.sort((a, b) => b.stock.compareTo(a.stock));
      case _Sort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  /// Brands or categories that exist in the item list. '' = All.
  Map<String, String> _lookupOptions(List<Item> items, {required bool brand}) {
    final found = <String, String>{};
    for (final i in items) {
      final id = brand ? i.brandId : i.categoryId;
      final name = brand ? i.brandName : i.categoryName;
      if (id != null) found[id] = name ?? '';
    }
    final sorted = found.entries.toList()..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return {'': 'All', for (final e in sorted) e.key: e.value};
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(itemsProvider);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Items',
            subtitle: async.hasValue ? '${async.requireValue.length} items' : null,
            trailing: FilledButton.icon(
              onPressed: () => context.push('/items/new'),
              icon: AppIcon(AppSvgs.addIcon, size: 18, color: Colors.white),
              label: const Text('New item'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search name, serial, brand...',
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
          const SizedBox(height: 12),
          async.when(
            loading: () => const Expanded(child: LoadingView()),
            error: (e, _) => Expanded(
              child: ErrorState(
                error: e,
                onRetry: () => ref.invalidate(itemsProvider),
              ),
            ),
            data: (items) {
              final shown = _apply(items);
              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _controls(items),
                    const SizedBox(height: 14),
                    Expanded(
                      child: items.isEmpty
                          ? EmptyState(
                              message: 'No items yet. Create your first item.',
                              action: FilledButton(
                                onPressed: () => context.push('/items/new'),
                                child: const Text('New item'),
                              ),
                            )
                          : shown.isEmpty
                          ? const EmptyState(
                              message: 'No items match your search.',
                            )
                          : switch (_view) {
                              _ViewMode.grid => _ItemGrid(items: shown),
                              _ViewMode.list => _ItemList(items: shown),
                              _ViewMode.table => _ItemTable(items: shown),
                            },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _controls(List<Item> items) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _MenuChip<String>(
            label: 'Brand',
            icon: AppSvgs.filterIcon,
            value: _brandId,
            options: _lookupOptions(items, brand: true),
            onSelected: (v) => setState(() => _brandId = v),
          ),
          const SizedBox(width: 8),
          _MenuChip<String>(
            label: 'Category',
            icon: AppSvgs.filterIcon,
            value: _categoryId,
            options: _lookupOptions(items, brand: false),
            onSelected: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(width: 8),
          _MenuChip<_StockFilter>(
            label: 'Stock',
            value: _stock,
            options: _stockLabels,
            onSelected: (v) => setState(() => _stock = v),
          ),
          const SizedBox(width: 8),
          _MenuChip<_Sort>(
            label: 'Sort',
            icon: AppSvgs.sortIcon,
            value: _sort,
            options: _sortLabels,
            onSelected: (v) => setState(() => _sort = v),
          ),
          const SizedBox(width: 12),
          _ViewToggle(
            value: _view,
            onChanged: (v) => setState(() => _view = v),
          ),
        ],
      ),
    );
  }
}

/// A pill button that opens a small menu.
class _MenuChip<T extends Object> extends StatelessWidget {
  const _MenuChip({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final String? icon;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: label,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final e in options.entries) PopupMenuItem<T>(value: e.key, child: Text(e.value)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              AppIcon(icon!, size: 16, color: AppColors.textSoft),
              const SizedBox(width: 8),
            ],
            Text(
              '$label: ${options[value] ?? 'All'}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            RotatedBox(
              quarterTurns: 1,
              child: AppIcon(
                AppSvgs.chevronRightIcon,
                size: 14,
                color: AppColors.textSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.value, required this.onChanged});

  final _ViewMode value;
  final ValueChanged<_ViewMode> onChanged;

  static const _icons = {
    _ViewMode.grid: AppSvgs.gridIcon,
    _ViewMode.list: AppSvgs.listIcon,
    _ViewMode.table: AppSvgs.tableIcon,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in _icons.entries)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onChanged(e.key),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: e.key == value ? AppColors.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AppIcon(
                  e.value,
                  size: 18,
                  color: e.key == value ? AppColors.primary : AppColors.textSoft,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({required this.items});

  final List<Item> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.75,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return AppCard(
          padding: const EdgeInsets.all(10),
          onTap: () => context.push('/items/${item.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: ItemThumb(url: item.imageUrl, expand: true)),
              const SizedBox(height: 8),
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
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: StockBadge(item.stock),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({required this.items});

  final List<Item> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final item = items[i];
        final meta = [item.brandName, item.categoryName].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
        return AppCard(
          padding: const EdgeInsets.all(12),
          onTap: () => context.push('/items/${item.id}'),
          child: Row(
            children: [
              ItemThumb(url: item.imageUrl, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (item.subtitle.isNotEmpty)
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSoft,
                        ),
                      ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSoft,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StockBadge(item.stock),
            ],
          ),
        );
      },
    );
  }
}

class _ItemTable extends StatelessWidget {
  const _ItemTable({required this.items});

  final List<Item> items;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: false,
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSoft,
            ),
            columns: const [
              DataColumn(label: Text('Serial')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Brand')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Size')),
              DataColumn(label: Text('Variation')),
              DataColumn(label: Text('Stock'), numeric: true),
            ],
            rows: [
              for (final i in items)
                DataRow(
                  onSelectChanged: (_) => context.push('/items/${i.id}'),
                  cells: [
                    DataCell(Text(i.itemSerial ?? '-')),
                    DataCell(Text(i.name)),
                    DataCell(Text(i.brandName ?? '-')),
                    DataCell(Text(i.categoryName ?? '-')),
                    DataCell(Text(i.size.isEmpty ? '-' : i.size)),
                    DataCell(Text(i.variation.isEmpty ? '-' : i.variation)),
                    DataCell(
                      Text(
                        '${i.stock}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: i.stock == 0 ? AppColors.danger : AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
