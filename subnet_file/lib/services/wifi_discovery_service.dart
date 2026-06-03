import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nsd/nsd.dart' as nsd;

import '../models/peer.dart';
import '../models/space.dart';

class WifiDiscoveryService {
  final int port = 4321;
  final String serviceType = '_ghostchat._tcp';

  nsd.Registration? _registration;
  nsd.Discovery? _discovery;
  SpaceMeta? _hostedMeta;
  String _displayName = 'Subnet';
  String _deviceId = '';
  bool _isGhost = false;
  int _memberCount = 1;
  StreamSubscription<int>? _connectionSubscription;
  Timer? _memberUpdateTimer;
  Timer? _expiryTimer;

  final _peersController = StreamController<List<Peer>>.broadcast();
  Stream<List<Peer>> get peersStream => _peersController.stream;

  final _hostedSpaceController = StreamController<String?>.broadcast();
  Stream<String?> get hostedSpaceStream => _hostedSpaceController.stream;

  final _hostedMetaController = StreamController<SpaceMeta?>.broadcast();
  Stream<SpaceMeta?> get hostedSpaceMetaStream => _hostedMetaController.stream;

  final List<Peer> _discoveredPeers = [];

  Future<void> startDiscovery({
    required String displayName,
    required String deviceId,
    required bool isGhost,
  }) async {
    if (_registration != null || _discovery != null) return;
    _displayName = displayName;
    _deviceId = deviceId;
    _isGhost = isGhost;
    // 1. Register current device
    _registration = await nsd.register(
      nsd.Service(
        name: displayName,
        type: serviceType,
        port: port,
        txt: _buildTxt(),
      ),
    );

    _hostedSpaceController.add(_hostedMeta?.name);

    // 2. Discover other devices
    _discovery = await nsd.startDiscovery(serviceType);
    _discovery!.addListener(() {
      _updatePeers(_discovery!.services);
    });
  }

  void _updatePeers(List<nsd.Service> services) {
    _discoveredPeers.clear();
    for (var service in services) {
      if (service.name != null && service.name != _registration?.service.name) {
        String? ip = service.host;
        if (ip != null) {
          final txt = _decodeTxt(service.txt);
          final deviceId = txt['id'] ?? service.name ?? ip;
          final displayName = SpaceMeta.decodeTxtValue(
            txt['nm'] ?? service.name ?? 'Unknown',
          );
          final isGhost = txt['gh'] == '1';
          final spaceMeta = _spaceMetaFromTxt(txt);
          _discoveredPeers.add(
            Peer(
              ipAddress: ip,
              displayName: displayName,
              deviceId: deviceId,
              isGhost: isGhost,
              spaceMeta: spaceMeta,
            ),
          );
        }
      }
    }
    _peersController.add(_discoveredPeers);
  }

  Future<void> updatePresence({
    required String displayName,
    required String deviceId,
    required bool isGhost,
  }) async {
    _displayName = displayName;
    _deviceId = deviceId;
    _isGhost = isGhost;

    if (_registration != null) {
      await nsd.unregister(_registration!);
      _registration = null;
    }
    _registration = await nsd.register(
      nsd.Service(
        name: _displayName,
        type: serviceType,
        port: port,
        txt: _buildTxt(),
      ),
    );
    _hostedSpaceController.add(_hostedMeta?.name);
  }

  Future<void> createHostedSpace(SpaceMeta meta) async {
    _memberCount = 1;
    _hostedMeta = meta.copyWith(memberCount: _memberCount, reportCount: 0);
    _hostedMetaController.add(_hostedMeta);
    await updatePresence(
      displayName: _displayName,
      deviceId: _deviceId,
      isGhost: _isGhost,
    );
  }

  SpaceMeta? get hostedSpaceMeta => _hostedMeta;

  void attachConnectionStream(Stream<int> stream) {
    _connectionSubscription?.cancel();
    _connectionSubscription = stream.listen((count) {
      if (_hostedMeta == null) return;
      _updateMemberCount(count + 1);
    });
  }

  void _updateMemberCount(int count) {
    if (_hostedMeta == null) return;
    if (_memberCount == count) return;
    _memberCount = count;
    _hostedMeta = _hostedMeta!.copyWith(memberCount: count);
    _hostedMetaController.add(_hostedMeta);
    _schedulePresenceUpdate();
    _handleExpiryTimer();
  }

  void updateHostedReportCount(int count) {
    if (_hostedMeta == null) return;
    _hostedMeta = _hostedMeta!.copyWith(reportCount: count);
    _hostedMetaController.add(_hostedMeta);
    _schedulePresenceUpdate();
  }

