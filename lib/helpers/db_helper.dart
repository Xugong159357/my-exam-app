import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import '../models/question.dart';

class DBHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'exam_questions.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE questions (
            id INTEGER PRIMARY KEY,
            content TEXT,
            correct_answer TEXT,
            option_a TEXT,
            option_b TEXT,
            option_c TEXT,
            option_d TEXT,
            is_favorite INTEGER DEFAULT 0,
            is_wrong INTEGER DEFAULT 0
          )
        ''');
        await _importCSVToDB(db);
      },
    );
  }

  // 自动解析 CSV 并批量插入数据库
  static Future<void> _importCSVToDB(Database db) async {
    final rawData = await rootBundle.loadString('assets/tableConvert.com_ymwisj.csv');
    List<List<dynamic>> listData = const CsvToListConverter().convert(rawData);

    Batch batch = db.batch();
    // 跳过表头从第1行开始
    for (int i = 1; i < listData.length; i++) {
      var row = listData[i];
      if (row.length < 7) continue;
      batch.insert('questions', {
        'id': int.tryParse(row[0].toString()) ?? i,
        'content': row[1].toString(),
        'correct_answer': row[2].toString().trim(),
        'option_a': row[3].toString(),
        'option_b': row[4].toString(),
        'option_c': row[5].toString(),
        'option_d': row[6].toString(),
        'is_favorite': 0,
        'is_wrong': 0,
      });
    }
    await batch.commit(noResult: true);
  }

  // 查询各类题目列表
  static Future<List<Question>> getQuestions({String type = 'all', String query = ''}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;

    if (type == 'favorite') {
      maps = await db.query('questions', where: 'is_favorite = 1');
    } else if (type == 'wrong') {
      maps = await db.query('questions', where: 'is_wrong = 1');
    } else if (query.isNotEmpty) {
      maps = await db.query('questions', where: 'content LIKE ?', whereArgs: ['%$query%']);
    } else {
      maps = await db.query('questions', orderBy: 'id ASC');
    }

    return maps.map((e) => Question.fromMap(e)).toList();
  }

  // 更新收藏状态
  static Future<void> toggleFavorite(int id, bool isFav) async {
    final db = await database;
    await db.update('questions', {'is_favorite': isFav ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  // 标记错题
  static Future<void> markWrong(int id, bool isWrong) async {
    final db = await database;
    await db.update('questions', {'is_wrong': isWrong ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }
}