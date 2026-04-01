// lib/services/services_app/admin_service.dart
import 'package:firebase_database/firebase_database.dart';

class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  final _db = FirebaseDatabase.instance.ref();

  // Cache local para não bater no banco a cada rebuild
  bool?   _isAdmin;
  String? _cachedUid;

  /// Verifica se [uid] existe em Administratives/{uid} == true
  Future<bool> isAdmin(String uid) async {
    if (uid.isEmpty) return false;
    if (_cachedUid == uid && _isAdmin != null) return _isAdmin!;

    try {
      final snap = await _db.child('Administratives/$uid').get();
      _cachedUid = uid;
      _isAdmin   = snap.exists && snap.value == true;
      return _isAdmin!;
    } catch (_) {
      return false;
    }
  }

  /// Limpa o cache (usar no logout)
  void clearCache() {
    _isAdmin   = null;
    _cachedUid = null;
  }
}