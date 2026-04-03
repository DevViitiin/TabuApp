// lib/services/services_app/gallery_service.dart

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:tabuapp/models/gallery_item_model.dart';

class GalleryService {
  static final GalleryService instance = GalleryService._();
  GalleryService._();

  final _db = FirebaseDatabase.instance.ref();

  // ── Criar galeria ───────────────────────────────────────────────────────────
  Future<void> createGallery(String userId) async {
    await _db.child('Gallery/$userId/created').set(true);
    await _db.child('Gallery/$userId/created_at')
        .set(DateTime.now().millisecondsSinceEpoch);
    await _db.child('Gallery/$userId/items').set({});
  }

  // ── Verificar se tem galeria ────────────────────────────────────────────────
  Future<bool> hasGallery(String userId) async {
    final snap = await _db.child('Gallery/$userId/items').get();
    if (!snap.exists || snap.value == null) return false;
    final data = snap.value as Map<dynamic, dynamic>?;
    return data != null && data.isNotEmpty;
  }

  // ── Adicionar item ─────────────────────────────────────────────────────────
  Future<void> addItem({
    required String userId,
    required String type,
    required String mediaUrl,
    String? thumbUrl,
    int? videoDuration,
  }) async {
    final itemRef = _db.child('Gallery/$userId/items').push();
    final item = GalleryItem(
      id: itemRef.key!,
      userId: userId,
      type: type,
      mediaUrl: mediaUrl,
      thumbUrl: thumbUrl,
      videoDuration: videoDuration,
      createdAt: DateTime.now(),
    );
    await itemRef.set(item.toMap());
  }

  // ── Buscar itens (com paginação por cursor de data) ─────────────────────────
  //
  // [limit]       – máximo de itens retornados (default 15)
  // [startAfter]  – cursor: retorna apenas itens com createdAt < startAfter
  //                 (ordenação decrescente → itens mais antigos que o cursor)
  //
  Future<List<GalleryItem>> fetchItems(
    String userId, {
    int limit = 15,
    DateTime? startAfter,
  }) async {
    debugPrint('🔍 Buscando galeria de $userId (limit=$limit, cursor=$startAfter)');
    final snap = await _db.child('Gallery/$userId/items').get();

    debugPrint('📦 Snap exists: ${snap.exists}, value: ${snap.value}');

    if (!snap.exists || snap.value == null) {
      debugPrint('❌ Galeria não existe ou vazia');
      return [];
    }

    final raw = snap.value;
    if (raw is! Map) {
      debugPrint('❌ Value não é Map: $raw');
      return [];
    }

    final data = Map<String, dynamic>.from(raw as Map);
    debugPrint('📊 Itens raw: ${data.length}');

    final items = <GalleryItem>[];
    data.forEach((key, value) {
      if (value is Map) {
        try {
          final itemMap = Map<String, dynamic>.from(value);
          itemMap['id'] = key;
          itemMap['userId'] = userId;
          final item = GalleryItem.fromMap(itemMap);

          // Filtro de paginação: só itens mais antigos que o cursor
          if (startAfter != null && !item.createdAt.isBefore(startAfter)) return;

          items.add(item);
        } catch (e) {
          debugPrint('❌ Parse error [$key]: $e');
        }
      }
    });

    // Ordena por data decrescente e limita ao pageSize
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final page = items.take(limit).toList();

    debugPrint('🎉 fetchItems FINAL: ${page.length} itens');
    return page;
  }

  // ── Deletar item ────────────────────────────────────────────────────────────
  Future<void> deleteItem(String userId, String itemId) async {
    await _db.child('Gallery/$userId/items/$itemId').remove();
  }

  // ── Contar itens ────────────────────────────────────────────────────────────
  Future<int> countItems(String userId) async {
    final snap = await _db.child('Gallery/$userId/items').get();
    if (!snap.exists) return 0;
    final data = snap.value as Map<dynamic, dynamic>;
    return data.length;
  }
}