import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../engine/signal_engine.dart';

class DatabaseService {
  static Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'mrkoko_signals.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE signals (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            direction  TEXT NOT NULL,
            confidence INTEGER NOT NULL,
            rule       TEXT NOT NULL,
            timeframe  TEXT NOT NULL,
            timestamp  TEXT NOT NULL,
            confirmations TEXT
          )
        ''');
      },
    );
  }

  Future<void> saveSignal(SignalResult s) async {
    await init();
    await _db!.insert('signals', s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getSignals({int limit = 100}) async {
    await init();
    return await _db!.query('signals',
        orderBy: 'id DESC', limit: limit);
  }

  Future<int> getSignalCount() async {
    await init();
    final result = await _db!.rawQuery('SELECT COUNT(*) as c FROM signals');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearAll() async {
    await init();
    await _db!.delete('signals');
  }
}
