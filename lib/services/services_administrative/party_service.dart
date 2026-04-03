// lib/services/services_administrative/party_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:tabuapp/models/party_model.dart';

class PartyService {
  PartyService._();
  static final PartyService instance = PartyService._();

  final _db = FirebaseDatabase.instance;

  DatabaseReference get _festasRef => _db.ref('Festas');
  DatabaseReference _festaRef(String id) => _festasRef.child(id);

  // ── Criar ──────────────────────────────────────────────────────────────────
  Future<String> createFesta({
    required String creatorId,
    required String creatorName,
    String? creatorAvatar,
    required String nome,
    required String descricao,
    String? local, // agora opcional — null = "não confirmado"
    String? bairro,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    required DateTime dataInicio,
    required DateTime dataFim,
    String? bannerUrl,
  }) async {
    final ref = _festasRef.push();
    final festa = PartyModel(
      id: ref.key!,
      creatorId: creatorId,
      creatorName: creatorName,
      creatorAvatar: creatorAvatar,
      nome: nome,
      descricao: descricao,
      local: (local != null && local.trim().isNotEmpty) ? local : null,
      bairro: bairro,
      city: city,
      state: state,
      latitude: latitude,
      longitude: longitude,
      dataInicio: dataInicio,
      dataFim: dataFim,
      bannerUrl: bannerUrl,
      createdAt: DateTime.now(),
      status: 'ativa',
    );
    await ref.set(festa.toMap());
    return ref.key!;
  }

  // ── Buscar (só ativas) ─────────────────────────────────────────────────────
  Future<List<PartyModel>> fetchFestas({int limit = 20}) async {
    final snap = await _festasRef.get();
    if (!snap.exists || snap.value == null) return [];

    final raw = Map<dynamic, dynamic>.from(snap.value as Map);
    final list = <PartyModel>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      try {
        final festa = PartyModel.fromMap(
          entry.key as String,
          Map<dynamic, dynamic>.from(entry.value as Map),
        );
        if (festa.isAtiva && !festa.estaVencida) {
          list.add(festa);
        }
      } catch (_) {}
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList();
  }

  /// Busca festas arquivadas — útil para histórico no painel admin.
  Future<List<PartyModel>> fetchFestasArquivadas({int limit = 50}) async {
    final snap = await _festasRef.get();
    if (!snap.exists || snap.value == null) return [];

    final raw = Map<dynamic, dynamic>.from(snap.value as Map);
    final list = <PartyModel>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      try {
        final festa = PartyModel.fromMap(
          entry.key as String,
          Map<dynamic, dynamic>.from(entry.value as Map),
        );
        if (festa.isArquivada || festa.estaVencida) list.add(festa);
      } catch (_) {}
    }

    list.sort((a, b) => b.dataFim.compareTo(a.dataFim));
    return list.take(limit).toList();
  }

  /// Arquiva manualmente uma festa.
  Future<void> arquivarFesta(String festaId) async {
    await _festaRef(festaId).update({'status': 'arquivada'});
  }

  // ── Presença ───────────────────────────────────────────────────────────────
  Future<FestaPresenca> getPresenca(String festaId, String uid) async {
    final snap = await _db.ref('Festas/$festaId/presenca/$uid').get();
    if (!snap.exists) return FestaPresenca.nenhuma;
    final v = snap.value as String?;
    if (v == 'confirmado') return FestaPresenca.confirmado;
    if (v == 'interessado') return FestaPresenca.interessado;
    return FestaPresenca.nenhuma;
  }

  Future<FestaPresenca> togglePresenca(
      String festaId, String uid, FestaPresenca atual) async {
    final ref = _db.ref('Festas/$festaId/presenca/$uid');

    switch (atual) {
      case FestaPresenca.nenhuma:
        await ref.set('interessado');
        await _db.ref('Festas/$festaId/interessados').runTransaction(
            (val) => Transaction.success((val is int) ? val + 1 : 1));
        return FestaPresenca.interessado;

      case FestaPresenca.interessado:
        await ref.set('confirmado');
        await _db.ref('Festas/$festaId/interessados').runTransaction((val) =>
            Transaction.success((val is int && val > 0) ? val - 1 : 0));
        await _db.ref('Festas/$festaId/confirmados').runTransaction(
            (val) => Transaction.success((val is int) ? val + 1 : 1));
        return FestaPresenca.confirmado;

      case FestaPresenca.confirmado:
        await ref.remove();
        await _db.ref('Festas/$festaId/confirmados').runTransaction((val) =>
            Transaction.success((val is int && val > 0) ? val - 1 : 0));
        return FestaPresenca.nenhuma;
    }
  }

  // ── Comentários ────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchComentarios(String festaId) async {
    final snap = await _db.ref('Festas/$festaId/comentarios').get();
    if (!snap.exists || snap.value == null) return [];

    final raw = Map<dynamic, dynamic>.from(snap.value as Map);
    final list = <Map<String, dynamic>>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      final data = Map<String, dynamic>.from(entry.value as Map);
      data['id'] = entry.key;
      list.add(data);
    }

    list.sort((a, b) =>
        (a['created_at'] as int? ?? 0).compareTo(b['created_at'] as int? ?? 0));
    return list;
  }

  Future<void> addComentario({
    required String festaId,
    required String uid,
    required String userName,
    String? userAvatar,
    required String texto,
  }) async {
    final ref = _db.ref('Festas/$festaId/comentarios').push();
    await ref.set({
      'user_id': uid,
      'user_name': userName,
      if (userAvatar != null) 'user_avatar': userAvatar,
      'texto': texto,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await _db.ref('Festas/$festaId/comment_count').runTransaction(
        (val) => Transaction.success((val is int) ? val + 1 : 1));
  }

  Future<void> deleteFesta(String festaId) async {
    await _festaRef(festaId).remove();
  }

  Future<void> updateFesta(String festaId, Map<String, dynamic> updates) async {
    // Firebase RTDB não aceita update de chave com valor null para remoção.
    // É necessário separar os campos que devem ser removidos dos que serão escritos.
    final toWrite = <String, dynamic>{};
    final toRemove = <String>[];

    for (final entry in updates.entries) {
      if (entry.value == null) {
        toRemove.add(entry.key);
      } else {
        toWrite[entry.key] = entry.value;
      }
    }

    final ref = _festaRef(festaId);

    // Grava os campos preenchidos
    if (toWrite.isNotEmpty) {
      await ref.update(toWrite);
    }

    // Remove os campos nulos um a um
    for (final key in toRemove) {
      await ref.child(key).remove();
    }
  }
}
