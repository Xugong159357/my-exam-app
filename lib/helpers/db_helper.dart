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

  // 强化版 CSV 导入解析逻辑
  static Future<void> _importCSVToDB(Database db) async {
    try {
      // 1. 读取 assets 下的 CSV 文件
      String rawData = await rootBundle.loadString('assets/tableConvert.com_ymwisj.csv');
      
      // 去除可能存在的 UTF-8 BOM 头
      if (rawData.startsWith('\uFEFF')) {
        rawData = rawData.substring(1);
      }

      // 2. 解析 CSV
      List<List<dynamic>> listData = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(rawData);

      if (listData.isEmpty) return;

      Batch batch = db.batch();
      
      // 3. 逐行插入数据库（跳过第 0 行表头）
      for (int i = 1; i < listData.length; i++) {
        var row = listData[i];
        if (row.length < 3) continue; // 忽略无效空行

        String idStr = row[0].toString().trim();
        int? id = int.tryParse(idStr);
        String content = row[1].toString().trim();
        
        // 如果题目内容为空，跳过
        if (content.isEmpty) continue;

        batch.insert('questions', {
          'id': id ?? i,
          'content': content,
          'correct_answer': row.length > 2 ? row[2].toString().trim() : '',
          'option_a': row.length > 3 ? row[3].toString().trim() : '',
          'option_b': row.length > 4 ? row[4].toString().trim() : '',
          'option_c': row.length > 5 ? row[5].toString().trim() : '',
          'option_d': row.length > 6 ? row[6].toString().trim() : '',
          'is_favorite': 0,
          'is_wrong': 0,
        });
      }

      await batch.commit(noResult: true);
    } catch (e) {
      print("CSV 导入失败: $e");
    }
  }

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

  static Future<void> toggleFavorite(int id, bool isFav) async {
    final db = await database;
    await db.update('questions', {'is_favorite': isFav ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> markWrong(int id, bool isWrong) async {
    final db = await database;
    await db.update('questions', {'is_wrong': isWrong ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }
}
