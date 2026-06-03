import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';

class UserIdentityService extends ChangeNotifier {
  final Box _box = Hive.box('identity');
  final _uuid = const Uuid();

  String get id {
    if (!_box.containsKey('deviceId')) {
      _box.put('deviceId', _uuid.v4());
    }
    return _box.get('deviceId') as String;
  }

  bool get isGhostMode => _box.get('isGhostMode', defaultValue: true) as bool;
  String? get customDisplayName => _box.get('displayName') as String?;
  String? get profileImagePath => _box.get('profileImagePath') as String?;
  bool get hasOnboarded => _box.get('hasOnboarded', defaultValue: false) as bool;

  int get messageCount => _box.get('messageCount', defaultValue: 0) as int;
  int get reactionCount => _box.get('reactionCount', defaultValue: 0) as int;
  int get spacesJoinedCount => _box.get('spacesJoinedCount', defaultValue: 0) as int;

  Future<void> incrementMessageCount() async {
    await _box.put('messageCount', messageCount + 1);
    notifyListeners();
  }

  Future<void> incrementReactionCount() async {
    await _box.put('reactionCount', reactionCount + 1);
    notifyListeners();
  }
  
  Future<void> incrementSpacesJoinedCount() async {
    await _box.put('spacesJoinedCount', spacesJoinedCount + 1);
    notifyListeners();
  }

  Future<void> setIdentity({required bool ghostMode, String? displayName}) async {
    await _box.put('isGhostMode', ghostMode);
    await _box.put('hasOnboarded', true);
    if (!ghostMode && displayName != null && displayName.isNotEmpty) {
      await _box.put('displayName', displayName);
    } else if (ghostMode) {
      await _box.delete('displayName');
    }
    notifyListeners();
  }

  Future<void> setProfileImagePath(String? path) async {
    if (path == null || path.trim().isEmpty) {
      await _box.delete('profileImagePath');
    } else {
      await _box.put('profileImagePath', path);
    }
    notifyListeners();
  }

  String get safeDisplayName {
    if (isGhostMode) {
      final ghostId = _box.get('ghostId') ?? _generateGhostId();
      _box.put('ghostId', ghostId);
      return "ghost_$ghostId";
    }
    return customDisplayName ?? "user_${id.substring(0, 4)}";
  }

  String _generateGhostId() {
    return Random().nextInt(9999).toString().padLeft(4, '0');
  }

  Future<String> getRealDeviceName() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    // Assuming Android for example, implement platform check if needed
    var build = await deviceInfo.androidInfo; 
    return build.model;
  }
}
