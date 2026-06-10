import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Error with a user-presentable Spanish message from the backend envelope.
class ApiException implements Exception {
  ApiException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Thin wrapper over dio bound to the backend base URL.
class ApiClient {
  ApiClient(this.baseUrl)
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(minutes: 5),
          responseType: ResponseType.json,
        ));

  final String baseUrl;
  final Dio _dio;

  String imageUrl(String hash) => '$baseUrl/images/$hash';

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _request(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) =>
      _request(() => _dio.post<dynamic>(path, data: body));

  Future<dynamic> put(String path, {Object? body}) =>
      _request(() => _dio.put<dynamic>(path, data: body));

  Future<dynamic> delete(String path) => _request(() => _dio.delete<dynamic>(path));

  Future<Map<String, dynamic>> uploadImage(Uint8List bytes, String filename) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final result = await _request(() => _dio.post<dynamic>('/images', data: form));
    return (result as Map).cast<String, dynamic>();
  }

  Future<dynamic> _request(Future<Response<dynamic>> Function() send) async {
    try {
      final response = await send();
      return response.data;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] is Map) {
        final error = (data['error'] as Map).cast<String, dynamic>();
        throw ApiException(
          error['code'] as String? ?? 'unknown',
          error['message'] as String? ?? 'Se ha producido un error inesperado.',
        );
      }
      throw ApiException('connection', 'No se ha podido conectar con el servicio de datos.');
    }
  }
}
