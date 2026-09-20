import 'package:flutter/material.dart';
import '../models/question.dart';
import '../helpers/db_helper.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<Question> searchResults = [];

  void _doSearch(String query) async {
    if (query.trim().isEmpty) return;
    var res = await DBHelper.getQuestions(query: query);
    setState(() {
      searchResults = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: const InputDecoration(hintText: "输入关键字搜索题目...", border: InputBorder.none),
          onChanged: _doSearch,
        ),
      ),
      body: ListView.builder(
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          Question q = searchResults[index];
          return ListTile(
            title: Text("${q.id}. ${q.content}"),
            subtitle: Text("正确答案: ${q.correctAnswer}"),
            onTap: () {
              // 可点击查看详情
            },
          );
        },
      ),
    );
  }
}