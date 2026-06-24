import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:syukketu_app/db/database.dart';

final _dbService = DatabaseService();

class CheckAndAnalyzePage extends StatefulWidget {
  const CheckAndAnalyzePage({Key? key}) : super(key: key);

  @override
  _CheckAndAnalyzePageState createState() => _CheckAndAnalyzePageState();
}

class _CheckAndAnalyzePageState extends State<CheckAndAnalyzePage> {
  final List<String> _dayNames = ['月', '火', '水', '木', '金'];

  // --- 教科の上限(Limit)を変更するダイアログ ---
  void _showEditLimitDialog(BuildContext context, Subject subject) {
    final TextEditingController limitController = TextEditingController(
      text: subject.limitCount.toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${subject.name} の上限変更'),
          content: TextField(
            controller: limitController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '週何時間？(Limit)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newLimit = int.tryParse(limitController.text.trim());
                if (newLimit != null) {
                  await _dbService.updateSubjectLimit(subject.id, newLimit);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('上限を変更しました')));
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('出席回数の確認と分析')),
      // 教科データを全体で使うため、一番上でStreamBuilderを回す
      body: StreamBuilder<List<Subject>>(
        stream: appDatabase.select(appDatabase.subjects).watch(),
        builder: (context, subjectSnapshot) {
          if (!subjectSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final subjects = subjectSnapshot.data!;

          return CustomScrollView(
            slivers: [
              // ==========================================
              // ① 未確認データのセクション (isAuto == true & isConfirmed == false)
              // ==========================================
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    '⚠️ 未確認の出欠データ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: StreamBuilder<List<AbsentTableData>>(
                  stream:
                      (appDatabase.select(appDatabase.absentTable)..where(
                            (tbl) =>
                                tbl.isAuto.equals(true) &
                                tbl.isConfirmed.equals(false),
                          ))
                          .watch(),
                  builder: (context, absentSnapshot) {
                    if (!absentSnapshot.hasData) return const SizedBox.shrink();
                    final unconfirmedAbsents = absentSnapshot.data!;

                    if (unconfirmedAbsents.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('未確認のデータはありません。素晴らしい！'),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: unconfirmedAbsents.length,
                      itemBuilder: (context, index) {
                        final absent = unconfirmedAbsents[index];
                        // 教科IDから教科名を探す
                        final subjectName = subjects
                            .firstWhere(
                              (s) => s.id == absent.subjectId,
                              orElse: () => const Subject(
                                id: -1,
                                name: '不明な教科',
                                limitCount: 0,
                              ),
                            )
                            .name;
                        final dayStr = _dayNames[absent.dayOfWeek];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          color: Colors.orange.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$dayStr曜日 ${absent.period}限 : $subjectName',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text('自動で欠席として記録されました。状況を確定してください。'),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // 欠席として確定 (type: 0)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade400,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => _dbService
                                          .confirmAbsentRecord(absent.id, 0),
                                      child: const Text('欠席'),
                                    ),
                                    // 遅刻として確定 (type: 1)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange.shade400,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => _dbService
                                          .confirmAbsentRecord(absent.id, 1),
                                      child: const Text('遅刻'),
                                    ),
                                    // 誤判定だった場合（削除）
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.grey.shade700,
                                      ),
                                      onPressed: () => _dbService
                                          .deleteAbsentRecordById(absent.id),
                                      child: const Text('出席していた'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(
                child: Divider(height: 40, thickness: 2),
              ),

              // ==========================================
              // ② 登録済み教科のLimit確認・変更セクション
              // ==========================================
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    '📚 教科の欠席上限(Limit)管理',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final subject = subjects[index];
                  return ListTile(
                    title: Text(subject.name),
                    subtitle: Text('週のコマ数(Limit設定値): ${subject.limitCount}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditLimitDialog(context, subject),
                    ),
                  );
                }, childCount: subjects.length),
              ),
            ],
          );
        },
      ),
    );
  }
}
