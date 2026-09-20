import 'package:flutter/material.dart';
import '../models/question.dart';
import '../helpers/db_helper.dart';

class PracticePage extends StatefulWidget {
  final String modeType; // 'all', 'favorite', 'wrong'
  final String title;

  const PracticePage({Key? key, required this.modeType, required this.title}) : super(key: key);

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  List<Question> questions = [];
  int currentIndex = 0;
  bool isReciteMode = false; // 是否为背题模式
  Set<String> selectedOptions = {}; // 当前已选的选项
  bool isSubmitted = false; // 是否已提交当前题目的答案
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  void _loadQuestions() async {
    var res = await DBHelper.getQuestions(type: widget.modeType);
    setState(() {
      questions = res;
      isLoading = false;
    });
  }

  void _onOptionSelected(String optionKey, bool isMultiple) {
    if (isSubmitted && !isReciteMode) return; // 已提交则锁定
    setState(() {
      if (isMultiple) {
        if (selectedOptions.contains(optionKey)) {
          selectedOptions.remove(optionKey);
        } else {
          selectedOptions.add(optionKey);
        }
      } else {
        selectedOptions = {optionKey};
        _submitAnswer(); // 单选直接提交
      }
    });
  }

  void _submitAnswer() {
    if (selectedOptions.isEmpty) return;
    setState(() {
      isSubmitted = true;
    });

    String userAns = (selectedOptions.toList()..sort()).join();
    Question q = questions[currentIndex];
    
    // 如果答错，自动存入错题本
    if (userAns != q.correctAnswer) {
      DBHelper.markWrong(q.id, true);
      q.isWrong = true;
    }
  }

  void _nextQuestion() {
    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;
        selectedOptions.clear();
        isSubmitted = false;
      });
    }
  }

  void _prevQuestion() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
        selectedOptions.clear();
        isSubmitted = false;
      });
    }
  }

  // 弹窗题号跳转板
  void _showJumpGrid() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6, crossAxisSpacing: 8, mainAxisSpacing: 8,
            ),
            itemCount: questions.length,
            itemBuilder: (context, index) {
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: index == currentIndex ? Colors.blue : Colors.grey[200],
                  foregroundColor: index == currentIndex ? Colors.white : Colors.black,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    currentIndex = index;
                    selectedOptions.clear();
                    isSubmitted = false;
                  });
                },
                child: Text('${index + 1}'),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (questions.isEmpty) return Scaffold(appBar: AppBar(title: Text(widget.title)), body: const Center(child: Text("暂无题目数据")));

    Question q = questions[currentIndex];
    bool isMultiple = q.correctAnswer.length > 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} (${currentIndex + 1}/${questions.length})'),
        actions: [
          Row(
            children: [
              const Text("背题模式", style: TextStyle(fontSize: 12)),
              Switch(
                value: isReciteMode,
                onChanged: (val) {
                  setState(() {
                    isReciteMode = val;
                  });
                },
              ),
            ],
          ),
          IconButton(
            icon: Icon(q.isFavorite ? Icons.star : Icons.star_border, color: q.isFavorite ? Colors.amber : null),
            onPressed: () {
              setState(() {
                q.isFavorite = !q.isFavorite;
              });
              DBHelper.toggleFavorite(q.id, q.isFavorite);
            },
          ),
          IconButton(icon: const Icon(Icons.grid_on), onPressed: _showJumpGrid),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 题型标签与题干
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: isMultiple ? Colors.orange[100] : Colors.blue[100], borderRadius: BorderRadius.circular(4)),
              child: Text(isMultiple ? "多选题" : "单选题", style: TextStyle(color: isMultiple ? Colors.orange[900] : Colors.blue[900])),
            ),
            const SizedBox(height: 10),
            Text("${q.id}. ${q.content}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // 选项列表
            Expanded(
              child: ListView(
                children: [
                  _buildOptionTile(q, 'A', q.optionA, isMultiple),
                  _buildOptionTile(q, 'B', q.optionB, isMultiple),
                  _buildOptionTile(q, 'C', q.optionC, isMultiple),
                  _buildOptionTile(q, 'D', q.optionD, isMultiple),

                  if (isMultiple && !isSubmitted && !isReciteMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: ElevatedButton(onPressed: _submitAnswer, child: const Text("确认提交答案")),
                    ),

                  // 背题模式或已提交时显示正确答案
                  if (isSubmitted || isReciteMode)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("正确答案：${q.correctAnswer}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                          if (!isReciteMode)
                            Text(
                              (selectedOptions.toList()..sort()).join() == q.correctAnswer ? "回答正确！" : "回答错误！",
                              style: TextStyle(color: (selectedOptions.toList()..sort()).join() == q.correctAnswer ? Colors.green : Colors.red),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // 底部翻页控制
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(onPressed: currentIndex > 0 ? _prevQuestion : null, child: const Text("上一题")),
                ElevatedButton(onPressed: currentIndex < questions.length - 1 ? _nextQuestion : null, child: const Text("下一题")),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(Question q, String key, String value, bool isMultiple) {
    if (value.isEmpty) return const SizedBox.shrink();
    bool isSelected = selectedOptions.contains(key);
    bool isCorrect = q.correctAnswer.contains(key);

    Color? tileColor;
    if (isSubmitted || isReciteMode) {
      if (isCorrect) {
        tileColor = Colors.green[100];
      } else if (isSelected && !isCorrect) {
        tileColor = Colors.red[100];
      }
    } else if (isSelected) {
      tileColor = Colors.blue[50];
    }

    return Card(
      color: tileColor,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSelected ? Colors.blue : Colors.grey[200],
          child: Text(key, style: TextStyle(color: isSelected ? Colors.white : Colors.black)),
        ),
        title: Text(value),
        onTap: () => _onOptionSelected(key, isMultiple),
      ),
    );
  }
}