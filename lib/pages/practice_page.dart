import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/question.dart';
import '../helpers/db_helper.dart';

class PracticePage extends StatefulWidget {
  final String modeType; // 'all', 'favorite', 'wrong'
  final String title;
  final int initialGroupIndex; // 初始选择的组号（从 0 开始）

  const PracticePage({
    Key? key,
    required this.modeType,
    required this.title,
    this.initialGroupIndex = 0,
  }) : super(key: key);

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  List<Question> allQuestions = []; // 当前模式下的所有题目
  List<Question> currentGroupQuestions = []; // 当前 20 题组的题目
  int groupIndex = 0; // 当前第几组
  int indexInGroup = 0; // 当前在组内的索引（0 ~ 19）

  bool isReciteMode = false; // 背题模式
  Set<String> selectedOptions = {};
  bool isSubmitted = false;
  bool isLoading = true;

  // 统计当前组的答题情况
  int groupCorrectCount = 0;
  int groupWrongCount = 0;

  @override
  void initState() {
    super.initState();
    groupIndex = widget.initialGroupIndex;
    _loadQuestions();
  }

  void _loadQuestions() async {
    var res = await DBHelper.getQuestions(type: widget.modeType);
    allQuestions = res;

    if (allQuestions.isNotEmpty) {
      // 如果是顺序练习，且没有指定组号，自动恢复上次保存的答题进度
      if (widget.modeType == 'all' && widget.initialGroupIndex == 0) {
        final prefs = await SharedPreferences.getInstance();
        int savedIndex = prefs.getInt('saved_sequence_index') ?? 0;
        if (savedIndex >= allQuestions.length) savedIndex = 0;

        groupIndex = savedIndex ~/ 20;
        indexInGroup = savedIndex % 20;
      }
      _loadGroupData();
    }

    setState(() {
      isLoading = false;
    });
  }

  // 加载当前组（20题）的数据
  void _loadGroupData() {
    int start = groupIndex * 20;
    int end = start + 20;
    if (start >= allQuestions.length) {
      start = 0;
      groupIndex = 0;
      end = 20;
    }
    if (end > allQuestions.length) end = allQuestions.length;

    currentGroupQuestions = allQuestions.sublist(start, end);
    groupCorrectCount = 0;
    groupWrongCount = 0;
  }

  // 保存当前的答题进度（绝对题号索引）
  Future<void> _saveProgress() async {
    if (widget.modeType == 'all') {
      final prefs = await SharedPreferences.getInstance();
      int absoluteIndex = groupIndex * 20 + indexInGroup;
      await prefs.setInt('saved_sequence_index', absoluteIndex);
    }
  }

  void _onOptionSelected(String optionKey, bool isMultiple) {
    if (isSubmitted && !isReciteMode) return;
    setState(() {
      if (isMultiple) {
        if (selectedOptions.contains(optionKey)) {
          selectedOptions.remove(optionKey);
        } else {
          selectedOptions.add(optionKey);
        }
      } else {
        selectedOptions = {optionKey};
        _submitAnswer();
      }
    });
  }

  void _submitAnswer() {
    if (selectedOptions.isEmpty) return;
    setState(() {
      isSubmitted = true;
    });

    String userAns = (selectedOptions.toList()..sort()).join();
    Question q = currentGroupQuestions[indexInGroup];

    if (userAns == q.correctAnswer) {
      groupCorrectCount++;
    } else {
      groupWrongCount++;
      DBHelper.markWrong(q.id, true);
      q.isWrong = true;
    }
  }

  void _nextQuestion() {
    if (indexInGroup < currentGroupQuestions.length - 1) {
      setState(() {
        indexInGroup++;
        selectedOptions.clear();
        isSubmitted = false;
      });
      _saveProgress();
    } else {
      // 答完本组 20 题，弹出组结算弹窗
      _showGroupResultDialog();
    }
  }

  void _prevQuestion() {
    if (indexInGroup > 0) {
      setState(() {
        indexInGroup--;
        selectedOptions.clear();
        isSubmitted = false;
      });
      _saveProgress();
    }
  }

  // 本组练习完成结算弹窗
  void _showGroupResultDialog() {
    int totalInGroup = currentGroupQuestions.length;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text("第 ${groupIndex + 1} 组练习完成！"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("本组共练习：$totalInGroup 题"),
              const SizedBox(height: 8),
              Text("正确：$groupCorrectCount 题", style: const TextStyle(color: Colors.green)),
              Text("错误：$groupWrongCount 题", style: const TextStyle(color: Colors.red)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 关弹窗
                Navigator.pop(context); // 返回主页
              },
              child: const Text("返回主页"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // 跳转到错题练习
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PracticePage(modeType: 'wrong', title: '错题练习'),
                  ),
                );
              },
              child: const Text("查看错题"),
            ),
            if ((groupIndex + 1) * 20 < allQuestions.length)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    groupIndex++;
                    indexInGroup = 0;
                    selectedOptions.clear();
                    isSubmitted = false;
                    _loadGroupData();
                  });
                  _saveProgress();
                },
                child: const Text("继续下一组"),
              ),
          ],
        );
      },
    );
  }

  // 跳转组与题号面板
  void _showJumpGrid() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("当前第 ${groupIndex + 1} 组 (每组20题)", style: const TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<int>(
                    value: groupIndex,
                    items: List.generate((allQuestions.length / 20).ceil(), (i) {
                      return DropdownMenuItem(
                        value: i,
                        child: Text("第 ${i + 1} 组 (${i * 20 + 1}~${(i + 1) * 20})"),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) {
                        Navigator.pop(context);
                        setState(() {
                          groupIndex = val;
                          indexInGroup = 0;
                          selectedOptions.clear();
                          isSubmitted = false;
                          _loadGroupData();
                        });
                        _saveProgress();
                      }
                    },
                  )
                ],
              ),
              const Divider(),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: currentGroupQuestions.length,
                  itemBuilder: (context, index) {
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: index == indexInGroup ? Colors.blue : Colors.grey[200],
                        foregroundColor: index == indexInGroup ? Colors.white : Colors.black,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          indexInGroup = index;
                          selectedOptions.clear();
                          isSubmitted = false;
                        });
                        _saveProgress();
                      },
                      child: Text('${groupIndex * 20 + index + 1}'),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (allQuestions.isEmpty) return Scaffold(appBar: AppBar(title: Text(widget.title)), body: const Center(child: Text("暂无题目数据")));

    Question q = currentGroupQuestions[indexInGroup];
    bool isMultiple = q.correctAnswer.length > 1;
    int currentAbsoluteNumber = groupIndex * 20 + indexInGroup + 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} ($currentAbsoluteNumber/${allQuestions.length})'),
        actions: [
          Row(
            children: [
              const Text("背题", style: TextStyle(fontSize: 12)),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: isMultiple ? Colors.orange[100] : Colors.blue[100], borderRadius: BorderRadius.circular(4)),
                  child: Text(isMultiple ? "多选题" : "单选题", style: TextStyle(color: isMultiple ? Colors.orange[900] : Colors.blue[900])),
                ),
                Text("第 ${groupIndex + 1} 组 (${indexInGroup + 1}/20)", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),
            Text("${q.id}. ${q.content}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(onPressed: indexInGroup > 0 ? _prevQuestion : null, child: const Text("上一题")),
                ElevatedButton(
                  onPressed: _nextQuestion,
                  child: Text(indexInGroup == currentGroupQuestions.length - 1 ? "完成本组" : "下一题"),
                ),
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
