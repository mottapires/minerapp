class ApiConfig {
  // URL base da API
  static const String baseUrl = 'https://smgengenharia.com.br/minerasys/api';
  
  // Endpoints
  static const String loginEndpoint = '/auth/login.php';
  static const String saidasEndpoint = '/apontador/saidas.php';
  static const String listarSaidasEndpoint = '/apontador/listar_saidas.php';
  static const String precoM3Endpoint = '/apontador/get_preco_m3.php';
  static const String syncBatchEndpoint = '/sync/batch.php';
  
  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 10);
  
  // Configurações
  static const int maxRetries = 3;
  static const int retryDelay = 2; // segundos
}