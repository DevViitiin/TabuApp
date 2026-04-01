// lib/services/services_administrative/reports/report_chat_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  MOTIVOS — específicos para denúncia de conversa
// ══════════════════════════════════════════════════════════════════════════════
enum ReportChatMotivo {
  assedio,
  conteudoSexual,
  ameaca,
  spam,
  dadosPessoais,
  conteudoIlegal,
}

extension ReportChatMotivoExt on ReportChatMotivo {
  String get label {
    switch (this) {
      case ReportChatMotivo.assedio:
        return 'Assédio ou mensagens ofensivas';
      case ReportChatMotivo.conteudoSexual:
        return 'Conteúdo sexual não solicitado';
      case ReportChatMotivo.ameaca:
        return 'Ameaças ou intimidação';
      case ReportChatMotivo.spam:
        return 'Spam ou mensagens repetitivas';
      case ReportChatMotivo.dadosPessoais:
        return 'Solicitação de dados pessoais ou golpe';
      case ReportChatMotivo.conteudoIlegal:
        return 'Conteúdo ilegal ou prejudicial';
    }
  }

  String get descricao {
    switch (this) {
      case ReportChatMotivo.assedio:
        return 'Mensagens com linguagem agressiva, insultos, humilhação ou perseguição.';
      case ReportChatMotivo.conteudoSexual:
        return 'Envio de imagens, vídeos ou textos de cunho sexual sem consentimento.';
      case ReportChatMotivo.ameaca:
        return 'Ameaças de violência física, exposição ou qualquer forma de coerção.';
      case ReportChatMotivo.spam:
        return 'Envio repetitivo e indesejado de mensagens, links ou promoções.';
      case ReportChatMotivo.dadosPessoais:
        return 'Tentativa de obter dados bancários, senhas ou informações pessoais.';
      case ReportChatMotivo.conteudoIlegal:
        return 'Conteúdo que viola leis vigentes, incluindo material de abuso ou crime.';
    }
  }

  String get artigo {
    switch (this) {
      case ReportChatMotivo.assedio:
        return 'Art. 7º, III – Política de Uso Responsável';
      case ReportChatMotivo.conteudoSexual:
        return 'Art. 8º, I – Política de Conteúdo Tabu';
      case ReportChatMotivo.ameaca:
        return 'Art. 7º, IV – Código de Conduta Tabu';
      case ReportChatMotivo.spam:
        return 'Art. 10º, II – Termos de Uso';
      case ReportChatMotivo.dadosPessoais:
        return 'Art. 12º – Proteção de Dados e LGPD';
      case ReportChatMotivo.conteudoIlegal:
        return 'Art. 15º – Marco Civil da Internet / Termos de Uso';
    }
  }

  String get key {
    switch (this) {
      case ReportChatMotivo.assedio:        return 'assedio';
      case ReportChatMotivo.conteudoSexual: return 'conteudo_sexual';
      case ReportChatMotivo.ameaca:         return 'ameaca';
      case ReportChatMotivo.spam:           return 'spam';
      case ReportChatMotivo.dadosPessoais:  return 'dados_pessoais';
      case ReportChatMotivo.conteudoIlegal: return 'conteudo_ilegal';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SERVICE
// ══════════════════════════════════════════════════════════════════════════════
class ReportChatService {
  ReportChatService._();
  static final instance = ReportChatService._();

  final _db   = FirebaseDatabase.instance;
  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Chave do report: reporterUid_chatId ───────────────────────────────────
  String _reportKey(String chatId) => '${_myUid}_$chatId';

  // ── Verifica se já denunciou esta conversa ────────────────────────────────
  Future<bool> jaReportou(String chatId) async {
    if (_myUid.isEmpty) return false;
    final snap = await _db
        .ref('Reports/chats/${_reportKey(chatId)}')
        .get();
    return snap.exists;
  }

  // ── Submete a denúncia ────────────────────────────────────────────────────
  Future<void> reportChat({
    required String chatId,
    required String reportedUid,
    required String reportedName,
    required ReportChatMotivo motivo,
    required String descricao,
  }) async {
    if (_myUid.isEmpty) throw Exception('Usuário não autenticado.');

    final key  = _reportKey(chatId);
    final ref  = _db.ref('Reports/chats/$key');

    // Impede duplicação
    final exists = (await ref.get()).exists;
    if (exists) throw Exception('Você já denunciou esta conversa.');

    final now = DateTime.now().millisecondsSinceEpoch;

    // Grava o report
    await ref.set({
      'reporter_uid':    _myUid,
      'reported_uid':    reportedUid,
      'reported_name':   reportedName,
      'chat_id':         chatId,
      'motivo':          motivo.key,
      'motivo_label':    motivo.label,
      'artigo':          motivo.artigo,
      'descricao':       descricao.trim(),
      'status':          'pending',
      'created_at':      now,
    });

    // Incrementa contador de reports do usuário denunciado
    final reportCountRef =
        _db.ref('Users/$reportedUid/report_count');
    final snap = await reportCountRef.get();
    final current = (snap.value as num?)?.toInt() ?? 0;
    await reportCountRef.set(current + 1);

    // Marca o chat como reportado (referência para moderação)
    await _db.ref('Chats/$chatId/report_count').set(
      ServerValue.increment(1));
  }
}