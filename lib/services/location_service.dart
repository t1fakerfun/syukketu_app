import 'package:location/location.dart';
import 'dart:math' as math;

class LocationService {
  final Location _location = Location();

  // 目標とする学校の座標（品川キャンパス付近の緯度・経度）
  final double schoolLat = 35.606350;
  final double schoolLon = 139.749158;

  // 何メートル以内なら「出席」とみなすか（例: 300m以内）
  final double attendanceRadius = 300.0;

  /// 初期化と権限の確認
  Future<bool> initialize() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    // 位置情報サービス自体がオンになっているか
    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false;
    }

    // アプリへの権限が許可されているか
    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return false;
    }

    // バックグラウンド実行の許可をリクエスト
    try {
      await _location.enableBackgroundMode(enable: true);
    } catch (e) {
      print('バックグラウンドモードの設定に失敗しました: $e');
    }

    return true;
  }

  /// 現在地を取得して、学校にいるかどうかを判定する
  Future<bool> isAtSchool() async {
    try {
      final locationData = await _location.getLocation();

      if (locationData.latitude == null || locationData.longitude == null) {
        return false;
      }

      // 現在地と学校との距離を計算
      final distance = _calculateDistance(
        locationData.latitude!,
        locationData.longitude!,
        schoolLat,
        schoolLon,
      );

      print('現在の学校からの距離: ${distance.toStringAsFixed(1)} メートル');

      // 指定した半径以内にいれば出席(true)
      return distance <= attendanceRadius;
    } catch (e) {
      print('位置情報の取得エラー: $e');
      return false;
    }
  }

  /// 2つの緯度・経度から距離（メートル）を計算する数学の公式
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371000; // 地球の半径 (メートル)
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }
}
