import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:5001/api';
  late Dio _dio;

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;

  // Auth
  Future<Response> login(String email, String password) =>
      _dio.post('/auth/login', data: {'email': email, 'password': password});

  Future<Response> register(Map<String, dynamic> data) =>
      _dio.post('/auth/register', data: data);

  Future<Response> getMe() => _dio.get('/auth/me');

  Future<Response> logout() => _dio.post('/auth/logout');

  // Permits
  Future<Response> getPermits({String? status, String? type, String? search, int page = 1}) {
    final params = <String, dynamic>{'page': page, 'limit': 20};
    if (status != null) params['status'] = status;
    if (type != null) params['type'] = type;
    if (search != null) params['search'] = search;
    return _dio.get('/permits', queryParameters: params);
  }

  Future<Response> getPermit(int id) => _dio.get('/permits/$id');

  Future<Response> createPermit(Map<String, dynamic> data) =>
      _dio.post('/permits', data: data);

  Future<Response> updatePermit(int id, Map<String, dynamic> data) =>
      _dio.put('/permits/$id', data: data);

  Future<Response> submitPermit(int id) => _dio.post('/permits/$id/submit');

  Future<Response> approvePermit(int id, {String? comments}) =>
      _dio.post('/permits/$id/approve', data: {'comments': comments ?? 'Approved'});

  Future<Response> rejectPermit(int id, String comments) =>
      _dio.post('/permits/$id/reject', data: {'comments': comments});

  Future<Response> uploadDocuments(int permitId, List<String> filePaths) async {
    final formData = FormData();
    for (final path in filePaths) {
      formData.files.add(MapEntry('documents', await MultipartFile.fromFile(path)));
    }
    return _dio.post('/permits/$permitId/documents', data: formData);
  }

  Future<Response> uploadDocumentBytes(int permitId, List<int> bytes, String filename) async {
    final formData = FormData.fromMap({
      'documents': MultipartFile.fromBytes(bytes, filename: filename),
    });
    return _dio.post('/permits/$permitId/documents', data: formData);
  }

  // Notifications
  Future<Response> getNotifications() => _dio.get('/notifications');

  Future<Response> markNotificationRead(int id) =>
      _dio.put('/notifications/$id/read');

  Future<Response> markAllNotificationsRead() =>
      _dio.put('/notifications/read-all');

  // Dashboard
  Future<Response> getDashboardStats() => _dio.get('/dashboard/stats');

  Future<Response> getDashboardTrend() => _dio.get('/dashboard/trend');

  Future<Response> getDashboardRecent() => _dio.get('/dashboard/recent');
}
