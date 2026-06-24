import 'package:flutter/material.dart';
import 'package:syukketu_app/db/database.dart';

final _dbService = DatabaseService();

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _limitController = TextEditingController();
  bool _isTuunenn = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('教科登録')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '教科名'),
            ),
            TextField(
              controller: _limitController,
              decoration: const InputDecoration(labelText: '週何コマ？'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('通年科目ですか？'),
              // スイッチの状態に応じて文字を切り替える
              subtitle: Text(_isTuunenn ? 'はい（通年）' : 'いいえ（半期）'),
              value: _isTuunenn,
              onChanged: (bool value) {
                // スイッチが押されたら、画面を更新して状態を切り替える
                setState(() {
                  _isTuunenn = value;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final name = _nameController.text.trim();
                int limit = int.tryParse(_limitController.text.trim()) ?? 0;
                //半期で授業は15回
                limit = limit * 15;
                if (_isTuunenn) {
                  limit = limit * 2;
                }
                limit = limit * 2 ~/ 4;
                if (name.isEmpty) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('教科名を入力してください')));
                  return;
                }

                // エラーで画面が真っ黒になるのを防ぐため try-catch を使用
                try {
                  await _dbService.registerSubject(name, limit);

                  // awaitの後にcontextを使うための安全確認
                  if (!mounted) return;

                  // 成功メッセージを表示
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('教科の登録に成功しました！')),
                  );

                  // 前の画面に戻る
                  _nameController.clear();
                  _limitController.clear();
                  setState(() {
                    _isTuunenn = false;
                  });
                } catch (e) {
                  // もしデータベース側でエラー（同じ名前が既に登録されている等）が起きた場合の処理
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('登録に失敗しました: $e')));
                }
              },
              child: const Text('登録'),
            ),
          ],
        ),
      ),
    );
  }
}
