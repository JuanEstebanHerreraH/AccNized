import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/account.dart';
import '../models/label.dart';
import '../models/note.dart';
import '../models/usage.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _db;

  DatabaseHelper._internal();

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'account_manager.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createAllTables(db);
    for (final label in Label.defaults) {
      await db.insert('labels', label.toMap());
    }
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      await db.execute(
          "ALTER TABLE accounts ADD COLUMN icon_name TEXT DEFAULT 'account_circle'");
      await db.execute('ALTER TABLE accounts ADD COLUMN password TEXT');
      await db.execute(
          "ALTER TABLE notes ADD COLUMN color_hex TEXT DEFAULT '#1A1A1A'");
      await db.execute(
          "ALTER TABLE notes ADD COLUMN font_color_hex TEXT DEFAULT '#E0E0E0'");
      await db.execute(
          'ALTER TABLE notes ADD COLUMN font_size REAL DEFAULT 16.0');
      await db.execute(
          'ALTER TABLE notes ADD COLUMN is_private INTEGER DEFAULT 0');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS note_labels (
          note_id INTEGER NOT NULL,
          label_id INTEGER NOT NULL,
          PRIMARY KEY (note_id, label_id),
          FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE,
          FOREIGN KEY (label_id) REFERENCES labels(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS account_notes (
          account_id INTEGER NOT NULL,
          note_id INTEGER NOT NULL,
          PRIMARY KEY (account_id, note_id),
          FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
          FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldV < 3) {
      // Agregar color del título independiente
      try {
        await db.execute(
            "ALTER TABLE notes ADD COLUMN title_color_hex TEXT DEFAULT '#FFFFFF'");
      } catch (_) {
        // columna ya existe (instalación fresca desde v3)
      }
    }
  }

  Future<void> _createAllTables(Database db) async {
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        identifier TEXT NOT NULL,
        type TEXT NOT NULL,
        icon_name TEXT NOT NULL DEFAULT 'account_circle',
        password TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE usages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        description TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE labels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color_hex TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE account_labels (
        account_id INTEGER NOT NULL,
        label_id INTEGER NOT NULL,
        PRIMARY KEY (account_id, label_id),
        FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
        FOREIGN KEY (label_id) REFERENCES labels(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        color_hex TEXT NOT NULL DEFAULT '#1A1A1A',
        title_color_hex TEXT NOT NULL DEFAULT '#FFFFFF',
        font_color_hex TEXT NOT NULL DEFAULT '#E0E0E0',
        font_size REAL NOT NULL DEFAULT 16.0,
        is_private INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE note_labels (
        note_id INTEGER NOT NULL,
        label_id INTEGER NOT NULL,
        PRIMARY KEY (note_id, label_id),
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE,
        FOREIGN KEY (label_id) REFERENCES labels(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE account_notes (
        account_id INTEGER NOT NULL,
        note_id INTEGER NOT NULL,
        PRIMARY KEY (account_id, note_id),
        FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
      )
    ''');
  }

  // ─────────────────────────── ACCOUNTS ───────────────────────────

  Future<int> insertAccount(Account account) async {
    final db = await database;
    return db.insert('accounts', account.toMap()..remove('id'));
  }

  Future<List<Account>> getAllAccounts({List<int>? labelIds}) async {
    final db = await database;
    List<Map<String, dynamic>> rows;
    if (labelIds != null && labelIds.isNotEmpty) {
      final placeholders = labelIds.map((_) => '?').join(', ');
      rows = await db.rawQuery('''
        SELECT DISTINCT a.* FROM accounts a
        INNER JOIN account_labels al ON a.id = al.account_id
        WHERE al.label_id IN ($placeholders)
        ORDER BY a.created_at DESC
      ''', labelIds);
    } else {
      rows = await db.query('accounts', orderBy: 'created_at DESC');
    }
    final accounts = <Account>[];
    for (final row in rows) {
      final account = Account.fromMap(row);
      account.labels = await getLabelsForAccount(account.id!);
      account.usages = await getUsagesForAccount(account.id!);
      accounts.add(account);
    }
    return accounts;
  }

  Future<Account?> getAccount(int id) async {
    final db = await database;
    final rows =
        await db.query('accounts', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final account = Account.fromMap(rows.first);
    account.labels = await getLabelsForAccount(id);
    account.usages = await getUsagesForAccount(id);
    return account;
  }

  Future<int> updateAccount(Account account) async {
    final db = await database;
    return db.update('accounts', account.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [account.id]);
  }

  Future<int> deleteAccount(int id) async {
    final db = await database;
    return db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────── USAGES ───────────────────────────

  Future<int> insertUsage(Usage usage) async {
    final db = await database;
    return db.insert('usages', usage.toMap()..remove('id'));
  }

  Future<List<Usage>> getUsagesForAccount(int accountId) async {
    final db = await database;
    final rows = await db.query('usages',
        where: 'account_id = ?', whereArgs: [accountId]);
    return rows.map(Usage.fromMap).toList();
  }

  Future<int> updateUsage(Usage usage) async {
    final db = await database;
    return db.update('usages', usage.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [usage.id]);
  }

  Future<int> deleteUsage(int id) async {
    final db = await database;
    return db.delete('usages', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────── LABELS ───────────────────────────

  Future<int> insertLabel(Label label) async {
    final db = await database;
    return db.insert('labels', label.toMap()..remove('id'));
  }

  Future<List<Label>> getAllLabels() async {
    final db = await database;
    final rows =
        await db.query('labels', orderBy: 'is_default DESC, name ASC');
    return rows.map(Label.fromMap).toList();
  }

  Future<List<Label>> getLabelsForAccount(int accountId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT l.* FROM labels l
      INNER JOIN account_labels al ON l.id = al.label_id
      WHERE al.account_id = ?
    ''', [accountId]);
    return rows.map(Label.fromMap).toList();
  }

  Future<int> updateLabel(Label label) async {
    final db = await database;
    return db.update('labels', label.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [label.id]);
  }

  Future<int> deleteLabel(int id) async {
    final db = await database;
    return db.delete('labels', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setLabelsForAccount(int accountId, List<int> labelIds) async {
    final db = await database;
    await db.delete('account_labels',
        where: 'account_id = ?', whereArgs: [accountId]);
    for (final lid in labelIds) {
      await db.insert(
          'account_labels', {'account_id': accountId, 'label_id': lid});
    }
  }

  // ─────────────────────────── NOTES ───────────────────────────

  Future<int> insertNote(Note note) async {
    final db = await database;
    return db.insert('notes', note.toMap()..remove('id'));
  }

  /// Solo notas públicas (is_private = 0) SIN vínculos a cuentas.
  /// Las notas vinculadas a cuentas solo se ven dentro de esas cuentas.
  Future<List<Note>> getAllPublicNotes({int? labelId}) async {
    final db = await database;
    List<Map<String, dynamic>> rows;
    if (labelId != null) {
      rows = await db.rawQuery('''
        SELECT n.* FROM notes n
        INNER JOIN note_labels nl ON n.id = nl.note_id
        WHERE nl.label_id = ?
          AND n.is_private = 0
          AND n.id NOT IN (SELECT note_id FROM account_notes)
        ORDER BY n.updated_at DESC
      ''', [labelId]);
    } else {
      rows = await db.rawQuery('''
        SELECT n.* FROM notes n
        WHERE n.is_private = 0
          AND n.id NOT IN (SELECT note_id FROM account_notes)
        ORDER BY n.updated_at DESC
      ''');
    }
    final notes = <Note>[];
    for (final row in rows) {
      final note = Note.fromMap(row);
      note.labels = await getLabelsForNote(note.id!);
      notes.add(note);
    }
    return notes;
  }

  /// Notas vinculadas a una cuenta (todas, incluyendo privadas)
  Future<List<Note>> getLinkedNotes(int accountId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT n.* FROM notes n
      INNER JOIN account_notes an ON n.id = an.note_id
      WHERE an.account_id = ?
      ORDER BY n.updated_at DESC
    ''', [accountId]);
    final notes = <Note>[];
    for (final row in rows) {
      final note = Note.fromMap(row);
      note.labels = await getLabelsForNote(note.id!);
      notes.add(note);
    }
    return notes;
  }

  /// Cuentas vinculadas a una nota
  Future<List<Account>> getLinkedAccounts(int noteId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT a.* FROM accounts a
      INNER JOIN account_notes an ON a.id = an.account_id
      WHERE an.note_id = ?
    ''', [noteId]);
    return rows.map(Account.fromMap).toList();
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    return db.update('notes', note.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [note.id]);
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // ──────────────────── NOTE ↔ LABELS ───────────────────────────

  Future<List<Label>> getLabelsForNote(int noteId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT l.* FROM labels l
      INNER JOIN note_labels nl ON l.id = nl.label_id
      WHERE nl.note_id = ?
    ''', [noteId]);
    return rows.map(Label.fromMap).toList();
  }

  Future<void> setLabelsForNote(int noteId, List<int> labelIds) async {
    final db = await database;
    await db.delete('note_labels',
        where: 'note_id = ?', whereArgs: [noteId]);
    for (final lid in labelIds) {
      await db.insert('note_labels', {'note_id': noteId, 'label_id': lid});
    }
  }

  // ──────────────────── NOTE ↔ ACCOUNTS ─────────────────────────

  Future<void> setLinkedAccounts(int noteId, List<int> accountIds) async {
    final db = await database;
    await db.delete('account_notes',
        where: 'note_id = ?', whereArgs: [noteId]);
    for (final aid in accountIds) {
      await db
          .insert('account_notes', {'account_id': aid, 'note_id': noteId});
    }
  }
}