  void _handleExpiryTimer() {
    if (_hostedMeta == null || !_hostedMeta!.isTemporary) {
      _expiryTimer?.cancel();
      _expiryTimer = null;
      return;
    }

    if (_memberCount > 1) {
      _expiryTimer?.cancel();
      _expiryTimer = null;
      return;
    }

    _expiryTimer ??= Timer(const Duration(minutes: 30), () {
      clearHostedSpace(reason: 'Temporary space expired');
    });
  }

  void _schedulePresenceUpdate() {
    _memberUpdateTimer?.cancel();
    _memberUpdateTimer = Timer(const Duration(seconds: 2), () {
      if (_registration != null) {
        updatePresence(
          displayName: _displayName,
          deviceId: _deviceId,
          isGhost: _isGhost,
        );
      }
    });
  }

  Future<void> clearHostedSpace({String? reason}) async {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _hostedMeta = null;
    _hostedMetaController.add(null);
    _hostedSpaceController.add(null);
    await updatePresence(
      displayName: _displayName,
      deviceId: _deviceId,
      isGhost: _isGhost,
    );
  }

  Future<void> refreshDiscovery({
    required String displayName,
    required String deviceId,
    required bool isGhost,
  }) async {
    await _stopDiscoveryInternal();
    await startDiscovery(
      displayName: displayName,
      deviceId: deviceId,
      isGhost: isGhost,
    );
  }

  Future<void> stopDiscovery({bool dispose = false}) async {
    await _stopDiscoveryInternal();
    if (dispose) {
      await _connectionSubscription?.cancel();
      _connectionSubscription = null;
      await _peersController.close();
      await _hostedSpaceController.close();
      await _hostedMetaController.close();
    }
  }

  Future<void> _stopDiscoveryInternal() async {
    if (_registration != null) {
      await nsd.unregister(_registration!);
      _registration = null;
    }
    if (_discovery != null) {
      await nsd.stopDiscovery(_discovery!);
      _discovery = null;
    }
    _discoveredPeers.clear();
    if (!_peersController.isClosed) {
      _peersController.add(const []);
    }
  }

  Map<String, Uint8List?> _buildTxt() {
    final map = <String, Uint8List?>{
      'id': _txtValue(_deviceId),
      'nm': _txtValue(SpaceMeta.encodeTxtValue(_displayName)),
      'gh': _txtValue(_isGhost ? '1' : '0'),
    };

    final meta = _hostedMeta;
    if (meta != null) {
      map['sp'] = _txtValue('1');
      map['sid'] = _txtValue(meta.spaceId);
      map['sn'] = _txtValue(SpaceMeta.encodeTxtValue(meta.name));
      map['sv'] = _txtValue(SpaceMeta.visibilityCode(meta.visibility));
      map['sl'] = _txtValue(SpaceMeta.lifetimeCode(meta.lifetime));
      map['sm'] = _txtValue(meta.memberCount.toString());
      map['sa'] = _txtValue(SpaceMeta.encodeTxtValue(meta.adminName));
      map['aid'] = _txtValue(meta.adminId);
      map['kp'] = _txtValue(
        meta.visibility == SpaceVisibility.private ? '1' : '0',
      );
    }

    return map;
  }

  Uint8List _txtValue(String value) => Uint8List.fromList(utf8.encode(value));

  Map<String, String> _decodeTxt(Map<String, Uint8List?>? txt) {
    if (txt == null) return {};
    final map = <String, String>{};
    for (final entry in txt.entries) {
      if (entry.value == null) continue;
      map[entry.key] = utf8.decode(entry.value!);
    }
    return map;
  }

  SpaceMeta? _spaceMetaFromTxt(Map<String, String> txt) {
    if (txt['sp'] != '1') return null;

    final name = SpaceMeta.decodeTxtValue(txt['sn'] ?? 'Space');
    final adminName = SpaceMeta.decodeTxtValue(txt['sa'] ?? 'Admin');
    return SpaceMeta(
      spaceId: txt['sid'] ?? '',
      adminId: txt['aid'] ?? '',
      adminName: adminName,
      name: name,
      description: '',
      visibility: SpaceMeta.visibilityFromCode(txt['sv']),
      lifetime: SpaceMeta.lifetimeFromCode(txt['sl']),
      memberCount: int.tryParse(txt['sm'] ?? '') ?? 1,
      reportCount: 0,
      createdAt: DateTime.now(),
      accessKey: null,
    );
  }
}
