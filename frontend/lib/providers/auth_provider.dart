import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;
  final ApiService _api = ApiService();

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  String? get error => _error;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      try {
        final response = await _api.getMe();
        _user = User.fromJson(response.data['user']);
      } catch (_) {
        await prefs.remove('token');
      }
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.login(email, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', response.data['token']);
      _user = User.fromJson(response.data['user']);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String email, String password, String role, String? department) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.register({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        'department': department,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', response.data['token']);
      _user = User.fromJson(response.data['user']);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try { await _api.logout(); } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    _user = null;
    notifyListeners();
  }

  String _extractError(dynamic e) {
    if (e is Exception) {
      try {
        final dynamic dioError = e;
        return dioError.response?.data?['error'] ?? 'An error occurred';
      } catch (_) {}
    }
    return 'An error occurred';
  }
}
