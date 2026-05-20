import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/message.dart';
import '../models/conversation.dart';
import '../models/segment_summary.dart';
import '../models/affection_log.dart';
import '../models/emotion_state.dart';
import '../models/ai_persona.dart';

class DatabaseService {
  static Database? _db;
  static Future<Database>? _dbFuture;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    if (_dbFuture != null) return _dbFuture!;
    _dbFuture = _init();
    try {
      _db = await _dbFuture;
      return _db!;
    } finally {
      _dbFuture = null;
    }
  }

  static Future<Database> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'chat_app.db');
    try {
      return await openDatabase(
        path,
        version: 17,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      print('Database init error: $e. Trying recovery without data loss...');
      // Try opening with current version to see if it works at all
      try {
        return await openDatabase(path, version: 17);
      } catch (_) {}
      // Last resort: wipe and recreate
      try { await deleteDatabase(path); } catch (_) {}
      try { await File(path).delete(); } catch (_) {}
      return await openDatabase(path, version: 17, onCreate: _onCreate);
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        system_prompt TEXT,
        user_persona TEXT,
        world_background TEXT,
        avatar_path TEXT,
        affection INTEGER NOT NULL DEFAULT 30,
        mode TEXT NOT NULL DEFAULT 'summary'
      )
    ''');
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        segment_index INTEGER,
        is_bookmarked INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE segment_summaries (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        segment_index INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE affection_logs (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        persona_id TEXT,
        delta REAL NOT NULL,
        reason TEXT NOT NULL,
        user_message TEXT NOT NULL DEFAULT '',
        ai_message TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE emotion_states (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL UNIQUE,
        affection REAL NOT NULL DEFAULT 30.0,
        current_libido_other REAL NOT NULL DEFAULT 25.0,
        base_libido_other REAL NOT NULL DEFAULT 25.0,
        current_aggression_other REAL NOT NULL DEFAULT 25.0,
        base_aggression_other REAL NOT NULL DEFAULT 25.0,
        current_libido_self REAL NOT NULL DEFAULT 25.0,
        base_libido_self REAL NOT NULL DEFAULT 25.0,
        current_aggression_self REAL NOT NULL DEFAULT 25.0,
        base_aggression_self REAL NOT NULL DEFAULT 25.0,
        turn_count INTEGER NOT NULL DEFAULT 0,
        last_interaction TEXT NOT NULL,
        last_update TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE persona_emotion_states (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        persona_id TEXT NOT NULL,
        affection REAL NOT NULL DEFAULT 30.0,
        current_libido_other REAL NOT NULL DEFAULT 25.0,
        base_libido_other REAL NOT NULL DEFAULT 25.0,
        current_aggression_other REAL NOT NULL DEFAULT 25.0,
        base_aggression_other REAL NOT NULL DEFAULT 25.0,
        current_libido_self REAL NOT NULL DEFAULT 25.0,
        base_libido_self REAL NOT NULL DEFAULT 25.0,
        current_aggression_self REAL NOT NULL DEFAULT 25.0,
        base_aggression_self REAL NOT NULL DEFAULT 25.0,
        turn_count INTEGER NOT NULL DEFAULT 0,
        last_interaction TEXT NOT NULL,
        last_update TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE emotion_logs (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        persona_id TEXT,
        affection_delta REAL,
        libido_other_delta REAL,
        aggression_other_delta REAL,
        libido_self_delta REAL,
        aggression_self_delta REAL,
        reason TEXT,
        intensity REAL NOT NULL DEFAULT 1.0,
        user_message TEXT NOT NULL DEFAULT '',
        ai_message TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    // Knowledge base FTS5 + metadata
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS kb_chunks USING fts5(
          title,
          content,
          tokenize='unicode61'
        )
      ''');
    } catch (_) {}
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kb_import_log (
        file_path TEXT PRIMARY KEY,
        file_name TEXT NOT NULL,
        imported_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_personas (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        name TEXT NOT NULL,
        personality TEXT NOT NULL DEFAULT '',
        habits TEXT NOT NULL DEFAULT '',
        appearance TEXT NOT NULL DEFAULT '',
        background TEXT NOT NULL DEFAULT '',
        opening_line TEXT NOT NULL DEFAULT '',
        affection REAL NOT NULL DEFAULT 30.0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db
          .execute('ALTER TABLE conversations ADD COLUMN system_prompt TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      try {
        await db
            .execute('ALTER TABLE messages ADD COLUMN segment_index INTEGER');
      } catch (_) {
        // Column may already exist from a partial previous migration.
      }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS segment_summaries (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          content TEXT NOT NULL DEFAULT '',
          segment_index INTEGER NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      try {
        await db.execute(
            'ALTER TABLE conversations ADD COLUMN affection INTEGER NOT NULL DEFAULT 30');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE conversations ADD COLUMN judge_counter INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE conversations ADD COLUMN judge_trigger INTEGER');
      } catch (_) {}
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS affection_logs (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          delta REAL NOT NULL,
          reason TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 7) {
      try {
        await db.execute(
            "ALTER TABLE affection_logs ADD COLUMN user_message TEXT NOT NULL DEFAULT ''");
      } catch (_) {}
      try {
        await db.execute(
            "ALTER TABLE affection_logs ADD COLUMN ai_message TEXT NOT NULL DEFAULT ''");
      } catch (_) {}
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS emotion_states (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL UNIQUE,
          affection REAL NOT NULL DEFAULT 30.0,
          current_libido_other REAL NOT NULL DEFAULT 25.0,
          base_libido_other REAL NOT NULL DEFAULT 25.0,
          current_aggression_other REAL NOT NULL DEFAULT 25.0,
          base_aggression_other REAL NOT NULL DEFAULT 25.0,
          current_libido_self REAL NOT NULL DEFAULT 25.0,
          base_libido_self REAL NOT NULL DEFAULT 25.0,
          current_aggression_self REAL NOT NULL DEFAULT 25.0,
          base_aggression_self REAL NOT NULL DEFAULT 25.0,
          turn_count INTEGER NOT NULL DEFAULT 0,
          last_interaction TEXT NOT NULL,
          last_update TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS emotion_logs (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          affection_delta REAL,
          libido_other_delta REAL,
          aggression_other_delta REAL,
          libido_self_delta REAL,
          aggression_self_delta REAL,
          reason TEXT,
          intensity REAL NOT NULL DEFAULT 1.0,
          user_message TEXT NOT NULL DEFAULT '',
          ai_message TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 9) {
      try {
        await db.execute(
            "ALTER TABLE messages ADD COLUMN is_bookmarked INTEGER NOT NULL DEFAULT 0");
      } catch (_) {}
      try {
        await db.execute(
            "ALTER TABLE conversations ADD COLUMN mode TEXT NOT NULL DEFAULT 'summary'");
      } catch (_) {}
    }
    if (oldVersion < 10) {
      try {
        await db
            .execute("ALTER TABLE conversations ADD COLUMN user_persona TEXT");
      } catch (_) {}
    }
    if (oldVersion < 11) {
      try {
        await db.execute(
            "ALTER TABLE conversations ADD COLUMN world_background TEXT");
      } catch (_) {}
    }
    if (oldVersion < 12) {
      try {
        await db.execute(
            "ALTER TABLE conversations ADD COLUMN avatar_path TEXT");
      } catch (_) {}
    }
    if (oldVersion < 13) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ai_personas (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          personality TEXT NOT NULL DEFAULT '',
          habits TEXT NOT NULL DEFAULT '',
          appearance TEXT NOT NULL DEFAULT '',
          background TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 14) {
      // Drop old global ai_personas (pre-isolation) and recreate with conversation_id
      await db.execute('DROP TABLE IF EXISTS ai_personas');
      await db.execute('''
        CREATE TABLE ai_personas (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          name TEXT NOT NULL,
          personality TEXT NOT NULL DEFAULT '',
          habits TEXT NOT NULL DEFAULT '',
          appearance TEXT NOT NULL DEFAULT '',
          background TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 15) {
      try {
        await db.execute(
            "ALTER TABLE ai_personas ADD COLUMN opening_line TEXT NOT NULL DEFAULT ''");
      } catch (_) {}
    }
    if (oldVersion < 16) {
      try {
        await db.execute(
            "ALTER TABLE ai_personas ADD COLUMN affection REAL NOT NULL DEFAULT 30.0");
      } catch (_) {}
      try {
        await db.execute(
            "ALTER TABLE emotion_states ADD COLUMN persona_id TEXT");
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS persona_emotion_states (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          persona_id TEXT NOT NULL,
          affection REAL NOT NULL DEFAULT 30.0,
          current_libido_other REAL NOT NULL DEFAULT 25.0,
          base_libido_other REAL NOT NULL DEFAULT 25.0,
          current_aggression_other REAL NOT NULL DEFAULT 25.0,
          base_aggression_other REAL NOT NULL DEFAULT 25.0,
          current_libido_self REAL NOT NULL DEFAULT 25.0,
          base_libido_self REAL NOT NULL DEFAULT 25.0,
          current_aggression_self REAL NOT NULL DEFAULT 25.0,
          base_aggression_self REAL NOT NULL DEFAULT 25.0,
          turn_count INTEGER NOT NULL DEFAULT 0,
          last_interaction TEXT NOT NULL,
          last_update TEXT NOT NULL
        )
      ''');
      try {
        await db.execute(
            "ALTER TABLE affection_logs ADD COLUMN persona_id TEXT");
      } catch (_) {}
      try {
        await db.execute(
            "ALTER TABLE emotion_logs ADD COLUMN persona_id TEXT");
      } catch (_) {}
    }
    if (oldVersion < 17) {
      try {
        await db.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS kb_chunks USING fts5(
            title,
            content,
            tokenize='unicode61'
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS kb_import_log (
            file_path TEXT PRIMARY KEY,
            file_name TEXT NOT NULL,
            imported_at TEXT NOT NULL
          )
        ''');
      } catch (e) {
        print('KB FTS5 init failed (may not be supported on this device): $e');
      }
    }
  }

  /// ─── Conversation CRUD ────────

  static Future<List<Conversation>> getConversations() async {
    final db = await database;
    final rows = await db.query('conversations', orderBy: 'updated_at DESC');
    return rows.map((r) => Conversation.fromMap(r)).toList();
  }

  static Future<Conversation> getConversation(String id) async {
    final db = await database;
    final rows =
        await db.query('conversations', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw Exception('Conversation not found');
    return Conversation.fromMap(rows.first);
  }

  static Future<void> insertConversation(Conversation conv) async {
    final db = await database;
    await db.insert('conversations', conv.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateConversation(Conversation conv) async {
    final db = await database;
    await db.update('conversations', conv.toMap(),
        where: 'id = ?', whereArgs: [conv.id]);
  }

  static Future<void> deleteConversation(String id) async {
    final db = await database;
    await db.delete('conversations', where: 'id = ?', whereArgs: [id]);
    await db.delete('messages', where: 'conversation_id = ?', whereArgs: [id]);
    await db.delete('segment_summaries',
        where: 'conversation_id = ?', whereArgs: [id]);
    await db.delete('affection_logs',
        where: 'conversation_id = ?', whereArgs: [id]);
    await db.delete('emotion_states',
        where: 'conversation_id = ?', whereArgs: [id]);
    await db
        .delete('emotion_logs', where: 'conversation_id = ?', whereArgs: [id]);
  }

  /// ─── Settings ────────

  static Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  /// ─── Message CRUD ────────

  static Future<List<Message>> getMessages(String conversationId) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC',
    );
    return rows.map((r) => Message.fromMap(r)).toList();
  }

  static Future<void> insertMessage(Message msg) async {
    final db = await database;
    await db.insert('messages', msg.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteMessages(String conversationId) async {
    final db = await database;
    await db.delete('messages',
        where: 'conversation_id = ?', whereArgs: [conversationId]);
  }

  static Future<void> updateMessage(Message msg) async {
    final db = await database;
    await db
        .update('messages', msg.toMap(), where: 'id = ?', whereArgs: [msg.id]);
  }

  static Future<void> deleteMessage(String id) async {
    final db = await database;
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateMessageBookmark(String id, bool bookmarked) async {
    final db = await database;
    await db.update('messages', {'is_bookmarked': bookmarked ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Message>> getBookmarkedMessages(
      String conversationId) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      where: 'conversation_id = ? AND is_bookmarked = 1',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC',
    );
    return rows.map((r) => Message.fromMap(r)).toList();
  }

  static Future<void> updateMessageArchiveStatus(
      List<String> messageIds, int segmentIndex) async {
    final db = await database;
    final batch = db.batch();
    for (final id in messageIds) {
      batch.update('messages', {'segment_index': segmentIndex},
          where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  /// ─── Segment Summary CRUD ────────

  static Future<List<SegmentSummary>> getSegmentSummaries(
      String conversationId) async {
    final db = await database;
    final rows = await db.query(
      'segment_summaries',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'segment_index ASC',
    );
    return rows.map((r) => SegmentSummary.fromMap(r)).toList();
  }

  static Future<void> insertSegmentSummary(SegmentSummary summary) async {
    final db = await database;
    await db.insert('segment_summaries', summary.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateSegmentSummary(SegmentSummary summary) async {
    final db = await database;
    await db.update('segment_summaries', summary.toMap(),
        where: 'id = ?', whereArgs: [summary.id]);
  }

  static Future<void> deleteSegmentSummaries(String conversationId) async {
    final db = await database;
    await db.delete('segment_summaries',
        where: 'conversation_id = ?', whereArgs: [conversationId]);
  }

  /// ─── Affection Log CRUD ────────

  static Future<void> insertAffectionLog(AffectionLog log) async {
    final db = await database;
    await db.insert('affection_logs', log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<AffectionLog>> getAffectionLogs(
      String conversationId, {String? personaId}) async {
    final db = await database;
    List<Map<String, dynamic>> rows;
    if (personaId != null) {
      rows = await db.query(
        'affection_logs',
        where: 'conversation_id = ? AND persona_id = ?',
        whereArgs: [conversationId, personaId],
        orderBy: 'created_at DESC',
      );
    } else {
      rows = await db.query(
        'affection_logs',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'created_at DESC',
      );
    }
    return rows.map((r) => AffectionLog.fromMap(r)).toList();
  }

  /// ─── Emotion State CRUD ────────

  static Future<EmotionState?> getEmotionState(String conversationId) async {
    final db = await database;
    final rows = await db.query(
      'emotion_states',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
    if (rows.isEmpty) return null;
    return EmotionState.fromMap(rows.first);
  }

  static Future<void> insertEmotionState(EmotionState state) async {
    final db = await database;
    await db.insert('emotion_states', state.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateEmotionState(EmotionState state) async {
    final db = await database;
    if (state.personaId != null) {
      await db.update('emotion_states', state.toMap(),
          where: 'conversation_id = ? AND persona_id = ?',
          whereArgs: [state.conversationId, state.personaId]);
    } else {
      await db.update('emotion_states', state.toMap(),
          where: 'conversation_id = ? AND persona_id IS NULL',
          whereArgs: [state.conversationId]);
    }
  }

  /// ─── Persona Emotion State CRUD ────────

  static Future<EmotionState?> getPersonaEmotionState(String conversationId, String personaId) async {
    final db = await database;
    final rows = await db.query(
      'persona_emotion_states',
      where: 'conversation_id = ? AND persona_id = ?',
      whereArgs: [conversationId, personaId],
    );
    if (rows.isEmpty) return null;
    return EmotionState.fromMap(rows.first);
  }

  static Future<void> insertPersonaEmotionState(EmotionState state) async {
    final db = await database;
    await db.insert('persona_emotion_states', state.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updatePersonaEmotionState(EmotionState state) async {
    final db = await database;
    await db.update('persona_emotion_states', state.toMap(),
        where: 'id = ?', whereArgs: [state.id]);
  }

  static Future<void> deletePersonaEmotionState(String conversationId, String personaId) async {
    final db = await database;
    await db.delete('persona_emotion_states',
        where: 'conversation_id = ? AND persona_id = ?',
        whereArgs: [conversationId, personaId]);
  }

  static Future<void> deleteEmotionState(String conversationId, {String? personaId}) async {
    final db = await database;
    if (personaId != null) {
      await db.delete('emotion_states',
          where: 'conversation_id = ? AND persona_id = ?',
          whereArgs: [conversationId, personaId]);
    } else {
      await db.delete('emotion_states',
          where: 'conversation_id = ? AND persona_id IS NULL',
          whereArgs: [conversationId]);
    }
  }

  /// ─── Emotion Log CRUD ────────

  static Future<void> insertEmotionLog(EmotionLog log) async {
    final db = await database;
    await db.insert('emotion_logs', log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<EmotionLog>> getEmotionLogs(String conversationId, {String? personaId}) async {
    final db = await database;
    List<Map<String, dynamic>> rows;
    if (personaId != null) {
      rows = await db.query(
        'emotion_logs',
        where: 'conversation_id = ? AND persona_id = ?',
        whereArgs: [conversationId, personaId],
        orderBy: 'created_at DESC',
      );
    } else {
      rows = await db.query(
        'emotion_logs',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'created_at DESC',
      );
    }
    return rows.map((r) => EmotionLog.fromMap(r)).toList();
  }

  /// ─── AI Persona CRUD ────────

  static Future<List<AIPersona>> getAIPersonas(String conversationId) async {
    final db = await database;
    final rows = await db.query(
      'ai_personas',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => AIPersona.fromMap(r)).toList();
  }

  static Future<void> insertAIPersona(AIPersona persona) async {
    final db = await database;
    await db.insert('ai_personas', persona.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateAIPersona(AIPersona persona) async {
    final db = await database;
    await db.update('ai_personas', persona.toMap(),
        where: 'id = ?', whereArgs: [persona.id]);
  }

  static Future<void> deleteAIPersona(String id) async {
    final db = await database;
    await db.delete('ai_personas', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteAIPersonasByConversation(String conversationId) async {
    final db = await database;
    await db.delete('ai_personas',
        where: 'conversation_id = ?', whereArgs: [conversationId]);
  }

  /// ─── Knowledge Base (FTS5) ────────

  static Future<void> insertKbChunk(String title, String content) async {
    try {
      final db = await database;
      await db.insert('kb_chunks', {'title': title, 'content': content});
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> searchKb(String query, {int limit = 5}) async {
    try {
      final db = await database;
      final safe = query
          .replaceAll(RegExp(r'["''*()]'), '')
          .replaceAll(RegExp(r'\s+'), ' ');
      if (safe.trim().isEmpty) return [];
      final rows = await db.rawQuery(
        "SELECT title, content, rank FROM kb_chunks WHERE kb_chunks MATCH ? ORDER BY rank LIMIT ?",
        [safe, limit],
      );
      return rows;
    } catch (_) {
      return [];
    }
  }

  static Future<int> kbChunkCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT count(*) as cnt FROM kb_chunks');
      return result.first['cnt'] as int;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> clearKb() async {
    final db = await database;
    await db.delete('kb_chunks');
    await db.delete('kb_import_log');
  }

  /// ─── KB Import Log ────────

  static Future<Set<String>> getImportedFiles() async {
    final db = await database;
    final rows = await db.query('kb_import_log');
    return rows.map((r) => r['file_path'] as String).toSet();
  }

  static Future<void> markFileImported(String filePath, String fileName) async {
    final db = await database;
    await db.insert('kb_import_log', {
      'file_path': filePath,
      'file_name': fileName,
      'imported_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
