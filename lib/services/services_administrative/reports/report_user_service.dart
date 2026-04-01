// lib/services/services_administrative/reports/report_user_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  MOTIVOS DE DENÚNCIA DE USUÁRIO
// ══════════════════════════════════════════════════════════════════════════════
enum ReportUserMotivo {
  condutaAbusiva,
  conteudoImproprioAtivo,
  assedio,
  identidadeFalsa,
  spamSolicitacoes,
  violacaoPrivacidade,
  discursoOdio,
  outro,
}

extension ReportUserMotivoExt on ReportUserMotivo {
  String get label {
    switch (this) {
      case ReportUserMotivo.condutaAbusiva:
        return 'Conduta abusiva ou agressiva';
      case ReportUserMotivo.conteudoImproprioAtivo:
        return 'Publicações com conteúdo impróprio';
      case ReportUserMotivo.assedio:
        return 'Assédio ou perseguição';
      case ReportUserMotivo.identidadeFalsa:
        return 'Identidade falsa ou conta falsa';
      case ReportUserMotivo.spamSolicitacoes:
        return 'Spam ou solicitações em massa';
      case ReportUserMotivo.violacaoPrivacidade:
        return 'Violação de privacidade';
      case ReportUserMotivo.discursoOdio:
        return 'Discurso de ódio ou discriminação';
      case ReportUserMotivo.outro:
        return 'Outro motivo';
    }
  }

  String get artigo {
    switch (this) {
      case ReportUserMotivo.condutaAbusiva:
        return 'Art. 10º, II – Código de Conduta';
      case ReportUserMotivo.conteudoImproprioAtivo:
        return 'Art. 10º, I e II – Código de Conduta';
      case ReportUserMotivo.assedio:
        return 'Art. 10º, II – Código de Conduta';
      case ReportUserMotivo.identidadeFalsa:
        return 'Art. 6º – Termos de Uso';
      case ReportUserMotivo.spamSolicitacoes:
        return 'Art. 10º, II – Código de Conduta';
      case ReportUserMotivo.violacaoPrivacidade:
        return 'Art. 5º – Código de Privacidade';
      case ReportUserMotivo.discursoOdio:
        return 'Art. 10º, I e II – Código de Conduta';
      case ReportUserMotivo.outro:
        return 'Art. 18º – Termos de Uso';
    }
  }

  String get chave {
    switch (this) {
      case ReportUserMotivo.condutaAbusiva:        return 'conduta_abusiva';
      case ReportUserMotivo.conteudoImproprioAtivo: return 'conteudo_improprio';
      case ReportUserMotivo.assedio:               return 'assedio';
      case ReportUserMotivo.identidadeFalsa:       return 'identidade_falsa';
      case ReportUserMotivo.spamSolicitacoes:      return 'spam';
      case ReportUserMotivo.violacaoPrivacidade:   return 'violacao_privacidade';
      case ReportUserMotivo.discursoOdio:          return 'discurso_odio';
      case ReportUserMotivo.outro:                 return 'outro';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SERVICE
// ══════════════════════════════════════════════════════════════════════════════
class ReportUserService {
  ReportUserService._();
  static final instance = ReportUserService._();

  final _db  = FirebaseDatabase.instance;
  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Verifica se já denunciou este usuário ─────────────────────────────────
  Future<bool> jaReportou(String reportedUserId) async {
    if (_myUid.isEmpty) return false;
    final chave = '${_myUid}_$reportedUserId';
    final snap  = await _db.ref('Reports/users/$chave').get();
    return snap.exists;
  }

  // ── Registra a denúncia ───────────────────────────────────────────────────
  Future<void> reportUser({
    required String             reportedUserId,
    required String             reportedUserName,
    required ReportUserMotivo   motivo,
    required String             descricao,
  }) async {
    if (_myUid.isEmpty) throw Exception('Usuário não autenticado.');

    final chave = '${_myUid}_$reportedUserId';
    final ref   = _db.ref('Reports/users/$chave');

    final jaExiste = (await ref.get()).exists;
    if (jaExiste) throw Exception('Você já denunciou este usuário.');

    await ref.set({
      'reporter_uid':       _myUid,
      'reported_user_id':   reportedUserId,
      'reported_user_name': reportedUserName,
      'motivo':             motivo.chave,
      'motivo_label':       motivo.label,
      'artigo':             motivo.artigo,
      'descricao':          descricao.trim(),
      'status':             'pending',
      'created_at':         ServerValue.timestamp,
    });

    // Incrementa contador de denúncias no perfil do usuário denunciado
    await _db
        .ref('Users/$reportedUserId/report_count')
        .set(ServerValue.increment(1));
  }
}