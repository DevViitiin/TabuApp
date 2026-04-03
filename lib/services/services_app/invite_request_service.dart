import 'package:firebase_database/firebase_database.dart';

class InviteRequestService {
  final _database = FirebaseDatabase.instance;

  /// Cria uma nova solicitação de convite
  Future<void> createInviteRequest({
    required String name,
    required String email,
    required String phone,
  }) async {
    try {
      // Limpar telefone (remover máscara)
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');

      // Verificar se já existe uma solicitação pendente com este email
      final existingRequest = await _checkExistingRequest(email);
      if (existingRequest != null) {
        throw 'Já existe uma solicitação pendente para este e-mail';
      }

      // Criar nova solicitação
      final requestRef = _database.ref('InviteRequests').push();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await requestRef.set({
        'name': name,
        'email': email.toLowerCase(),
        'phone': cleanPhone,
        'created_at': timestamp,
        'status': 'pending', // pending, approved, rejected
        'request_id': requestRef.key,
      });
    } catch (e) {
      if (e is String) {
        rethrow;
      }
      throw 'Erro ao enviar solicitação. Tente novamente.';
    }
  }

  /// Verifica se já existe uma solicitação pendente para o email
  Future<Map<String, dynamic>?> _checkExistingRequest(String email) async {
    try {
      final snapshot = await _database
          .ref('InviteRequests')
          .orderByChild('email')
          .equalTo(email.toLowerCase())
          .get();

      if (!snapshot.exists) return null;

      final requests = snapshot.value as Map<dynamic, dynamic>;
      
      // Verificar se há alguma solicitação pendente
      for (var entry in requests.entries) {
        final request = entry.value as Map<dynamic, dynamic>;
        if (request['status'] == 'pending') {
          return Map<String, dynamic>.from(request);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Busca todas as solicitações pendentes (admin)
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    try {
      final snapshot = await _database
          .ref('InviteRequests')
          .orderByChild('status')
          .equalTo('pending')
          .get();

      if (!snapshot.exists) return [];

      final requests = snapshot.value as Map<dynamic, dynamic>;
      final List<Map<String, dynamic>> requestList = [];

      requests.forEach((key, value) {
        final request = Map<String, dynamic>.from(value as Map);
        request['key'] = key;
        requestList.add(request);
      });

      // Ordenar por data de criação (mais recente primeiro)
      requestList.sort((a, b) => 
        (b['created_at'] as int).compareTo(a['created_at'] as int));

      return requestList;
    } catch (e) {
      throw 'Erro ao buscar solicitações';
    }
  }

  /// Aprova uma solicitação de convite (admin)
  Future<void> approveRequest(String requestId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await _database.ref('InviteRequests/$requestId').update({
        'status': 'approved',
        'approved_at': timestamp,
      });
    } catch (e) {
      throw 'Erro ao aprovar solicitação';
    }
  }

  /// Rejeita uma solicitação de convite (admin)
  Future<void> rejectRequest(String requestId, {String? reason}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final updates = {
        'status': 'rejected',
        'rejected_at': timestamp,
      };

      if (reason != null && reason.isNotEmpty) {
        updates['rejection_reason'] = reason;
      }

      await _database.ref('InviteRequests/$requestId').update(updates);
    } catch (e) {
      throw 'Erro ao rejeitar solicitação';
    }
  }

  /// Busca uma solicitação específica por ID
  Future<Map<String, dynamic>?> getRequestById(String requestId) async {
    try {
      final snapshot = await _database.ref('InviteRequests/$requestId').get();

      if (!snapshot.exists) return null;

      return Map<String, dynamic>.from(snapshot.value as Map);
    } catch (e) {
      return null;
    }
  }

  /// Busca solicitações de um email específico
  Future<List<Map<String, dynamic>>> getRequestsByEmail(String email) async {
    try {
      final snapshot = await _database
          .ref('InviteRequests')
          .orderByChild('email')
          .equalTo(email.toLowerCase())
          .get();

      if (!snapshot.exists) return [];

      final requests = snapshot.value as Map<dynamic, dynamic>;
      final List<Map<String, dynamic>> requestList = [];

      requests.forEach((key, value) {
        final request = Map<String, dynamic>.from(value as Map);
        request['key'] = key;
        requestList.add(request);
      });

      // Ordenar por data de criação (mais recente primeiro)
      requestList.sort((a, b) => 
        (b['created_at'] as int).compareTo(a['created_at'] as int));

      return requestList;
    } catch (e) {
      throw 'Erro ao buscar solicitações';
    }
  }

  /// Estatísticas de solicitações (admin)
  Future<Map<String, int>> getRequestStats() async {
    try {
      final snapshot = await _database.ref('InviteRequests').get();

      if (!snapshot.exists) {
        return {
          'total': 0,
          'pending': 0,
          'approved': 0,
          'rejected': 0,
        };
      }

      final requests = snapshot.value as Map<dynamic, dynamic>;
      int total = 0;
      int pending = 0;
      int approved = 0;
      int rejected = 0;

      requests.forEach((key, value) {
        final request = value as Map<dynamic, dynamic>;
        total++;
        
        switch (request['status']) {
          case 'pending':
            pending++;
            break;
          case 'approved':
            approved++;
            break;
          case 'rejected':
            rejected++;
            break;
        }
      });

      return {
        'total': total,
        'pending': pending,
        'approved': approved,
        'rejected': rejected,
      };
    } catch (e) {
      throw 'Erro ao buscar estatísticas';
    }
  }

  /// Deleta uma solicitação (admin)
  Future<void> deleteRequest(String requestId) async {
    try {
      await _database.ref('InviteRequests/$requestId').remove();
    } catch (e) {
      throw 'Erro ao deletar solicitação';
    }
  }
}