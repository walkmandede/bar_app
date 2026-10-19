// providers/providers.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, SupabaseClient;

import '../models/app_user.dart';
import '../models/inventory_entry.dart';
import '../models/item.dart';
import '../models/lookup.dart';
import '../repositories/auth_repository.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/item_repository.dart';

// ---------- Core ----------

/// Overridden in main.dart.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider not overridden'),
);

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(supabaseProvider)));
final itemRepositoryProvider = Provider((ref) => ItemRepository(ref.watch(supabaseProvider)));
final inventoryRepositoryProvider = Provider((ref) => InventoryRepository(ref.watch(supabaseProvider)));

// ---------- Auth ----------

class AuthNotifier extends Notifier<AppUser?> {
  static const _key = 'app_user';

  @override
  AppUser? build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> login(String username, String password) async {
    final user = await ref.read(authRepositoryProvider).login(username, password);
    await ref.read(sharedPrefsProvider).setString(_key, jsonEncode(user.toJson()));
    state = user;
  }

  Future<void> logout() async {
    await ref.read(sharedPrefsProvider).remove(_key);
    state = null;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);

// ---------- Data ----------

final itemsProvider = FutureProvider.autoDispose<List<Item>>(
  (ref) => ref.watch(itemRepositoryProvider).fetchItems(),
);

final itemProvider = FutureProvider.autoDispose.family<Item, String>(
  (ref, id) => ref.watch(itemRepositoryProvider).fetchItem(id),
);

final brandsProvider = FutureProvider.autoDispose<List<Lookup>>(
  (ref) => ref.watch(itemRepositoryProvider).fetchBrands(),
);

final categoriesProvider = FutureProvider.autoDispose<List<Lookup>>(
  (ref) => ref.watch(itemRepositoryProvider).fetchCategories(),
);

/// Entries for one day. Pass a date with no time (year, month, day).
final entriesByDayProvider = FutureProvider.autoDispose.family<List<InventoryEntry>, DateTime>(
  (ref, day) => ref.watch(inventoryRepositoryProvider).fetchEntries(from: day, to: day),
);

typedef HistoryQuery = ({EntryType? type, DateTime? from, DateTime? to});

final historyProvider = FutureProvider.autoDispose.family<List<InventoryEntry>, HistoryQuery>(
  (ref, q) => ref.watch(inventoryRepositoryProvider).fetchEntries(from: q.from, to: q.to, type: q.type),
);

final itemHistoryProvider = FutureProvider.autoDispose.family<List<ItemHistoryRow>, String>(
  (ref, itemId) => ref.watch(inventoryRepositoryProvider).fetchItemHistory(itemId),
);

/// Call after any change so every screen reloads fresh data.
void refreshAll(WidgetRef ref) {
  ref.invalidate(itemsProvider);
  ref.invalidate(itemProvider);
  ref.invalidate(brandsProvider);
  ref.invalidate(categoriesProvider);
  ref.invalidate(entriesByDayProvider);
  ref.invalidate(historyProvider);
  ref.invalidate(itemHistoryProvider);
}
