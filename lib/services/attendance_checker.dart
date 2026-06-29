import 'package:syukketu_app/db/database.dart';
import 'package:syukketu_app/services/location_service.dart';

class AttendanceChecker {
  final DatabaseService _dbService = DatabaseService();
  final LocationService _locationService = LocationService();

  /// 自動出欠チェックを実行するメイン関数
  Future<void> executeAutoCheck() async {
    final now = DateTime.now();

    // 1. 今日の曜日を取得 (DateTime.weekday は 1:月曜 〜 7:日曜 なので、-1 して 0:月曜 〜 4:金曜 に合わせる)
    int dayOfWeek = now.weekday - 1;
    if (dayOfWeek < 0 || dayOfWeek > 4) {
      print('今日は土日なので授業はありません。');
      return;
    }

    // 2. 現在の時刻から「何限目か」を判定する
    int currentPeriod = _getCurrentPeriod(now);
    if (currentPeriod == 0) {
      print('現在は授業時間外です。');
      return;
    }

    // 3. データベースから、今の時間帯の「教科」を取得
    final entry = await _dbService.getTimetableEntry(dayOfWeek, currentPeriod);
    if (entry == null) {
      print('この時間は空きコマです。');
      return;
    }

    // 4. 重複チェック（すでに今日この授業の欠席・遅刻判定が終わっていないか）
    final hasRecord = await _dbService.hasAbsentRecordToday(
        entry.subjectId, dayOfWeek, currentPeriod);
    if (hasRecord) {
      print('すでに今日のこの授業の出欠データは記録されています。');
      return;
    }

    // 5. 位置情報を取得して学校にいるか判定！
    final hasPermission = await _locationService.initialize();
    if (!hasPermission) {
      print('位置情報の権限がないため判定できません。');
      return;
    }

    final isAtSchool = await _locationService.isAtSchool();

    if (!isAtSchool) {
      // 6. 学校にいない場合、自動的に「欠席（未確認）」としてデータベースに保存
      print('⚠️ 学校から離れています。自動で欠席として記録します。');
      await _dbService.saveAbsent(
        subjectId: entry.subjectId,
        dayOfWeek: dayOfWeek,
        period: currentPeriod,
        type: 0, // 0: 欠席として仮登録
        isAuto: true, // 自動で登録されたフラグ
        isConfirmed: false, // ユーザーの確認待ち
      );
    } else {
      print('✅ 学校にいることを確認しました。出席です！');
    }
  }

  /// 時間から何限目かを判定するヘルパー関数
  /// ※ 時間はご自身の学校のチャイムに合わせて書き換えてください！
  int _getCurrentPeriod(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final timeValue = hour * 100 + minute; // 例: 9時30分 -> 930

    // 授業の開始〜終了時間（バッファを持たせてもOKです）
    if (timeValue >= 900 && timeValue <= 1030) return 1; // 1限: 9:00 - 10:30
    if (timeValue >= 1040 && timeValue <= 1210) return 2; // 2限: 10:40 - 12:10
    if (timeValue >= 1300 && timeValue <= 1430) return 3; // 3限: 13:00 - 14:30
    if (timeValue >= 1440 && timeValue <= 1610) return 4; // 4限: 14:40 - 16:10

    return 0; // 授業時間外
  }
}