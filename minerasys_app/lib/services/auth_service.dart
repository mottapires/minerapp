import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/usuario.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  static const String _userKey = 'usuario_logado';

  // Login
  Future<Usuario> login(String email, String senha) async {
    try {
      final response = await _apiService.login(email, senha);
      
      if (response['success'] == true) {
        final usuario = Usuario.fromJson(response['data']);
        await _salvarUsuario(usuario);
        return usuario;
      } else {
        throw Exception(response['message'] ?? 'Erro ao fazer login');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Salvar usuário localmente
  Future<void> _salvarUsuario(Usuario usuario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(usuario.toJson()));
  }

  // Buscar usuário logado
  Future<Usuario?> getUsuarioLogado() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    
    if (userData != null) {
      return Usuario.fromJson(jsonDecode(userData));
    }
    return null;
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  // Verificar se está logado
  Future<bool> isLogado() async {
    final usuario = await getUsuarioLogado();
    return usuario != null;
  }
}