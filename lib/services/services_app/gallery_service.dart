// lib/services/services_app/gallery_service.dart

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:tabuapp/models/gallery_item_model.dart';

class GalleryService {
  static final GalleryService instance = GalleryService._();
  GalleryService._();

  final _db = FirebaseDatabase.instance.ref();

  // ── Criar galeria (apenas flag de que existe) ───────────────────────────────
  Future<void> createGallery(String userId) async {
    await _db.child('Gallery/$userId/created').set(true);
    await _db.child('Gallery/$userId/created_at')
        .set(DateTime.now().millisecondsSinceEpoch);
    await _db.child('Gallery/$userId/items').set({}); // ✅ Cria nó vazio
  }

  // ── Verificar se usuário tem galeria ────────────────────────────────────────
  Future<bool> hasGallery(String userId) async {
    final snap = await _db.child('Gallery/$userId/items').get();
    if (!snap.exists || snap.value == null) return false;
    
    final data = snap.value as Map<dynamic, dynamic>?;
    return data != null && data.isNotEmpty; // ✅ Verifica se tem itens
  }

  // ── Adicionar item à galeria ────────────────────────────────────────────────
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

  // ── Buscar itens da galeria ─────────────────────────────────────────────────
  Future<List<GalleryItem>> fetchItems(String userId) async {
  debugPrint('🔍 Buscando galeria de $userId...');
  final snap = await _db.child('Gallery/$userId/items').get();
  
  debugPrint('📦 Snap exists: ${snap.exists}, value: ${snap.value}');
  
  if (!snap.exists || snap.value == null) {
    debugPrint('❌ Galeria não existe');
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
    debugPrint('🔑 Item key: $key, value: $value');
    if (value is Map) {
      try {
        final itemMap = Map<String, dynamic>.from(value);
        itemMap['id'] = key;
        itemMap['userId'] = userId;
        final item = GalleryItem.fromMap(itemMap);
        items.add(item);
        debugPrint('✅ Item parse OK: ${item.id} - ${item.type}');
      } catch (e) {
        debugPrint('❌ Parse error [$key]: $e');
      }
    }
  });

  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  debugPrint('🎉 fetchItems FINAL: ${items.length} itens');
  return items;
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