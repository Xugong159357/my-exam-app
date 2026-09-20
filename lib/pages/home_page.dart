import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'practice_page.dart';
import 'search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int lastProgressIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  void _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      lastProgressIndex = prefs.getInt('saved_sequence_index') ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("铁路客运规章刷题系统"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 上次进度提示条
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
              child: Text(
                "上次顺序练习到：第 ${lastProgressIndex + 1} 题（第 ${(lastProgressIndex ~/ 20) + 1} 组）",
                style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildMenuCard(context, "顺序练习", Icons.list_alt, Colors.blue, () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PracticePage(modeType: 'all', title: '顺序练习')),
                    );
                    _loadProgress(); // 从练习返回后刷新显示进度
                  }),
                  _buildMenuCard(context, "错题本", Icons.error_outline, Colors.red, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PracticePage(modeType: 'wrong', title: '错题练习')),
                    );
                  }),
                  _buildMenuCard(context, "我的收藏", Icons.star_border, Colors.amber[700]!, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PracticePage(modeType: 'favorite', title: '我的收藏')),
                    );
                  }),
                  _buildMenuCard(context, "题目搜索", Icons.search, Colors.green, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage()));
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
