// models/item.dart
/// "strawberry · 500ml"
String joinSubtitle(String variation, String size) => [variation, size].where((s) => s.trim().isNotEmpty).join(' · ');

class Item {
  const Item({
    required this.id,
    required this.name,
    required this.shortDesc,
    required this.size,
    required this.variation,
    required this.isActive,
    required this.stock,
    required this.createdBy,
    required this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
    this.itemSerial,
    this.brandId,
    this.brandName,
    this.categoryId,
    this.categoryName,
    this.imageUrl,
  });

  final String id;
  final String? itemSerial;
  final String name;
  final String shortDesc;
  final String size;
  final String variation;
  final bool isActive;
  final int stock;
  final String? brandId;
  final String? brandName;
  final String? categoryId;
  final String? categoryName;
  final String? imageUrl;
  final String createdBy;
  final String updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get subtitle => joinSubtitle(variation, size);

  factory Item.fromJson(Map<String, dynamic> j) {
    final brand = j['brands'] as Map<String, dynamic>?;
    final category = j['categories'] as Map<String, dynamic>?;

    // item_stock may come back as an object or a list with one object
    final stockRaw = j['item_stock'];
    final Map<String, dynamic>? stockMap = stockRaw is List
        ? (stockRaw.isEmpty ? null : stockRaw.first as Map<String, dynamic>)
        : stockRaw as Map<String, dynamic>?;

    return Item(
      id: j['id'] as String,
      itemSerial: j['item_serial'] as String?,
      name: j['name'] as String,
      shortDesc: (j['short_desc'] as String?) ?? '',
      size: (j['size'] as String?) ?? '',
      variation: (j['variation'] as String?) ?? '',
      isActive: (j['is_active'] as bool?) ?? true,
      stock: (stockMap?['quantity'] as int?) ?? 0,
      brandId: j['brand_id'] as String?,
      brandName: brand?['name'] as String?,
      categoryId: j['category_id'] as String?,
      categoryName: category?['name'] as String?,
      imageUrl: j['image_url'] as String?,
      createdBy: j['created_by'] as String,
      updatedBy: j['updated_by'] as String,
      createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
    );
  }
}

/// Values from the create/edit form.
class ItemInput {
  const ItemInput({
    required this.name,
    this.itemSerial,
    this.brandId,
    this.categoryId,
    this.imageUrl,
    this.shortDesc = '',
    this.size = '',
    this.variation = '',
  });

  final String? itemSerial;
  final String name;
  final String? brandId;
  final String? categoryId;
  final String? imageUrl;
  final String shortDesc;
  final String size;
  final String variation;

  Map<String, dynamic> toJson() => {
    // An empty serial is saved as "no serial" (null), never as an empty text.
    'item_serial': (itemSerial == null || itemSerial!.trim().isEmpty) ? null : itemSerial!.trim(),
    'name': name.trim(),
    'brand_id': brandId,
    'category_id': categoryId,
    'image_url': (imageUrl == null || imageUrl!.trim().isEmpty) ? null : imageUrl!.trim(),
    'short_desc': shortDesc.trim(),
    'size': size.trim(),
    'variation': variation.trim(),
  };
}
