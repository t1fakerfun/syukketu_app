import 'package:flutter/material.dart';
import 'package:syukketu_app/db/database.dart';

final _dbService = DatabaseService();

class MountPage extends StatefulWidget {
  const MountPage({Key? key}) : super(key: key);

  @override
  _MountPageState createState() => _MountPageState();
}

class _MountPageState extends State<MountPage> {
  final List<String> _dayNames = ['月', '火', '水', '木', '金'];

  String _getSubjectName(
    int day,
    int period,
    List<TimetableEntry> entries,
    List<Subject> subjects,
  ) {
    try {
      final entry = entries.firstWhere(
        (e) => e.dayOfWeek == day && e.period == period,
      );
      final subject = subjects.firstWhere((s) => s.id == entry.subjectId);
      return subject.name;
    } catch (e) {
      return '';
    }
  }

  // ★ ポイント1: 関数をクラスの中に移動しました（setStateを使えるようにするため）
  void _showSubjectSelectionDialog(BuildContext context, int day, int period) {
    final dayName = _dayNames[day];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('$dayName曜日 $period限の教科を選択'),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<List<Subject>>(
              stream: appDatabase.select(appDatabase.subjects).watch(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final subjects = snapshot.data!;

                if (subjects.isEmpty) {
                  return const Text('登録されている教科がありません。先に教科登録をしてください。');
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: subjects.length,
                  itemBuilder: (context, index) {
                    final subject = subjects[index];
                    return ListTile(
                      title: Text(subject.name),
                      onTap: () async {
                        final navigator = Navigator.of(dialogContext);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);

                        try {
                          // database.dart に作ったメソッドを呼び出す
                          await _dbService.saveTimetableEntry(
                            dayOfWeek: day,
                            period: period,
                            subjectId: subject.id,
                          );

                          navigator.pop();

                          // ★ ポイント2: 強制的に画面を再描画するおまじない
                          setState(() {});

                          scaffoldMessenger.showSnackBar(
                            const SnackBar(content: Text('時間割を更新しました！')),
                          );
                        } catch (e) {
                          navigator.pop();
                          scaffoldMessenger.showSnackBar(
                            SnackBar(content: Text('エラーが発生しました: $e')),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                try {
                  await _dbService.deleteTimetableEntry(
                    dayOfWeek: day,
                    period: period,
                  );

                  navigator.pop();
                  setState(() {});

                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('削除しました。')),
                  );
                } catch (e) {
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('エラーが発生しました: $e')),
                  );
                }
              },
              child: const Text('削除'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('キャンセル'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('時間割')),
      // ★ ポイント3: .watch() で常にデータベースの変更を監視
      body: StreamBuilder<List<Subject>>(
        stream: appDatabase.select(appDatabase.subjects).watch(),
        builder: (context, subjectSnapshot) {
          if (!subjectSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final subjects = subjectSnapshot.data!;

          return StreamBuilder<List<TimetableEntry>>(
            stream: appDatabase.select(appDatabase.timetableEntries).watch(),
            builder: (context, entrySnapshot) {
              if (!entrySnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries = entrySnapshot.data!;

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Table(
                  border: TableBorder.all(color: Colors.grey.shade400),
                  columnWidths: const {0: FixedColumnWidth(40.0)},
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade200),
                      children: [
                        const SizedBox(
                          height: 40,
                          child: Center(child: Text('')),
                        ),
                        for (String dayName in _dayNames)
                          SizedBox(
                            height: 40,
                            child: Center(
                              child: Text(
                                dayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    for (int period = 1; period <= 4; period++)
                      TableRow(
                        children: [
                          SizedBox(
                            height: 80,
                            child: Center(
                              child: Text(
                                '$period',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          for (int day = 0; day < 5; day++)
                            InkWell(
                              onTap: () {
                                _showSubjectSelectionDialog(
                                  context,
                                  day,
                                  period,
                                );
                              },
                              child: SizedBox(
                                height: 80,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Text(
                                      _getSubjectName(
                                        day,
                                        period,
                                        entries,
                                        subjects,
                                      ),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
