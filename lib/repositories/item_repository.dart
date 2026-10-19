// repositories/item_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../core/app_exception.dart';
import '../models/item.dart';
import '../models/lookup.dart';

class ItemRepository {
  ItemRepository(this._db);
  final SupabaseClient _db;

  static const _select = '*, brands(id,name), categories(id,name), item_stock(quantity)';

  Future<List<Item>> fetchItems() async {
    final rows = await _db.from('items').select(_select).eq('is_active', true).order('name');
    return rows.map((r) => Item.fromJson(r)).toList();
  }

  Future<Item> fetchItem(String id) async {
    final row = await _db.from('items').select(_select).eq('id', id).maybeSingle();
    if (row == null) throw const AppException('Item not found.');
    return Item.fromJson(row);
  }

  Future<void> createItem(String userId, ItemInput input) async {
    await _db.from('items').insert({
      ...input.toJson(),
      'created_by': userId,
      'updated_by': userId,
    });
  }

  Future<void> updateItem(String id, String userId, ItemInput input) async {
    await _db
        .from('items')
        .update({
          ...input.toJson(),
          'updated_by': userId,
        })
        .eq('id', id);
  }

  /// "Delete" hides the item. History stays safe.
  Future<void> archiveItem(String id, String userId) async {
    await _db.from('items').update({'is_active': false, 'updated_by': userId}).eq('id', id);
  }

  Future<List<Lookup>> fetchBrands() => _fetchLookup('brands');
  Future<List<Lookup>> fetchCategories() => _fetchLookup('categories');
  Future<Lookup> createBrand(String name) => _createLookup('brands', name);
  Future<Lookup> createCategory(String name) => _createLookup('categories', name);

  Future<List<Lookup>> _fetchLookup(String table) async {
    final rows = await _db.from(table).select('id, name').order('name');
    return rows.map((r) => Lookup.fromJson(r)).toList();
  }

  Future<Lookup> _createLookup(String table, String name) async {
    final row = await _db.from(table).insert({'name': name.trim()}).select('id, name').single();
    return Lookup.fromJson(row);
  }
}
