// lib/services/services_app/presence_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class PresenceService {
  PresenceService._();
  static final instance = PresenceService._();

  DatabaseReference? _presenceRef;
  bool _initialized = false;

  /// Chama no login / quando o usuário está autenticado.
  Future<void> init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _initialized) return;
    _initialized = true;

    _presenceRef = FirebaseDatabase.instance.ref('Users/$uid/presence');

    // Observa a conexão do Firebase com o servidor
    final connectedRef = FirebaseDatabase.instance.ref('.info/connected');

    connectedRef.onValue.listen((event) async {
      final connected = event.snapshot.value as bool? ?? false;
      if (!connected) return;

      // Quando DESCONECTAR (por qualquer motivo), o Firebase executa isso no servidor
      await _presenceRef!.onDisconnect().update({
        'online': false,
        'last_seen': ServerValue.timestamp,
      });

      // Marca como online agora
      await _presenceRef!.update({
        'online': true,
        'last_seen': ServerValue.timestamp,
      });
    });
  }

  /// Chama no logout explícito (para marcar offline imediatamente).
  Future<void> setOffline() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseDatabase.instance.ref('Users/$uid/presence').update({
      'online': false,
      'last_seen': ServerValue.timestamp,
    });
    _initialized = false;
    _presenceRef = null;
  }
}