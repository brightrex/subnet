import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class AppSettingsService extends ChangeNotifier {
  final Box _box = Hive.box('settings');

  Color get accentColor => Color(_box.get('accentColor', defaultValue: 0xFFF6D365) as int);
  double get fontScale => (_box.get('fontScale', defaultValue: 1.0) as num).toDouble();
  bool get showTimestamps => _box.get('showTimestamps', defaultValue: true) as bool;
  bool get notificationsEnabled => _box.get('notificationsEnabled', defaultValue: true) as bool;
  bool get soundsEnabled => _box.get('soundsEnabled', defaultValue: true) as bool;
  bool get vibrateEnabled => _box.get('vibrateEnabled', defaultValue: true) as bool;

  Future<void> setAccentColor(Color color) async {
    await _box.put('accentColor', color.toARGB32());
    notifyListeners();
  }

  Future<void> setFontScale(double value) async {
    await _box.put('fontScale', value.clamp(0.88, 1.18));
    notifyListeners();
  }

  Future<void> setShowTimestamps(bool value) async {
    await _box.put('showTimestamps', value);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    await _box.put('notificationsEnabled', value);
    notifyListeners();
  }

  Future<void> setSoundsEnabled(bool value) async {
    await _box.put('soundsEnabled', value);
    notifyListeners();
  }

  Future<void> setVibrateEnabled(bool value) async {
    await _box.put('vibrateEnabled', value);
    notifyListeners();
  }
}
