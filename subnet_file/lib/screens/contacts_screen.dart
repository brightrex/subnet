import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/message.dart';
import '../models/peer.dart';
import '../models/space.dart';
import '../navigation/app_page_route.dart';
import '../providers/providers.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import 'chat_screen.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final List<ChatMessage> _recentMessages = [];
  StreamSubscription<Map<String, dynamic>>? _subscription;
  final _searchController = TextEditingController();
  String _query = '';
  final Map<String, _ChatRequest> _requests = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final next = _searchController.text.trim().toLowerCase();
      if (next != _query) setState(() => _query = next);
    });
    _subscription = ref.read(tcpMessagingServiceProvider).messageStream.listen(
      (event) {
        final type = event['type'] ?? 'message';
        if (type == 'chat_request') {
          _handleChatRequest(event);
          return;
        }
        if (type == 'chat_accept') {
          _handleChatAccept(event);
          return;
        }
        if (type == 'chat_deny') {
          _handleChatDeny(event);
          return;
        }
        if (type != 'message') return;

        final msg = ChatMessage.fromJson(event);
        if (!mounted) return;
        setState(() {
          _recentMessages.removeWhere((m) => m.senderId == msg.senderId);
          _recentMessages.insert(0, msg);
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleChatRequest(Map<String, dynamic> event) {
    final requestId = event['requestId'] as String?;
    if (requestId == null || requestId.isEmpty) return;

    final idService = ref.read(identityServiceProvider);
    final senderId = event['senderId'] as String? ?? '';
    final displayName = event['displayName'] as String? ?? 'Unknown';
    final isGhost = event['isAnonymous'] == true;
    final sourceIp = event['sourceIp'] as String? ?? '';
    final spaceId = event['spaceId'] as String?;
    final spaceName = event['spaceName'] as String?;
    final accessKey = event['accessKey'] as String?;
    final isIncoming = senderId != idService.id;

    if (isIncoming && sourceIp.isEmpty) return;

    if (isIncoming && spaceId != null) {
      final hostedMeta = ref.read(wifiDiscoveryServiceProvider).hostedSpaceMeta;
      if (hostedMeta == null || hostedMeta.spaceId != spaceId) return;
      if (hostedMeta.visibility == SpaceVisibility.private && hostedMeta.accessKey != null) {
        if (accessKey != hostedMeta.accessKey) {
          ref.read(tcpMessagingServiceProvider).sendChatDeny(
                ipAddress: sourceIp,
                requestId: requestId,
                senderId: idService.id,
                reason: 'Invalid key',
              );
          return;
        }
      }
    }

    final timestamp = DateTime.tryParse(event['timestamp'] ?? '') ?? DateTime.now();

    setState(() {
      _requests[requestId] = _ChatRequest(
        requestId: requestId,
        senderId: senderId,
        displayName: displayName,
        isGhost: isGhost,
        sourceIp: sourceIp,
        timestamp: timestamp,
        isIncoming: isIncoming,
        spaceId: spaceId,
        spaceName: spaceName,
        status: _RequestStatus.pending,
      );
    });
  }

  void _handleChatAccept(Map<String, dynamic> event) {
    final requestId = event['requestId'] as String?;
    if (requestId == null) return;
    final req = _requests[requestId];
    if (req == null) return;
    if (!mounted) return;

    setState(() {
      _requests[requestId] = req.copyWith(status: _RequestStatus.accepted);
    });

    if (!req.isIncoming) {
      _openAccepted(req);
    }
  }

  void _handleChatDeny(Map<String, dynamic> event) {
    final requestId = event['requestId'] as String?;
    if (requestId == null) return;
    final req = _requests[requestId];
    if (req == null) return;

    final reason = event['reason'] as String?;

    setState(() {
      _requests[requestId] = req.copyWith(status: _RequestStatus.denied);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason ?? 'Request denied by ${req.displayName}')),
      );
    }
  }

  Future<void> _acceptRequest(_ChatRequest request) async {
    final idService = ref.read(identityServiceProvider);
    await ref.read(tcpMessagingServiceProvider).sendChatAccept(
          ipAddress: request.sourceIp,
          requestId: request.requestId,
          senderId: idService.id,
          spaceId: request.spaceId,
        );

    setState(() {
      if (request.isSpaceRequest) {
        _requests.remove(request.requestId);
      } else {
        _requests[request.requestId] = request.copyWith(status: _RequestStatus.accepted);
      }
    });

    if (!request.isSpaceRequest) {
      _openAccepted(request);
    }
  }

  Future<void> _denyRequest(_ChatRequest request) async {
    final idService = ref.read(identityServiceProvider);
    await ref.read(tcpMessagingServiceProvider).sendChatDeny(
          ipAddress: request.sourceIp,
          requestId: request.requestId,
          senderId: idService.id,
        );
    setState(() {
      _requests.remove(request.requestId);
    });
  }

  Future<void> _openAccepted(_ChatRequest request) async {
    final peer = Peer(
      ipAddress: request.sourceIp,
      displayName: request.displayName,
      deviceId: request.senderId,
      isGhost: request.isGhost,
    );
    if (request.isSpaceRequest) {
      await ref.read(identityServiceProvider).incrementSpacesJoinedCount();
    }
    await ref.read(tcpMessagingServiceProvider).connectToPeer(peer.ipAddress);
    if (mounted) {
      Navigator.of(context).push(AppPageRoute.slideUp(ChatScreen(targetPeer: peer)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final peersAsync = ref.watch(peersStreamProvider);
    final idService = ref.watch(identityServiceProvider);
    final requests = _requests.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final incoming = requests.where((r) => r.isIncoming && r.status == _RequestStatus.pending).toList();
    final outgoing = requests.where((r) => !r.isIncoming && r.status == _RequestStatus.pending).toList();
    final accepted = requests.where((r) => r.status == _RequestStatus.accepted).toList();
    final filteredMessages =
        _query.isEmpty
            ? _recentMessages
            : _recentMessages
                .where((msg) => msg.displayName.toLowerCase().contains(_query))
                .toList();

    Future<void> sendRequest(Peer peer) async {
      await ref.read(tcpMessagingServiceProvider).sendChatRequest(
            ipAddress: peer.ipAddress,
            senderId: idService.id,
            displayName: idService.safeDisplayName,
            isAnonymous: idService.isGhostMode,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request sent to ${peer.displayName}')),
        );
      }
    }

    return Stack(
      children: [
        const Positioned.fill(child: _SoftBg()),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 122),
            children: [
              Row(
                children: [
                  Text(
                    'Chats',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(width: 12),
                  _ModePill(
                    label: idService.isGhostMode ? 'Ghost' : 'Visible',
                    ghost: idService.isGhostMode,
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Scan is coming soon.')),
                      );
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceElevated,
                      foregroundColor: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: () {},
                    icon: const Icon(Icons.edit_square),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceElevated,
                      foregroundColor: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search people or chats',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (incoming.isNotEmpty || outgoing.isNotEmpty || accepted.isNotEmpty) ...[
                Text('Requests', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                for (final req in incoming) ...[
                  _RequestTile(
                    request: req,
                    onAccept: () => _acceptRequest(req),
                    onDeny: () => _denyRequest(req),
                  ),
                  const SizedBox(height: 10),
                ],
                for (final req in outgoing) ...[
                  _RequestTile(request: req),
                  const SizedBox(height: 10),
                ],
                for (final req in accepted) ...[
                  _RequestTile(
                    request: req,
                    onOpen: () => _openAccepted(req),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
              ],
              Text(
                'People nearby',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              peersAsync.when(
                data: (peers) {
                  final peoplePeers = peers.where((peer) => peer.spaceMeta == null).toList();
                  final filteredPeers =
                    _query.isEmpty
                      ? peoplePeers
                      : peoplePeers
                        .where(
                        (peer) => peer.displayName
                          .toLowerCase()
                          .contains(_query),
                        )
                        .toList();
                  if (filteredPeers.isEmpty) {
                    return const _EmptyPeople();
                  }
                  return Column(
                    children: [
                      for (final peer in filteredPeers) ...[
                        _PersonTile(peer: peer, onTap: () => sendRequest(peer)),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
                loading:
                    () => const _EmptyPeople(message: 'Searching this WiFi...'),
                error: (err, _) => _EmptyPeople(message: '$err'),
              ),
              const SizedBox(height: 18),
              Text(
                'Recent chats',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (filteredMessages.isEmpty)
                const _EmptyChats()
              else
                for (final msg in filteredMessages) ...[
                  _ChatTile(message: msg),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatMessage message;

  const _ChatTile({required this.message});

  @override
  Widget build(BuildContext context) {
    final accent = message.isAnonymous ? AppColors.ghost : AppColors.primary;

    return GlassCard(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.16),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.16),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Icon(
              message.isAnonymous
                  ? Icons.visibility_off_rounded
                  : Icons.person_rounded,
              color: accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  message.text,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatTime(message.timestamp),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _PersonTile extends StatelessWidget {
  final Peer peer;
  final VoidCallback onTap;

  const _PersonTile({required this.peer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isGhost = peer.isGhost;
    final accent = isGhost ? AppColors.ghost : AppColors.primary;

    return GlassCard(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.16),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.16),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Icon(
              isGhost ? Icons.visibility_off_rounded : Icons.person_rounded,
              color: accent,
            ),
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
                        peer.displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (isGhost) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Ghost',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppColors.ghost,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  peer.ipAddress,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

class _RequestTile extends StatelessWidget {
  final _ChatRequest request;
  final VoidCallback? onAccept;
  final VoidCallback? onDeny;
  final VoidCallback? onOpen;

  const _RequestTile({
    required this.request,
    this.onAccept,
    this.onDeny,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final accent = request.isGhost ? AppColors.ghost : AppColors.primary;
    final statusLabel = request.status == _RequestStatus.pending
        ? (request.isIncoming ? 'Incoming' : 'Pending')
        : request.status == _RequestStatus.accepted
            ? 'Accepted'
            : 'Denied';

    final isPendingIncoming = request.isIncoming && request.status == _RequestStatus.pending;

    return GlassCard(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header with avatar and info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.16),
                  boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.12), blurRadius: 20, spreadRadius: 2)],
                ),
                child: Icon(
                  request.isGhost ? Icons.visibility_off_rounded : Icons.person_rounded,
                  color: accent,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            request.displayName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (request.isGhost) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.ghost.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Ghost',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ghost,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      request.isSpaceRequest
                          ? 'wants to join ${request.spaceName ?? 'a space'}'
                          : 'wants to chat',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StatusTag(label: statusLabel),
                  ],
                ),
              ),
            ],
          ),
          // Action buttons for pending incoming requests
          if (isPendingIncoming) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDeny,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.textSecondary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Decline',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Accept',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (onOpen != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Open Chat',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  final String label;
  const _StatusTag({required this.label});

  @override
  Widget build(BuildContext context) {
    final isPending = label == 'Pending' || label == 'Incoming';
    final isAccepted = label == 'Accepted';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPending
            ? AppColors.primary.withValues(alpha: 0.1)
            : isAccepted
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPending
              ? AppColors.primary.withValues(alpha: 0.2)
              : isAccepted
                  ? AppColors.success.withValues(alpha: 0.2)
                  : AppColors.borderSubtle,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isPending
              ? AppColors.primary
              : isAccepted
                  ? AppColors.success
                  : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _EmptyPeople extends StatelessWidget {
  final String message;

  const _EmptyPeople({this.message = 'No people found yet'});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.radar_rounded, color: AppColors.ghost, size: 34),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'People on your WiFi will appear here.',
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

enum _RequestStatus { pending, accepted, denied }

class _ChatRequest {
  final String requestId;
  final String senderId;
  final String displayName;
  final bool isGhost;
  final String sourceIp;
  final DateTime timestamp;
  final bool isIncoming;
  final String? spaceId;
  final String? spaceName;
  final _RequestStatus status;

  const _ChatRequest({
    required this.requestId,
    required this.senderId,
    required this.displayName,
    required this.isGhost,
    required this.sourceIp,
    required this.timestamp,
    required this.isIncoming,
    required this.status,
    this.spaceId,
    this.spaceName,
  });

  bool get isSpaceRequest => spaceId != null;

  _ChatRequest copyWith({
    _RequestStatus? status,
  }) {
    return _ChatRequest(
      requestId: requestId,
      senderId: senderId,
      displayName: displayName,
      isGhost: isGhost,
      sourceIp: sourceIp,
      timestamp: timestamp,
      isIncoming: isIncoming,
      status: status ?? this.status,
      spaceId: spaceId,
      spaceName: spaceName,
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

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.chat_bubble_outline_rounded,
            color: AppColors.ghost,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text('No chats yet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Join a live space on this WiFi and new messages will appear here.',
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

class _SoftBg extends StatelessWidget {
  const _SoftBg();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.3),
          radius: 1.05,
          colors: [
            AppColors.ghostGlow.withValues(alpha: 0.12),
            AppColors.appBg,
          ],
        ),
      ),
    );
  }
}
