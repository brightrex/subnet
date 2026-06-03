import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/peer.dart';
import '../models/space.dart';
import '../providers/providers.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/glass_card.dart';
import 'contacts_screen.dart';
import 'room_list_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DiscoverScreen(),
      const RoomListScreen(),
      const ContactsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.appBg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInOut,
        child: pages[_navIndex],
      ),
      bottomNavigationBar: BottomNav(
        index: _navIndex,
        onChanged: (i) => setState(() => _navIndex = i),
        items: const [
          BottomNavItem(icon: Icons.travel_explore_rounded, label: 'Discover'),
          BottomNavItem(icon: Icons.grid_view_rounded, label: 'Spaces'),
          BottomNavItem(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Chats',
          ),
          BottomNavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
        ],
      ),
    );
  }
}

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String _wifiName = 'Detecting WiFi...';
  String? _startupError;
  bool _syncing = false;
  int _segment = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLiveDiscovery());
  }

  Future<void> _startLiveDiscovery() async {
    if (mounted) {
      setState(() {
        _syncing = true;
        _startupError = null;
      });
    }
    await _requestNetworkPermissions();
    final info = NetworkInfo();
    final wifiName = await info.getWifiName();
    if (mounted) {
      setState(() => _wifiName = _cleanSsid(wifiName) ?? 'Unknown WiFi');
    }

    try {
      final idService = ref.read(identityServiceProvider);
      await ref.read(tcpMessagingServiceProvider).startServer();
        ref.read(wifiDiscoveryServiceProvider).attachConnectionStream(
              ref.read(tcpMessagingServiceProvider).connectionCountStream,
            );
      await ref
          .read(wifiDiscoveryServiceProvider)
          .startDiscovery(
            displayName: idService.safeDisplayName,
            deviceId: idService.id,
            isGhost: idService.isGhostMode,
          );
    } catch (e) {
      if (mounted) setState(() => _startupError = e.toString());
    }

    if (mounted) {
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _syncing = false);
      });
    }
  }

  Future<void> _refreshDiscovery() async {
    if (mounted) {
      setState(() {
        _syncing = true;
        _startupError = null;
      });
    }

    await _requestNetworkPermissions();
    final info = NetworkInfo();
    final wifiName = await info.getWifiName();
    if (mounted) {
      setState(() => _wifiName = _cleanSsid(wifiName) ?? 'Unknown WiFi');
    }

    try {
      final idService = ref.read(identityServiceProvider);
        ref.read(wifiDiscoveryServiceProvider).attachConnectionStream(
              ref.read(tcpMessagingServiceProvider).connectionCountStream,
            );
      await ref.read(tcpMessagingServiceProvider).startServer();
      await ref
          .read(wifiDiscoveryServiceProvider)
          .refreshDiscovery(
            displayName: idService.safeDisplayName,
            deviceId: idService.id,
            isGhost: idService.isGhostMode,
          );
    } catch (e) {
      if (mounted) setState(() => _startupError = e.toString());
    }

    if (mounted) {
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _syncing = false);
      });
    }
  }

  String? _cleanSsid(String? ssid) {
    if (ssid == null || ssid.isEmpty || ssid == '<unknown ssid>') return null;
    return ssid.replaceAll('"', '');
  }

  Future<void> _requestNetworkPermissions() async {
    await Permission.locationWhenInUse.request();
    await Permission.nearbyWifiDevices.request();
  }

  @override
  Widget build(BuildContext context) {
    final peers = ref.watch(peersStreamProvider);

    return peers.when(
      data:
          (items) => _DiscoverView(
            wifiName: _wifiName,
            peers: items,
            startupError: _startupError,
            segment: _segment,
            syncing: _syncing,
            onSegmentChanged: (value) => setState(() => _segment = value),
            onRefresh: _refreshDiscovery,
          ),
      loading:
          () => _DiscoverView(
            wifiName: _wifiName,
            peers: const [],
            startupError: _startupError,
            scanning: true,
            segment: _segment,
            syncing: _syncing,
            onSegmentChanged: (value) => setState(() => _segment = value),
            onRefresh: _refreshDiscovery,
          ),
      error:
          (err, _) => _DiscoverView(
            wifiName: _wifiName,
            peers: const [],
            startupError: '$err',
            segment: _segment,
            syncing: _syncing,
            onSegmentChanged: (value) => setState(() => _segment = value),
            onRefresh: _refreshDiscovery,
          ),
    );
  }
}

