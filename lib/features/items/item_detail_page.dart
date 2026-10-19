// features/items/item_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_exception.dart';
import '../../core/app_svgs.dart';
import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../models/item.dart';
import '../../providers/providers.dart';

/// Looks up a user's display name by id.
final _userNameProvider = FutureProvider.autoDispose.family<String, String>((ref, id) async {
  final row = await ref.watch(supabaseProvider).from('app_users').select('display_name').eq('id', id).maybeSingle();
  return (row?['display_name'] as String?) ?? 'Unknown';
});

class ItemDetailPage extends ConsumerWidget {
  const ItemDetailPage({super.key, required this.itemId});

  final String itemId;

  Future<void> _archive(BuildContext context, WidgetRef ref, Item item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete item?'),
        content: Text(
          '"${item.name}" will be removed from the item list.'
          '${item.stock > 0 ? ' It still has ${item.stock} in stock.' : ''}'
          ' Its stock history is kept.',
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
    if (ok != true) return;

    final user = ref.read(authProvider);
    if (user == null) return;
    try {
      await ref.read(itemRepositoryProvider).archiveItem(item.id, user.id);
      refreshAll(ref);
      if (context.mounted) {
        showMessage(context, 'Item deleted');
        goBackOr(context, '/items');
      }
    } catch (e) {
      if (context.mounted) showMessage(context, errorMessage(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(itemProvider(itemId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => goBackOr(context, '/items'),
          icon: AppIcon(AppSvgs.chevronLeftIcon, color: AppColors.text),
        ),
        title: const Text('Item'),
        actions: async.hasValue
            ? [
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () => context.push('/items/$itemId/edit'),
                  icon: AppIcon(AppSvgs.editIcon, color: AppColors.text),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () => _archive(context, ref, async.requireValue),
                  icon: AppIcon(AppSvgs.deleteIcon, color: AppColors.danger),
                ),
              ]
            : null,
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(itemProvider(itemId)),
        ),
        data: (item) => SingleChildScrollView(
          child: PageContainer(
            child: LayoutBuilder(
              builder: (context, c) {
                final info = _InfoCard(item: item);
                final history = _History(itemId: item.id);
                if (c.maxWidth < 860) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [info, const SizedBox(height: 16), history],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 380, child: info),
                    const SizedBox(width: 20),
                    Expanded(child: history),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends ConsumerWidget {
  const _InfoCard({required this.item});

  final Item item;

  static final _dateFmt = DateFormat('d MMM yyyy, h:mm a');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final createdBy = ref.watch(_userNameProvider(item.createdBy)).asData?.value ?? '...';
    final updatedBy = ref.watch(_userNameProvider(item.updatedBy)).asData?.value ?? '...';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 200,
            child: ItemThumb(url: item.imageUrl, expand: true),
          ),
          const SizedBox(height: 16),
          Text(
            item.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          if (item.subtitle.isNotEmpty) Text(item.subtitle, style: const TextStyle(color: AppColors.textSoft)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.stock}',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: item.stock == 0 ? AppColors.danger : AppColors.text,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('in stock', style: TextStyle(color: AppColors.textSoft)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => context.push('/orders/supply?item=${item.id}'),
                child: const Text('Add supply'),
              ),
              OutlinedButton(
                onPressed: () => context.push('/orders/sale?item=${item.id}'),
                child: const Text('Record sale'),
              ),
              OutlinedButton(
                onPressed: () => context.push('/orders/manual?item=${item.id}'),
                child: const Text('Adjust stock'),
              ),
            ],
          ),
          const Divider(height: 32),
          _InfoRow('Serial', item.itemSerial),
          _InfoRow('Brand', item.brandName),
          _InfoRow('Category', item.categoryName),
          _InfoRow('Size', item.size),
          _InfoRow('Variation', item.variation),
          _InfoRow('Description', item.shortDesc),
          _InfoRow('Created', '${_dateFmt.format(item.createdAt)}\nby $createdBy'),
          _InfoRow('Updated', '${_dateFmt.format(item.updatedAt)}\nby $updatedBy'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = (value == null || value!.trim().isEmpty) ? '-' : value!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: const TextStyle(color: AppColors.textSoft)),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(itemHistoryProvider(itemId));
    final dateFmt = DateFormat('d MMM yyyy');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Stock history',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const SizedBox(height: 100, child: LoadingView()),
            error: (e, _) => ErrorState(
              error: e,
              onRetry: () => ref.invalidate(itemHistoryProvider(itemId)),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No stock changes yet.',
                      style: TextStyle(color: AppColors.textSoft),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 56,
                            child: Text(
                              signed(rows[i].quantityChange),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: rows[i].quantityChange > 0 ? AppColors.success : AppColors.danger,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    TypeChip(rows[i].type),
                                    if (rows[i].referenceNo != null) ...[
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          '#${rows[i].referenceNo}',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${dateFmt.format(rows[i].entryDate)} · by ${rows[i].createdByName}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSoft,
                                  ),
                                ),
                                if (rows[i].note != null)
                                  Text(
                                    rows[i].note!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.textSoft,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
