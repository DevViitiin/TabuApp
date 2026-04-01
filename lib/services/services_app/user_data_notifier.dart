// lib/services/services_app/user_data_notifier.dart
//
// Notifier global que mantém os dados do usuário logado atualizados.
// Qualquer tela que mude nome/avatar/bio chama UserDataNotifier.instance.update()
// e todas as telas que ouvem são reconstruídas automaticamente.

import 'package:flutter/foundation.dart';

class UserDataNotifier extends ValueNotifier<Map<String, dynamic>> {
  UserDataNotifier._() : super({});

  static final UserDataNotifier instance = UserDataNotifier._();

  /// Inicializa com os dados vindos do login/registro.
  void init(Map<String, dynamic> data) {
    value = Map<String, dynamic>.from(data);
  }

  /// Atualiza campos específicos e notifica ouvintes.
  void update(Map<String, dynamic> changes) {
    value = {...value, ...changes};
    notifyListeners();
  }

  // Atalhos para os campos mais usados
  String get uid        => value['uid']    as String? ?? value['id'] as String? ?? '';
  String get name       => value['name']   as String? ?? '';
  String get nameUpper  => name.toUpperCase();
  String get avatar     => value['avatar'] as String? ?? '';
  String get email      => value['email']  as String? ?? '';
  String get bio        => ((value['bio']  as String?) ?? (value['bio '] as String?) ?? '').trim();
  String get city       => value['city']   as String? ?? '';
  String get state      => value['state']  as String? ?? '';
}