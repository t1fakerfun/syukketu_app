import 'package:flutter/material.dart';
// ↓ さっき作ったチェッカーと、各種ページをインポート（パスは環境に合わせてください）
import 'package:syukketu_app/services/attendance_checker.dart';
import 'package:syukketu_app/screens/mount-page.dart'; // 時間割画面
import 'package:syukketu_app/screens/register-page.dart'; // 教科登録画面
import 'package:syukketu_app/screens/check-and-analyze-page.dart'; // 出欠確認画面

import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart'; // 追加
import 'package:syukketu_app/services/attendance_checker.dart';
// ※他のインポートはそのまま

// 🌟 バックグラウンドで呼ばれる処理（トップレベルに書く）
@pragma('vm:entry-point')
void checkAttendanceAlarm() async {
  print("⏰ アラーム発動！出欠の自動判定を開始します...");
  try {
    final checker = AttendanceChecker();
    await checker.executeAutoCheck();
  } catch (e) {
    print('アラーム処理でエラー: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // AlarmManagerの初期化
  await AndroidAlarmManager.initialize();

  // 今日の授業の時間にアラームをセットする関数を呼ぶ
  await scheduleClassAlarms();

  runApp(const MyApp());
}

// 🌟 1日4回のアラームをセットする関数
Future<void> scheduleClassAlarms() async {
  final now = DateTime.now();

  // 1〜4限の「時間」と「分」のリスト（学校に合わせて修正してください）
  final classTimes = [
    {'hour': 8, 'minute': 40, 'id': 1},   // 1限 8:40
    {'hour': 10, 'minute': 25, 'id': 2}, // 2限 10:25
    {'hour': 12, 'minute': 45, 'id': 3},  // 3限 12:45
    {'hour': 14, 'minute': 30, 'id': 4}, // 4限 14:30
  ];

  for (var time in classTimes) {
    // 今日（または明日）のアラーム時間を計算
    DateTime alarmTime = DateTime(now.year, now.month, now.day, time['hour']!, time['minute']!);

    // もし今日のその時間がすでに過ぎていたら、明日の同じ時間にセットする
    if (alarmTime.isBefore(now)) {
      alarmTime = alarmTime.add(const Duration(days: 1));
    }

    // アラームの予約（毎日その時間に繰り返す）
    await AndroidAlarmManager.periodic(
      const Duration(days: 1), // 1日おき
      time['id']!, // 1限ならID:1、2限ならID:2
      checkAttendanceAlarm,
      startAt: alarmTime,
      exact: true,  // ★重要: 時間ピッタリに発動させる！
      wakeup: true, // ★重要: スマホがスリープ状態でもCPUを叩き起こす！
    );
    print("予約完了: ${time['id']}限のアラームを $alarmTime にセットしました");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '出欠管理アプリ',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainTabScreen(), // タブ画面を初期表示
    );
  }
}

// （おまけ）画面下部のタブバーを作るためのクラス
class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const MountPage(),            // 時間割
    const RegisterPage(),         // 教科登録
    const CheckAndAnalyzePage(),  // 分析・確認
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_on), label: '時間割'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: '教科登録'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: '分析'),
        ],
      ),
    );
  }
}