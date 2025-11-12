import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../../models/usuario.dart';
import '../../models/saida.dart';
import '../../config/app_theme.dart';

class RegistrarSaidaScreen extends StatefulWidget {
  const RegistrarSaidaScreen({Key? key}) : super(key: key);

  @override
  State<RegistrarSaidaScreen> createState() => _RegistrarSaidaScreenState();
}

class _RegistrarSaidaScreenState extends State<RegistrarSaidaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _placaController = TextEditingController();
  final _metrosController = TextEditingController();
  final _motoristaController = TextEditingController();
  
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService.instance;
  final SyncService _syncService = SyncService();
  
  Usuario? _usuario;
  double _precoM3 = 30.0;
  double _valorCalculado = 0.0;
  bool _isLoading = false;
  int _saidasPendentes = 0;
  String _dataAtual = '';
  String _horaAtual = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _atualizarDataHora();
    _iniciarTimer();
  }

  @override
  void dispose() {
    _placaController.dispose();
    _metrosController.dispose();
    _motoristaController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _iniciarTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _atualizarDataHora();
      }
    });
  }

  void _atualizarDataHora() {
    final now = DateTime.now();
    setState(() {
      _dataAtual = DateFormat('dd/MM/yyyy').format(now);
      _horaAtual = DateFormat('HH:mm:ss').format(now);
    });
  }

  Future<void> _carregarDados() async {
    _usuario = await _authService.getUsuarioLogado();
    await _buscarPrecoM3();
    await _contarSaidasPendentes();
    _monitorarConectividade();
  }

  Future<void> _buscarPrecoM3() async {
    try {
      final preco = await _apiService.buscarPrecoM3();
      setState(() => _precoM3 = preco);
      await _dbService.salvarConfigLocal('preco_m3', preco.toString());
    } catch (e) {
      // Usar preço local se offline
      final precoLocal = await _dbService.buscarConfigLocal('preco_m3');
      if (precoLocal != null) {
        setState(() => _precoM3 = double.parse(precoLocal));
      }
    }
  }

  Future<void> _contarSaidasPendentes() async {
    final count = await _dbService.contarSaidasPendentes();
    setState(() => _saidasPendentes = count);
  }

  void _monitorarConectividade() {
    _syncService.monitorarConectividade().listen((result) async {
      if (result != ConnectivityResult.none) {
        // Conectou - tentar sincronizar
        await _sincronizarAutomatico();
      }
    });
  }

  Future<void> _sincronizarAutomatico() async {
    if (_saidasPendentes > 0) {
      final resultado = await _syncService.sincronizarSaidas();
      if (resultado['success'] == true) {
        await _contarSaidasPendentes();
        if (mounted) {
          _mostrarSucesso('${resultado['sincronizados']} saídas sincronizadas!');
        }
      }
    }
  }

  void _calcularValor(String metros) {
    if (metros.isEmpty) {
      setState(() => _valorCalculado = 0.0);
      return;
    }
    
    try {
      final metrosDouble = double.parse(metros.replaceAll(',', '.'));
      setState(() => _valorCalculado = metrosDouble * _precoM3);
    } catch (e) {
      setState(() => _valorCalculado = 0.0);
    }
  }

  Future<void> _registrarSaida() async {
    if (!_formKey.currentState!.validate()) return;
    if (_usuario == null) return;

    setState(() => _isLoading = true);

    final now = DateTime.now();
    final placa = _placaController.text.trim().toUpperCase();
    final metros = double.parse(_metrosController.text.replaceAll(',', '.'));
    final motorista = _motoristaController.text.trim();

    try {
      // Tentar registrar online primeiro
      final temInternet = await _syncService.temConexao();
      
      if (temInternet) {
        final response = await _apiService.registrarSaida(
          idUsuario: _usuario!.id,
          placa: placa,
          metrosCubicos: metros,
          motorista: motorista.isEmpty ? null : motorista,
        );

        if (response['success'] == true) {
          _mostrarSucesso('Saída registrada com sucesso!');
          _limparFormulario();
        } else {
          throw Exception(response['message']);
        }
      } else {
        // Salvar offline
        final saida = Saida(
          tempId: 'temp_${now.millisecondsSinceEpoch}',
          idUsuario: _usuario!.id,
          placa: placa,
          metrosCubicos: metros,
          valorRecebido: _valorCalculado,
          motorista: motorista.isEmpty ? null : motorista,
          dataSaida: DateFormat('yyyy-MM-dd').format(now),
          horario: DateFormat('HH:mm:ss').format(now),
          sincronizado: false,
        );

        await _dbService.inserirSaidaOffline(saida);
        await _contarSaidasPendentes();
        
        _mostrarInfo('Sem internet. Saída salva para sincronizar depois.');
        _limparFormulario();
      }
    } catch (e) {
      _mostrarErro('Erro: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _limparFormulario() {
    _formKey.currentState?.reset();
    _placaController.clear();
    _metrosController.clear();
    _motoristaController.clear();
    setState(() => _valorCalculado = 0.0);
  }

  void _mostrarSucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensagem)),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarInfo(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensagem)),
          ],
        ),
        backgroundColor: AppTheme.secondaryColor,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: AppTheme.errorColor,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _confirmarLogout() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja realmente sair do aplicativo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Saída'),
        actions: [
          // Badge de pendentes
          if (_saidasPendentes > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_saidasPendentes pendentes',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          
          // Menu
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Row(
                  children: const [
                    Icon(Icons.sync),
                    SizedBox(width: 12),
                    Text('Sincronizar'),
                  ],
                ),
                onTap: () {
                  Future.delayed(Duration.zero, () async {
                    final resultado = await _syncService.sincronizarSaidas();
                    _mostrarInfo(resultado['message']);
                    await _contarSaidasPendentes();
                  });
                },
              ),
              PopupMenuItem(
                child: Row(
                  children: const [
                    Icon(Icons.exit_to_app, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Sair', style: TextStyle(color: Colors.red)),
                  ],
                ),
                onTap: () => Future.delayed(Duration.zero, _confirmarLogout),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card de Data/Hora
              Card(
                color: AppTheme.primaryColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock, color: Colors.white70, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Data e Hora Automáticas',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.white),
                              const SizedBox(height: 8),
                              Text(
                                _dataAtual,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Icon(Icons.access_time, color: Colors.white),
                              const SizedBox(height: 8),
                              Text(
                                _horaAtual,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Campo Placa
              TextFormField(
                controller: _placaController,
                decoration: const InputDecoration(
                  labelText: 'Placa do Caminhão *',
                  hintText: 'ABC-1234',
                  prefixIcon: Icon(Icons.local_shipping),
                ),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9-]')),
                  LengthLimitingTextInputFormatter(8),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Digite a placa do caminhão';
                  }
                  if (value.length < 7) {
                    return 'Placa inválida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Campo Metros Cúbicos
              TextFormField(
                controller: _metrosController,
                decoration: InputDecoration(
                  labelText: 'Metros Cúbicos (M³) *',
                  hintText: '0,00',
                  prefixIcon: const Icon(Icons.inventory_2),
                  suffixText: 'm³',
                  helperText: 'Preço: R\$ ${_precoM3.toStringAsFixed(2)}/m³',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                onChanged: _calcularValor,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Digite os metros cúbicos';
                  }
                  try {
                    final metros = double.parse(value.replaceAll(',', '.'));
                    if (metros <= 0) {
                      return 'Valor deve ser maior que zero';
                    }
                  } catch (e) {
                    return 'Valor inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Valor Calculado
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.successColor, width: 2),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.calculate, color: AppTheme.successColor),
                        SizedBox(width: 8),
                        Text(
                          'Valor Calculado Automaticamente',
                          style: TextStyle(
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'R\$ ${_valorCalculado.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Campo Motorista (Opcional)
              TextFormField(
                controller: _motoristaController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Motorista (opcional)',
                  hintText: 'Nome do motorista',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 32),
              
              // Botão Confirmar
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _registrarSaida,
                  icon: _isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.check_circle, size: 28),
                  label: _isLoading
                      ? const SpinKitThreeBounce(color: Colors.white, size: 24)
                      : const Text(
                          'CONFIRMAR SAÍDA',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}