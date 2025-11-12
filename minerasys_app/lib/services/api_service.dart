import 'package:dio/dio.dart';
import '../config/api_config.dart';

class ApiService {
  late Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      sendTimeout: ApiConfig.sendTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Interceptor para logs (debug)
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));
  }

  // Login
  Future<Map<String, dynamic>> login(String email, String senha) async {
    try {
      final response = await _dio.post(
        ApiConfig.loginEndpoint,
        data: {'email': email, 'senha': senha},
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Registrar saída
  Future<Map<String, dynamic>> registrarSaida({
    required int idUsuario,
    required String placa,
    required double metrosCubicos,
    String? motorista,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.saidasEndpoint,
        data: {
          'id_usuario': idUsuario,
          'placa': placa,
          'metros_cubicos': metrosCubicos,
          'motorista': motorista,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Buscar preço m³
  Future<double> buscarPrecoM3() async {
    try {
      final response = await _dio.get(ApiConfig.precoM3Endpoint);
      return response.data['preco_m3'].toDouble();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Sincronização em lote
  Future<Map<String, dynamic>> sincronizarLote(List<Map<String, dynamic>> registros) async {
    try {
      final response = await _dio.post(
        ApiConfig.syncBatchEndpoint,
        data: {'registros': registros},
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Tratamento de erros
  String _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Timeout: Verifique sua conexão com a internet';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      return 'Servidor demorou muito para responder';
    } else if (e.type == DioExceptionType.connectionError) {
      return 'Sem conexão com a internet';
    } else if (e.response != null) {
      final message = e.response?.data['message'];
      return message ?? 'Erro no servidor';
    } else {
      return 'Erro de rede: ${e.message}';
    }
  }
}