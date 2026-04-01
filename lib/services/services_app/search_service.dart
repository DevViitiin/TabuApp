// lib/services/services_app/search_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:tabuapp/models/user_search.dart';

class SearchService {
  SearchService._();
  static final SearchService instance = SearchService._();

  final _db = FirebaseDatabase.instance;

  /// Busca todos os usuários excluindo [myUid].
  /// Ordena: quem está em [followingIds] primeiro, depois alfabético.
  Future<List<UserSearchResult>> fetchAllUsers({
    required String      myUid,
    required Set<String> followingIds,
  }) async {
    final snap = await _db.ref('Users').get();
    if (!snap.exists || snap.value == null) return [];

    final raw  = Map<dynamic, dynamic>.from(snap.value as Map);
    final list = <UserSearchResult>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      final uid = entry.key as String;
      if (uid == myUid) continue;

      final data = Map<String, dynamic>.from(entry.value as Map);
      final name = (data['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;

      final followersMap = data['followers'];
      final followingMap = data['following'];

      list.add(UserSearchResult(
        uid:            uid,
        name:           name,
        avatar:         data['avatar']    as String? ?? '',
        bio:            (data['bio']      as String? ?? '').trim(),
        city:           data['city']      as String? ?? '',
        state:          data['state']     as String? ?? '',
        followersCount: followersMap is Map ? followersMap.length : 0,
        followingCount: followingMap is Map ? followingMap.length : 0,
        latitude:       (data['latitude']  as num?)?.toDouble(),   // ← novo
        longitude:      (data['longitude'] as num?)?.toDouble(),   // ← novo
      ));
    }

    list.sort((a, b) {
      final aFollow = followingIds.contains(a.uid) ? 0 : 1;
      final bFollow = followingIds.contains(b.uid) ? 0 : 1;
      if (aFollow != bFollow) return aFollow.compareTo(bFollow);
      return a.name.compareTo(b.name);
    });

    return list;
  }

  // ── Normalização ─────────────────────────────────────────────────────────
  static String _normalize(String s) {
    const accents = 'àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ';
    const normal  = 'aaaaaaeceeeeiiiidnoooooouuuuyby';
    var r = s.toLowerCase();
    for (int i = 0; i < accents.length; i++) {
      r = r.replaceAll(accents[i], i < normal.length ? normal[i] : '');
    }
    return r;
  }

  static int _score(String candidate, String query) {
    if (candidate.isEmpty || query.isEmpty) return 0;
    final c = _normalize(candidate);
    final q = _normalize(query);

    if (c == q) return 100;
    if (c.startsWith(q)) return 80;
    if (c.contains(q)) return 60;

    final queryTokens = q.split(RegExp(r'\s+'))
        .where((t) => t.length >= 2).toList();
    if (queryTokens.isNotEmpty) {
      final allMatch = queryTokens.every((t) => c.contains(t));
      if (allMatch) return 50;
      final anyMatch = queryTokens.any((t) => c.contains(t));
      if (anyMatch) return 30;
    }

    final candidateWords = c.split(RegExp(r'\s+'));
    if (candidateWords.any((w) => w.startsWith(q))) return 40;

    return 0;
  }

  /// Filtra e ordena por relevância.
  List<UserSearchResult> filterAndRank({
    required List<UserSearchResult> all,
    required String                 query,
    String?                         estadoSigla,
    String?                         cidadeNome,
  }) {
    var pool = all;
    if (estadoSigla != null && estadoSigla.isNotEmpty) {
      final s = _normalize(estadoSigla);
      pool = pool.where((u) => _normalize(u.state) == s).toList();
    }
    if (cidadeNome != null && cidadeNome.isNotEmpty) {
      final c = _normalize(cidadeNome);
      pool = pool.where((u) => _normalize(u.city) == c).toList();
    }

    if (query.trim().isEmpty) return List.from(pool);

    final q = query.trim();
    final scored = <MapEntry<UserSearchResult, int>>[];
    for (final u in pool) {
      final nameScore = _score(u.name, q) * 3;
      final bioScore  = _score(u.bio,  q);
      final total = nameScore + bioScore;
      if (total > 0) scored.add(MapEntry(u, total));
    }

    scored.sort((a, b) {
      if (b.value != a.value) return b.value.compareTo(a.value);
      return a.key.name.compareTo(b.key.name);
    });

    return scored.map((e) => e.key).toList();
  }
}