// lib/services/services_app/report_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

enum ReportMotivo {
  conteudoOfensivo,
  discursoOdio,
  assedio,
  informacaoFalsa,
  conteudoImproprio,
  violacaoPrivacidade,
  spam,
  violacaoTermos,
}

extension ReportMotivoLabel on ReportMotivo {
  String get label {
    switch (this) {
      case ReportMotivo.conteudoOfensivo:    return 'Conteúdo ofensivo ou prejudicial';
      case ReportMotivo.discursoOdio:        return 'Discurso de ódio ou discriminação';
      case ReportMotivo.assedio:             return 'Assédio ou intimidação';
      case ReportMotivo.informacaoFalsa:     return 'Informação falsa ou enganosa';
      case ReportMotivo.conteudoImproprio:   return 'Conteúdo inapropriado para menores';
      case ReportMotivo.violacaoPrivacidade: return 'Violação de privacidade';
      case ReportMotivo.spam:                return 'Spam ou conteúdo repetitivo';
      case ReportMotivo.violacaoTermos:      return 'Violação dos Termos de Uso';
    }
  }

  String get artigo {
    switch (this) {
      case ReportMotivo.conteudoOfensivo:    return 'Art. 10º, II';
      case ReportMotivo.discursoOdio:        return 'Art. 10º, II';
      case ReportMotivo.assedio:             return 'Art. 10º, II';
      case ReportMotivo.informacaoFalsa:     return 'Art. 6º';
      case ReportMotivo.conteudoImproprio:   return 'Art. 1º';
      case ReportMotivo.violacaoPrivacidade: return 'Art. 5º (LGPD)';
      case ReportMotivo.spam:                return 'Art. 10º, II';
      case ReportMotivo.violacaoTermos:      return 'Art. 10º, III';
    }
  }
}

class ReportService {
  static final ReportService instance = ReportService._();
  ReportService._();

  final _db   = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  Future<void> reportPost({
    required String postId,
    required String postOwnerId,
    required ReportMotivo motivo,
    required String descricao,
  }) async {
    if (_uid.isEmpty) throw Exception('Usuário não autenticado');

    final reportId = '${_uid}_$postId';
    final now      = DateTime.now().millisecondsSinceEpoch;

    await _db.child('Reports/posts/$reportId').set({
      'post_id':       postId,
      'post_owner_id': postOwnerId,
      'reporter_uid':  _uid,
      'motivo':        motivo.name,
      'motivo_label':  motivo.label,
      'artigo':        motivo.artigo,
      'descricao':     descricao.trim(),
      'status':        'pending', // pending | reviewed | resolved | dismissed
      'created_at':    now,
    });

    // Incrementa contador de denúncias no post para análise do admin
    await _db.child('Posts/post/$postId/report_count')
        .runTransaction((current) => Transaction.success(((current as int?) ?? 0) + 1));
  }

  /// Verifica se o usuário já denunciou este post nesta sessão
  Future<bool> jaReportou(String postId) async {
    if (_uid.isEmpty) return false;
    final snap = await _db.child('Reports/posts/${_uid}_$postId').get();
    return snap.exists;
  }
}