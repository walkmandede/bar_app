// models/lookup.dart
/// Used for brands and categories (id + name).
class Lookup {
  const Lookup({required this.id, required this.name});

  final String id;
  final String name;

  factory Lookup.fromJson(Map<String, dynamic> j) => Lookup(id: j['id'] as String, name: j['name'] as String);
}
