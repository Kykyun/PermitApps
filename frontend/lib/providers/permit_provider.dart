import 'package:flutter/material.dart';
import '../models/permit.dart';
import '../services/api_service.dart';

class PermitProvider extends ChangeNotifier {
  List<Permit> _permits = [];
  bool _isLoading = false;
  String? _error;
  int _totalPages = 1;
  int _currentPage = 1;
  final ApiService _api = ApiService();

  List<Permit> get permits => _permits;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalPages => _totalPages;
  int get currentPage => _currentPage;

  Future<void> loadPermits({String? status, String? type, String? search, int page = 1}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.getPermits(status: status, type: type, search: search, page: page);
      _permits = (response.data['permits'] as List).map((e) => Permit.fromJson(e)).toList();
      _totalPages = response.data['pagination']['pages'];
      _currentPage = page;
    } catch (e) {
      _error = 'Failed to load permits';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getPermitDetail(int id) async {
    try {
      final response = await _api.getPermit(id);
      return response.data;
    } catch (e) {
      return null;
    }
  }

  Future<Permit?> createPermit(Map<String, dynamic> data) async {
    try {
      final response = await _api.createPermit(data);
      final permit = Permit.fromJson(response.data['permit']);
      await loadPermits();
      return permit;
    } catch (e) {
      return null;
    }
  }

  Future<bool> submitPermit(int id) async {
    try {
      await _api.submitPermit(id);
      await loadPermits();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> uploadDocumentBytes(int permitId, List<int> bytes, String filename) async {
    try {
      await _api.uploadDocumentBytes(permitId, bytes, filename);
      return true;
    } catch (e) {
      return false;
    }
  }


  Future<bool> approvePermit(int id, {String? comments}) async {
    try {
      await _api.approvePermit(id, comments: comments);
      await loadPermits();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> rejectPermit(int id, String comments) async {
    try {
      await _api.rejectPermit(id, comments);
      await loadPermits();
      return true;
    } catch (e) {
      return false;
    }
  }
}