class _DiscoverView extends ConsumerWidget {
  final String wifiName;
  final List<Peer> peers;
  final String? startupError;
  final bool scanning;
  final bool syncing;
  final int segment;
  final ValueChanged<int> onSegmentChanged;
  final VoidCallback onRefresh;

  const _DiscoverView({
    required this.wifiName,
    required this.peers,
    required this.startupError,
    this.scanning = false,
    required this.syncing,
    required this.segment,
    required this.onSegmentChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idService = ref.watch(identityServiceProvider);
    final isGhost = idService.isGhostMode;
    final syncActive = scanning || syncing;
    final peoplePeers = peers.where((peer) => peer.spaceMeta == null).toList();
    final spacePeers =
      peers.where((peer) => peer.spaceMeta != null).toList()..sort(
          (a, b) =>
              b.spaceMeta!.memberCount.compareTo(a.spaceMeta!.memberCount),
        );

    Future<String?> askForKey() {
      final controller = TextEditingController();
      return showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceBase,
          title: const Text('Enter private key'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Space key'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Join')),
          ],
        ),
      );
    }

    Future<void> sendRequest(Peer peer, {bool isSpace = false}) async {
      String? accessKey;
      if (isSpace && peer.spaceMeta?.visibility == SpaceVisibility.private) {
        accessKey = await askForKey();
        if (accessKey == null || accessKey.trim().isEmpty) return;
      }
      await ref.read(tcpMessagingServiceProvider).sendChatRequest(
            ipAddress: peer.ipAddress,
            senderId: idService.id,
            displayName: idService.safeDisplayName,
            isAnonymous: idService.isGhostMode,
            spaceId: isSpace ? peer.spaceMeta?.spaceId : null,
            spaceName: isSpace ? peer.spaceMeta?.name : null,
            accessKey: accessKey,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isSpace ? 'Join request sent' : 'Chat request sent')),
        );
      }
    }

    return Stack(
      children: [
        const Positioned.fill(child: _PageGlow()),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Discover',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Connected to WiFi:',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          wifiName,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ghost,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ModePill(
                    label: isGhost ? 'Ghost' : 'Visible',
                    ghost: isGhost,
                  ),
                  const SizedBox(width: 10),
                  _RoundIconButton(
                    icon: Icons.refresh_rounded,
                    onTap: onRefresh,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SyncRadar(active: syncActive),
              const SizedBox(height: 10),
              Center(
                child: Column(
                  children: [
                    Text(
                      '${peoplePeers.length} people nearby',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      syncActive
                          ? 'Syncing with this WiFi...'
                          : (peers.isEmpty
                              ? 'No one found yet'
                              : 'Live on this WiFi'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                children: [
                  _SegmentChip(
                    label: 'Spaces',
                    selected: segment == 0,
                    onTap: () => onSegmentChanged(0),
                  ),
                  _SegmentChip(
                    label: 'People',
                    selected: segment == 1,
                    onTap: () => onSegmentChanged(1),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    segment == 0
                        ? 'Spaces on this WiFi'
                        : 'People on this WiFi',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  Text(
                    segment == 0 ? 'Sorted by activity' : 'Direct chat',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (startupError != null)
                _EmptyLiveState(
                  icon: Icons.error_outline_rounded,
                  title: 'Discovery needs attention',
                  subtitle: startupError!,
                )
              else if ((segment == 0 && spacePeers.isEmpty) ||
                  (segment == 1 && peoplePeers.isEmpty))
                _EmptyLiveState(
                  icon: Icons.radar_rounded,
                  title: segment == 0 ? 'No spaces found' : 'No people found',
                  subtitle:
                      'When another Subnet user joins this WiFi, they will appear here.',
                )
              else if (segment == 0)
                for (final peer in spacePeers) ...[
                  _DiscoverTile(
                    title: peer.spaceMeta?.name ?? peer.displayName,
                    subtitle: '${peer.spaceMeta?.memberCount ?? 1} active now',
                    icon: Icons.grid_view_rounded,
                    badge: peer.spaceMeta?.visibility.label,
                    onTap: () => sendRequest(peer, isSpace: true),
                  ),
                  const SizedBox(height: 10),
                ]
              else
                for (final peer in peoplePeers) ...[
                  _DiscoverTile(
                    title: peer.displayName,
                    subtitle: peer.ipAddress,
                    icon:
                        peer.isGhost
                            ? Icons.visibility_off_rounded
                            : Icons.person_rounded,
                    badge: peer.isGhost ? 'Ghost' : null,
                    onTap: () => sendRequest(peer),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ],
    );
  }

  int _estimateMembers(Peer peer) {
    final hash = peer.displayName.hashCode.abs();
    return (hash % 6) + 1;
  }
}

class _EmptyLiveState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyLiveState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(icon, color: AppColors.ghost, size: 32),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DiscoverTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;

  const _DiscoverTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      _Badge(label: badge!),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final bool ghost;

  const _ModePill({required this.label, required this.ghost});

  @override
  Widget build(BuildContext context) {
    final color = ghost ? AppColors.ghost : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ghost ? Icons.visibility_off_rounded : Icons.circle,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? AppColors.surfaceBase : AppColors.textSecondary,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceBase,
      side: const BorderSide(color: AppColors.borderSubtle),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }
}

class _SyncRadar extends StatefulWidget {
  final bool active;

  const _SyncRadar({required this.active});

  @override
  State<_SyncRadar> createState() => _SyncRadarState();
}

class _SyncRadarState extends State<_SyncRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.active) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _SyncRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: AnimatedBuilder(
        animation: _controller,
        builder:
            (context, _) => CustomPaint(
              painter: _SyncRadarPainter(_controller.value, widget.active),
              size: Size.infinite,
            ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: AppColors.surfaceElevated.withValues(alpha: 0.76),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, color: AppColors.textPrimary, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncRadarPainter extends CustomPainter {
  final double t;
  final bool active;

  _SyncRadarPainter(this.t, this.active);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final orbit =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.ghost.withValues(alpha: 0.16);
    final glowPaint =
        Paint()
          ..color = AppColors.ghostGlow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    final sweepPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = AppColors.primary.withValues(alpha: active ? 0.55 : 0.25);

    canvas.drawCircle(center, 52, glowPaint);
    for (final r in [44.0, 78.0, 112.0]) {
      canvas.drawCircle(center, r, orbit);
    }

    final sweepAngle = 1.4;
    final start = (t * 6.28318) - (sweepAngle / 2);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 112),
      start,
      sweepAngle,
      false,
      sweepPaint,
    );

    final dotAngle = t * 6.28318;
    final dot = center + Offset(112 * cos(dotAngle), 112 * sin(dotAngle));
    canvas.drawCircle(dot, 5, Paint()..color = AppColors.primary);

    final pulse = 0.8 + 0.2 * sin(t * 6.28318);
    canvas.drawCircle(
      center,
      28 * pulse,
      Paint()..color = AppColors.ghost.withValues(alpha: 0.22),
    );
    canvas.drawCircle(center, 20, Paint()..color = AppColors.surfaceElevated);
  }

  @override
  bool shouldRepaint(covariant _SyncRadarPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.active != active;
}

class _PageGlow extends StatelessWidget {
  const _PageGlow();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.2, -0.25),
          radius: 1.05,
          colors: [
            AppColors.ghostGlow.withValues(alpha: 0.18),
            AppColors.primaryGlow.withValues(alpha: 0.08),
            AppColors.appBg,
          ],
        ),
      ),
    );
  }
}
