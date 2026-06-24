# syukketu_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## 実装したい機能

出欠の確認を自動で行う。もし学校にいるべき時間にいないってなったら学校にいなかったかの確認を行う（家で授業の可能性もあるから）。
ユーザーは科目の設定を行い。時間割画面で科目をマウントする。
メモ：特殊な日程になった時（時間割の変更があった時や学校が休みだった時手動で内容の変更を行う必要がある）
欠席したか？→そうですor いいえ（自動的に聞く）
自己申告→”教科名”を休みました（システムが取りこぼした時）
授業が15回の時は15*2/4 = 7.5となる　8まで行ったら確定で落単なので7まで休める。欠席は2回分の休み、遅刻は１回分の休みと換算される。
