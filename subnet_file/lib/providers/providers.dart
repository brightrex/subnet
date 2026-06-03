import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wifi_discovery_service.dart';
import '../services/tcp_messaging_service.dart';
import '../services/user_identity_service.dart';
import '../services/report_service.dart';
import '../services/app_settings_service.dart';
import '../models/peer.dart';
import '../models/space.dart';

final identityServiceProvider = ChangeNotifierProvider<UserIdentityService>((ref) {
  return UserIdentityService();
});

final identityRevisionProvider = StateProvider<int>((ref) => 0);

final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService();
});

final wifiDiscoveryServiceProvider = Provider<WifiDiscoveryService>((ref) {
  return WifiDiscoveryService();
});

final tcpMessagingServiceProvider = Provider<TcpMessagingService>((ref) {
  return TcpMessagingService();
});

final appSettingsServiceProvider = ChangeNotifierProvider<AppSettingsService>((ref) {
  return AppSettingsService();
});

// Stream providers for UI reactivity
final peersStreamProvider = StreamProvider<List<Peer>>((ref) {
  final service = ref.watch(wifiDiscoveryServiceProvider);
  return service.peersStream;
});

final hostedSpaceStreamProvider = StreamProvider<String?>((ref) {
  final service = ref.watch(wifiDiscoveryServiceProvider);
  return service.hostedSpaceStream;
});

final hostedSpaceMetaStreamProvider = StreamProvider<SpaceMeta?>((ref) {
  final service = ref.watch(wifiDiscoveryServiceProvider);
  return service.hostedSpaceMetaStream;
});

final messageStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final service = ref.watch(tcpMessagingServiceProvider);
  return service.messageStream;
});
