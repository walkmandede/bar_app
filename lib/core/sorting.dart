// core/sorting.dart

final _chunkPattern = RegExp(r'\d+|\D+');

List<String> _chunks(String s) => _chunkPattern.allMatches(s).map((m) => m.group(0)!).toList();

/// Compares texts the way people expect: "SKU-2" comes before "SKU-10".
int compareNatural(String a, String b) {
  final ca = _chunks(a.toLowerCase());
  final cb = _chunks(b.toLowerCase());
  final n = ca.length < cb.length ? ca.length : cb.length;

  for (var i = 0; i < n; i++) {
    final x = ca[i];
    final y = cb[i];
    final nx = int.tryParse(x);
    final ny = int.tryParse(y);
    final c = (nx != null && ny != null) ? nx.compareTo(ny) : x.compareTo(y);
    if (c != 0) return c;
  }
  return ca.length.compareTo(cb.length);
}

/// Sorts by code. Items without a code go last.
int compareCodes(String? a, String? b) {
  final emptyA = a == null || a.trim().isEmpty;
  final emptyB = b == null || b.trim().isEmpty;
  if (emptyA && emptyB) return 0;
  if (emptyA) return 1;
  if (emptyB) return -1;
  return compareNatural(a.trim(), b.trim());
}
