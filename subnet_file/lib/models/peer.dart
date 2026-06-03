import 'space.dart';

class Peer {
  final String ipAddress;
  final String displayName;
  final String deviceId;
  final bool isGhost;
  final SpaceMeta? spaceMeta;

  const Peer({
    required this.ipAddress,
    required this.displayName,
    required this.deviceId,
    this.isGhost = false,
    this.spaceMeta,
  });
}
