// lib/services/services_app/report_service.dart
import 'package:firebase_database/firebase_database.dart';

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  final _db = FirebaseDatabase.instance.ref();

  // ── Denuncia um story ─────────────────────────────────────────────────────
  //
  // Estrutura no RTDB:
  //   Reports/
  //     stories/
  //       {reporterUid}_{storyId}/
  //         story_id, story_owner_id, reporter_uid,
  //         motivo, motivo_label, artigo, descricao,
  //         created_at, status
  //
  Future<void> reportStory({
    required String storyId,
    required String storyOwnerId,
    required String reporterUid,
    required String motivo,
    required String motivoLabel,
    required String artigo,
    String?         descricao,
  }) async {
    final key = '${reporterUid}_$storyId';

    await _db.child('Reports/stories/$key').set({
      'story_id':       storyId,
      'story_owner_id': storyOwnerId,
      'reporter_uid':   reporterUid,
      'motivo':         motivo,
      'motivo_label':   motivoLabel,
      'artigo':         artigo,
      'descricao':      descricao ?? '',
      'created_at':     ServerValue.timestamp,
      'status':         'pending', // pending | reviewed | dismissed
    });

    // Incrementa contador de reports no story para facilitar moderação
    await _db
        .child('Posts/story/$storyId/report_count')
        .runTransaction((data) {
      final current = (data as int?) ?? 0;
      return Transaction.success(current + 1);
    });
  }

  // ── Verifica se o usuário já denunciou este story ─────────────────────────
  Future<bool> jaReportou({
    required String reporterUid,
    required String storyId,
  }) async {
    final key      = '${reporterUid}_$storyId';
    final snapshot = await _db.child('Reports/stories/$key').get();
    return snapshot.exists;
  }
}