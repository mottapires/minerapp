import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/saida.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('minerasys.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Tabela de saídas offline
    await db.execute('''
      CREATE TABLE saidas_offline (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        temp_id TEXT NOT NULL,
        id_usuario INTEGER NOT NULL,
        placa TEXT NOT NULL,
        metros_cubicos REAL NOT NULL,
        valor_recebido REAL NOT NULL,
        motorista TEXT,
        data_saida TEXT NOT NULL,
        horario TEXT NOT NULL,
        sincronizado INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabela de configurações locais
    await db.execute('''
      CREATE TABLE config_local (
        chave TEXT PRIMARY KEY,
        valor TEXT NOT NULL,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  // Inserir saída offline
  Future<int> inserirSaidaOffline(Saida saida) async {
    final db = await instance.database;
    return await db.insert('saidas_offline', saida.toJson());
  }

  // Buscar saídas não sincronizadas
  Future<List<Saida>> buscarSaidasPendentes() async {
    final db = await instance.database;
    final result = await db.query(
      'saidas_offline',
      where: 'sincronizado = ?',
      whereArgs: [0],
    );
    return result.map((json) => Saida.fromJson(json)).toList();
  }

  // Marcar saída como sincronizada
  Future<int> marcarComoSincronizado(String tempId) async {
    final db = await instance.database;
    return await db.update(
      'saidas_offline',
      {'sincronizado': 1},
      where: 'temp_id = ?',
      whereArgs: [tempId],
    );
  }

  // Contar saídas pendentes
  Future<int> contarSaidasPendentes() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM saidas_offline WHERE sincronizado = 0'
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Salvar configuração local
  Future<void> salvarConfigLocal(String chave, String valor) async {
    final db = await instance.database;
    await db.insert(
      'config_local',
      {'chave': chave, 'valor': valor, 'updated_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Buscar configuração local
  Future<String?> buscarConfigLocal(String chave) async {
    final db = await instance.database;
    final result = await db.query(
      'config_local',
      where: 'chave = ?',
      whereArgs: [chave],
    );
    if (result.isNotEmpty) {
      return result.first['valor'] as String;
    }
    return null;
  }

  // Fechar banco
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}