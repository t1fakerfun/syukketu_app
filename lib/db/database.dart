import 'package:drift/drift.dart';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

final AppDatabase appDatabase = AppDatabase();

class Subjects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get limitCount => integer()();
}

class TimetableEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get dayOfWeek => integer()(); // 0:月〜4:金
  IntColumn get period => integer()(); // 1〜4限
  IntColumn get subjectId =>
      integer().references(Subjects, #id)(); // 外部キー（教科と紐付け）
}

class AbsentTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId => integer().references(Subjects, #id)();
  IntColumn get dayOfWeek => integer()();
  IntColumn get period => integer()();
  IntColumn get type => integer().withDefault(const Constant(0))();
  BoolColumn get isAuto => boolean().withDefault(const Constant(false))();
  BoolColumn get isConfirmed => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
}

@DriftDatabase(tables: [Subjects, TimetableEntries, AbsentTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

class DatabaseService {
  final AppDatabase db = appDatabase;

  // 教科登録
  Future<void> registerSubject(String name, int limit) async {
    await db
        .into(db.subjects)
        .insert(
          SubjectsCompanion.insert(
            name: name,
            limitCount: limit, // ここで引数を受け取る
          ),
        );
  }

  Future<void> registerTimetableEntry(
    int dayOfWeek,
    int period,
    int subjectId,
  ) async {
    await db
        .into(db.timetableEntries)
        .insert(
          TimetableEntriesCompanion.insert(
            dayOfWeek: dayOfWeek,
            period: period,
            subjectId: subjectId,
          ),
        );
  }

  Future<void> saveTimetableEntry({
    required int dayOfWeek,
    required int period,
    required int subjectId,
  }) async {
    final existingEntry =
        await (db.select(db.timetableEntries)..where(
              (tbl) =>
                  tbl.dayOfWeek.equals(dayOfWeek) & tbl.period.equals(period),
            ))
            .getSingleOrNull();

    if (existingEntry != null) {
      // 2. 存在する場合は上書き（Update）
      await db
          .update(db.timetableEntries)
          .replace(existingEntry.copyWith(subjectId: subjectId));
    } else {
      // 3. 存在しない場合は新規追加（Insert）
      await db
          .into(db.timetableEntries)
          .insert(
            TimetableEntriesCompanion.insert(
              dayOfWeek: dayOfWeek,
              period: period,
              subjectId: subjectId,
            ),
          );
    }
  }

  Future<void> deleteTimetableEntry({
    required int dayOfWeek,
    required int period,
  }) async {
    final existingEntry =
        await (db.select(db.timetableEntries)..where(
              (tbl) =>
                  tbl.dayOfWeek.equals(dayOfWeek) & tbl.period.equals(period),
            ))
            .getSingleOrNull();
    if (existingEntry != null) {
      await db.delete(db.timetableEntries).delete(existingEntry);
    }
  }

  //欠席情報の管理
  Future<void> saveAbsent({
    required int subjectId,
    required int dayOfWeek,
    required int period,
    required int type,
    bool isAuto = false,
    bool isConfirmed = true,
  }) async {
    await db
        .into(db.absentTable)
        .insert(
          AbsentTableCompanion.insert(
            subjectId: subjectId,
            dayOfWeek: dayOfWeek,
            period: period,
            type: Value(type),
            isAuto: Value(isAuto),
            isConfirmed: Value(isConfirmed),
          ),
        );
  }

  Future<void> deleteAbsent({
    required int subjectId,
    required int dayOfWeek,
    required int period,
  }) async {
    final existingAbsentEntry =
        await (db.select(db.absentTable)..where(
              (tbl) =>
                  tbl.subjectId.equals(subjectId) &
                  tbl.dayOfWeek.equals(dayOfWeek) &
                  tbl.period.equals(period),
            ))
            .getSingleOrNull();
    if (existingAbsentEntry != null) {
      await db.delete(db.absentTable).delete(existingAbsentEntry);
    }
  }

  Future<void> updateSubjectLimit(int subjectId, int newLimit) async {
    await (db.update(db.subjects)..where((tbl) => tbl.id.equals(subjectId)))
        .write(SubjectsCompanion(limitCount: Value(newLimit)));
  }

  Future<void> confirmAbsentRecord(int absentId, int type) async {
    await (db.update(
      db.absentTable,
    )..where((tbl) => tbl.id.equals(absentId))).write(
      AbsentTableCompanion(
        type: Value(type), // 0: 欠席, 1: 遅刻
        isConfirmed: const Value(true), // 確認済みにする
      ),
    );
  }

  // 3. ID指定で出欠データを削除するメソッド（「実は出席していた」場合のキャンセル用）
  Future<void> deleteAbsentRecordById(int absentId) async {
    await (db.delete(
      db.absentTable,
    )..where((tbl) => tbl.id.equals(absentId))).go();
  }

  // --- lib/db/database.dart の DatabaseService 内に追加 ---

  // 指定した曜日・時限の「時間割データ」を取得する
  Future<TimetableEntry?> getTimetableEntry(int dayOfWeek, int period) async {
    return await (db.select(db.timetableEntries)..where(
          (tbl) => tbl.dayOfWeek.equals(dayOfWeek) & tbl.period.equals(period),
        ))
        .getSingleOrNull();
  }

  // 「今日」すでにその授業の出欠（欠席・遅刻）データが作られているか確認する
  Future<bool> hasAbsentRecordToday(
    int subjectId,
    int dayOfWeek,
    int period,
  ) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day); // 今日の0時0分

    final existing =
        await (db.select(db.absentTable)..where(
              (tbl) =>
                  tbl.subjectId.equals(subjectId) &
                  tbl.dayOfWeek.equals(dayOfWeek) &
                  tbl.period.equals(period) &
                  tbl.createdAt.isBiggerOrEqualValue(startOfDay),
            )) // 今日作られたデータか
            .get();

    return existing.isNotEmpty; // データがあればtrue
  }

  Future<void> confirmAbsentAndDecrementLimit(int absentId, int type) async {
    // ① まず欠席レコードを確定
    await confirmAbsentRecord(absentId, type);

    // ② typeが0（欠席）の場合のみLimitを減らす
    //    遅刻（type:1）の場合は減らさない（仕様に応じて変更してください）
    // 欠席レコードからsubjectIdを取得
    final absent = await (db.select(
      db.absentTable,
    )..where((tbl) => tbl.id.equals(absentId))).getSingleOrNull();

    if (absent == null) return;

    // 教科の現在のlimitCountを取得
    final subject = await (db.select(
      db.subjects,
    )..where((tbl) => tbl.id.equals(absent.subjectId))).getSingleOrNull();

    if (subject == null) return;

    // limitCountを1減らす（0以下にはしない）
    int newLimit;
    if (type == 1) {
      newLimit = (subject.limitCount - 1).clamp(0, 999);
    } else {
      newLimit = (subject.limitCount - 2).clamp(0, 999);
    }
    await updateSubjectLimit(subject.id, newLimit);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app_database.sqlite'));
    return NativeDatabase(file);
  });
}
