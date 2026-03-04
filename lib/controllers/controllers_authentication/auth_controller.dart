import 'package:flutter/material.dart';
import 'package:tabuapp/services/services_app/auth_service.dart';


enum AuthStatus { idle, loading, success, error }

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.idle;
  String? _errorMessage;

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AuthStatus.loading;

  Future<bool> login(String email, String password) async {
    _setStatus(AuthStatus.loading);

    try {
      await _authService.signInWithEmail(email: email, password: password);
      _setStatus(AuthStatus.success);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setStatus(AuthStatus.error);
      return false;
    }
  }

  Future<bool> register(String email, String password, String name) async {
    _setStatus(AuthStatus.loading);

    try {
      await _authService.registerWithEmail(
        email: email,
        password: password,
        displayName: name,
      );
      _setStatus(AuthStatus.success);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setStatus(AuthStatus.error);
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.signOut();
    _setStatus(AuthStatus.idle);
  }

  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}