import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';


class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'mindpilot_journal.db');
    return await openDatabase(
      path,
      version: 11,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE journal_entries ADD COLUMN title TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE focus_sessions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT,
          duration_minutes INTEGER
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE tasks(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          description TEXT,
          date TEXT,
          isDone INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE notifications(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          body TEXT,
          date TEXT,
          type TEXT,
          isRead INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE tasks ADD COLUMN completionTime TEXT');
    }
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN startTime TEXT');
      } catch (e) {
        debugPrint('Migration Error: $e');
      }
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN durationMinutes INTEGER');
      } catch (e) {
        debugPrint('Migration Error: $e');
      }
    }
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN remoteId TEXT');
        await db.execute('ALTER TABLE notifications ADD COLUMN remoteId TEXT');
        await db.execute('ALTER TABLE journal_entries ADD COLUMN remoteId TEXT');
      } catch (e) {
        debugPrint('Migration Error: $e');
      }
    }
    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE notifications ADD COLUMN author TEXT');
      } catch (e) {
        debugPrint('Migration Error: $e');
      }
    }
    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE notifications ADD COLUMN source TEXT');
      } catch (e) {
        debugPrint('Migration Error: $e');
      }
    }
    if (oldVersion < 11) {
      try {
        await db.execute('ALTER TABLE notifications ADD COLUMN source TEXT');
      } catch (e) {
        debugPrint('Migration Error: $e');
      }
    }
  }


  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE journal_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        time TEXT,
        text TEXT,
        mood TEXT,
        title TEXT,
        remoteId TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE focus_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        duration_minutes INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE tasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        description TEXT,
        date TEXT,
        isDone INTEGER DEFAULT 0,
        completionTime TEXT,
        startTime TEXT,
        durationMinutes INTEGER,
        remoteId TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE notifications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        body TEXT,
        date TEXT,
        type TEXT,
        isRead INTEGER DEFAULT 0,
        remoteId TEXT,
        author TEXT,
        source TEXT
      )
    ''');
  }

  Future<int> insertEntry(Map<String, dynamic> entry) async {
    Database db = await database;
    return await db.insert('journal_entries', entry);
  }

  Future<List<Map<String, dynamic>>> getEntries() async {
    Database db = await database;
    return await db.query('journal_entries', orderBy: 'id DESC');
  }

  Future<int> getJournalCountSince(String dateIso) async {
    Database db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM journal_entries WHERE date >= ?',
      [dateIso]
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> deleteEntry(int id) async {
    Database db = await database;
    return await db.delete('journal_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateJournalRemoteId(int id, String remoteId) async {
    Database db = await database;
    return await db.update('journal_entries', {'remoteId': remoteId}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertFocusSession(int minutes) async {
    Database db = await database;
    final date = DateTime.now().toIso8601String();
    return await db.insert('focus_sessions', {
      'date': date,
      'duration_minutes': minutes,
    });
  }

  Future<int> getTotalFocusMinutes() async {
    Database db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT SUM(duration_minutes) as total FROM focus_sessions'
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> getFocusMinutesSince(String dateIso) async {
    Database db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(duration_minutes) as total FROM focus_sessions WHERE date >= ?',
      [dateIso]
    );
    return (result.first['total'] as int?) ?? 0;
  }
  
  Future<int> insertTask(Map<String, dynamic> task) async {
    Database db = await database;
    return await db.insert('tasks', task);
  }

  Future<List<Map<String, dynamic>>> getTasks() async {
    Database db = await database;
    return await db.query('tasks', orderBy: 'id DESC');
  }

  Future<int> updateTask(int id, Map<String, dynamic> task) async {
    Database db = await database;
    return await db.update('tasks', task, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTask(int id) async {
    Database db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getTotalTasksCount() async {
    Database db = await database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM tasks WHERE date = ?',
      [today]
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getCompletedTasksCount() async {
    Database db = await database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM tasks WHERE isDone = 1 AND date = ?',
      [today]
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getTasksCompletedSince(String dateIso) async {
    Database db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM tasks WHERE isDone = 1 AND date >= ?',
      [dateIso]
    );
    return (result.first['count'] as int?) ?? 0;
  }
  
  Future<int> insertNotification(Map<String, dynamic> notification) async {
    Database db = await database;
    return await db.insert('notifications', notification);
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    Database db = await database;
    return await db.query('notifications', orderBy: 'id DESC');
  }

  Future<int> markNotificationAsRead(int id) async {
    Database db = await database;
    return await db.update('notifications', {'isRead': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getUnreadNotificationsCount() async {
    Database db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notifications WHERE isRead = 0 AND type = "update"'
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> deleteNotification(int id) async {
    Database db = await database;
    return await db.delete('notifications', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearTasks() async {
    Database db = await database;
    await db.delete('tasks');
  }

  Future<void> clearAll() async {
    Database db = await database;
    await db.delete('journal_entries');
    await db.delete('focus_sessions');
    await db.delete('tasks');
    await db.delete('notifications');
  }
}
