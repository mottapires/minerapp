import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_service.dart';
import 'api_service.dart';
import '../models/saida.dart';

class SyncService {
  final DatabaseService _dbService = DatabaseService.instance;
  final ApiService _apiService = ApiService();
  final Connectivity _connectivity = Connectivity();

  // Verificar conectividade
  Future<bool> temConexao() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // Sincronizar saídas pendentes
  Future<Map<String, dynamic>> sincronizarSaidas() async {
    if (!await temConexao()) {
      return {
        'success': false,
        'message': 'Sem conexão com a internet',
        'pendentes': await _dbService.contarSaidasPendentes(),
      };
    }

    try {
      final saidasPendentes = await _dbService.buscarSaidasPendentes();
      
      if (saidasPendentes.isEmpty) {
        return {
          'success': true,
          'message': 'Nenhuma saída pendente',
          'sincronizados': 0,
        };
      }

      // Preparar dados para envio
      final registros = saidasPendentes.map((saida) => {
        'temp_id': saida.tempId,
        'id_usuario': saida.idUsuario,
        'placa': saida.placa,
        'metros_cubicos': saida.metrosCubicos,
        'motorista': saida.motorista,
      }).toList();

      // Enviar para API
      final response = await _apiService.sincronizarLote(registros);

      if (response['success'] == true) {
        // Marcar como sincronizado
        for (var resultado in response['resultados']) {
          if (resultado['success'] == true && resultado['temp_id'] != null) {
            await _dbService.marcarComoSincronizado(resultado['temp_id']);
          }
        }

        return {
          'success': true,
          'message': 'Sincronização concluída',
          'sincronizados': response['total_sincronizados'],
          'erros': response['total_erros'],
        };
      } else {
        return {
          'success': false,
          'message': response['message'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro na sincronização: $e',
      };
    }
  }

  // Monitorar conectividade e sincronizar automaticamente
  Stream<ConnectivityResult> monitorarConectividade() {
    return _connectivity.onConnectivityChanged;
  }
}