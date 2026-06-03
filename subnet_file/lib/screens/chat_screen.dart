import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/message.dart';
import '../models/peer.dart';
import '../models/space.dart';
import '../providers/providers.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final Peer targetPeer;

  const ChatScreen({super.key, required this.targetPeer});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  bool _hasText = false;
  bool _showAcceptedNotif = false;
  final Map<String, String> _messageIds = {}; // timestamp+sender -> messageId
  final Map<String, DateTime> _typingIndicators = {}; // displayName -> timestamp
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleTyping);
    _messageSubscription = ref
        .read(tcpMessagingServiceProvider)
        .messageStream
        .listen(_handleMessage);
    // Clean up old typing indicators every 500ms
    Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final expired = _typingIndicators.entries
          .where((e) => now.difference(e.value).inSeconds > 3)
          .map((e) => e.key)
          .toList();
      if (expired.isNotEmpty) {
        setState(() {
          for (final name in expired) {
            _typingIndicators.remove(name);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageSubscription?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _handleTyping() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
      ref.read(tcpMessagingServiceProvider).sendTypingIndicator(
        displayName: ref.read(identityServiceProvider).safeDisplayName,
        isTyping: hasText,
      );
      _typingTimer?.cancel();
      if (hasText) {
        _typingTimer = Timer(const Duration(seconds: 3), () {
          ref.read(tcpMessagingServiceProvider).sendTypingIndicator(
            displayName: ref.read(identityServiceProvider).safeDisplayName,
            isTyping: false,
          );
        });
      }
    }
  }

  void _handleMessage(Map<String, dynamic> msgMap) {
    final msg = ChatMessage.fromJson(msgMap);

    if (msg.type == 'typing') {
      final displayName = msgMap['displayName'] as String?;
      if (displayName != null && (msgMap['isTyping'] ?? false)) {
        setState(() => _typingIndicators[displayName] = DateTime.now());
      } else if (displayName != null) {
        setState(() => _typingIndicators.remove(displayName));
      }
      return;
    }

    if (msg.type == 'reaction') {
      _handleReaction(msgMap);
      return;
    }

    if (msg.type == 'report') {
      ref.read(reportServiceProvider).submitReport(msg.senderId, msg.text);
      return;
    }

    if (msg.type == 'chat_accept') {
      if (!mounted) return;
      setState(() => _showAcceptedNotif = true);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showAcceptedNotif = false);
      });
      return;
    }

    if (msg.type == 'space_report') {
      _handleSpaceReport(msgMap);
      return;
    }

    if (msg.type == 'space_closed') {
      _handleSpaceClosed(msgMap);
      return;
    }

    if (msg.type != 'message') return;

    if (!mounted) return;
    if (_messages.any(
      (m) =>
          m.timestamp.isAtSameMomentAs(msg.timestamp) &&
          m.senderId == msg.senderId,
    ))
      return;

    // Generate messageId
    final msgId = '${msg.timestamp.millisecondsSinceEpoch}_${msg.senderId.hashCode}';
    _messageIds['${msg.timestamp.toIso8601String()}_${msg.senderId}'] = msgId;

    setState(() => _messages.insert(0, msg));
  }

  void _handleReaction(Map<String, dynamic> msgMap) {
    final messageId = msgMap['messageId'] as String?;
    final emoji = msgMap['emoji'] as String?;
    final userId = msgMap['userId'] as String?;
    if (messageId == null || emoji == null || userId == null) return;

    setState(() {
      final msgIndex = _messages.indexWhere((m) {
        final key = '${m.timestamp.toIso8601String()}_${m.senderId}';
        return _messageIds[key] == messageId;
      });
      if (msgIndex >= 0) {
        final msg = _messages[msgIndex];
        final reactions = Map<String, List<String>>.from(msg.reactions);
        if (reactions[emoji]?.contains(userId) ?? false) {
          reactions[emoji]!.remove(userId);
          if (reactions[emoji]!.isEmpty) reactions.remove(emoji);
        } else {
          reactions.putIfAbsent(emoji, () => []).add(userId);
        }
        _messages[msgIndex] = msg.copyWith(reactions: reactions);
      }
    });
  }

  void _handleSpaceReport(Map<String, dynamic> msgMap) {
    final spaceId = msgMap['spaceId'] as String?;
    if (spaceId == null) return;
    final hostedMeta = ref.read(wifiDiscoveryServiceProvider).hostedSpaceMeta;
    if (hostedMeta == null || hostedMeta.spaceId != spaceId) return;
    if (msgMap['isAnonymous'] == true) return;

    final reporterId = msgMap['senderId'] as String?;
    if (reporterId == null) return;

    final count = ref.read(reportServiceProvider).submitSpaceReport(spaceId, reporterId);
    ref.read(wifiDiscoveryServiceProvider).updateHostedReportCount(count);
    if (count >= 10) {
      ref.read(wifiDiscoveryServiceProvider).clearHostedSpace(reason: 'Reported by network');
      ref.read(tcpMessagingServiceProvider).broadcastSpaceClosed(
            spaceId: spaceId,
            reason: 'Space removed after reports',
          );
    }
  }

  void _handleSpaceClosed(Map<String, dynamic> msgMap) {
    final spaceId = msgMap['spaceId'] as String?;
    final reason = msgMap['reason'] as String? ?? 'Space closed';
    if (spaceId == null) return;
    if (widget.targetPeer.spaceMeta?.spaceId != spaceId) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.appBg,
      body: Stack(
        children: [
          const Positioned.fill(child: _ChatBackground()),
          Column(
            children: [
              if (_showAcceptedNotif)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.green.withOpacity(0.1),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Request accepted!',
                        style: GoogleFonts.inter(
                          color: Colors.green.shade400,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate(onPlay: (controller) => controller.loop())
                    .fadeIn(duration: 200.ms)
                    .then()
                    .fadeOut(
                      delay: 3500.ms,
                      duration: 300.ms,
                    ),
              _ChatAppBar(
                peer: widget.targetPeer,
                onMenu: () => _showChatMenu(widget.targetPeer),
              ),
              Expanded(
                child:
                    _messages.isEmpty
                        ? const _EmptyChatState()
                        : ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final idService = ref.read(identityServiceProvider);
                            final settings = ref.watch(
                              appSettingsServiceProvider,
                            );
                            final isMe = msg.senderId == idService.id;
                            final isExposed = ref
                                .read(reportServiceProvider)
                                .isExposed(msg.senderId);

                            return _SwipeReplyWrapper(
                                  onReply: () => HapticFeedback.mediumImpact(),
                                  child: GestureDetector(
                                    onLongPress: () => _showActions(msg, isMe),
                                    child: _MessageBubble(
                                      message: msg,
                                      isMe: isMe,
                                      isExposed: isExposed,
                                      showTimestamp: settings.showTimestamps,
                                    ),
                                  ),
                                )
                                .animate()
                                .fade(
                                  duration: 180.ms,
                                  curve: Curves.easeOutCubic,
                                )
                                .slideY(
                                  begin: 0.12,
                                  end: 0,
                                  duration: 180.ms,
                                  curve: Curves.easeOutCubic,
                                );
                          },
                        ),
              ),
              if (_typingIndicators.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '${_typingIndicators.keys.join(', ')} ${_typingIndicators.length > 1 ? 'are' : 'is'} typing...',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              _InputBar(
                controller: _textController,
                hasText: _hasText,
                onSend: _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.mediumImpact();
    final idService = ref.read(identityServiceProvider);
    final isSpace = widget.targetPeer.spaceMeta != null;
    final msg = ChatMessage(
      senderId: idService.id,
      displayName: idService.safeDisplayName,
      text: text,
      timestamp: DateTime.now(),
      isAnonymous: idService.isGhostMode,
    );

    // Generate messageId for reactions
    final msgId = '${msg.timestamp.millisecondsSinceEpoch}_${msg.senderId.hashCode}';
    _messageIds['${msg.timestamp.toIso8601String()}_${msg.senderId}'] = msgId;

    final payload = msg.toJson()
      ..addAll({
        'scope': isSpace ? 'space' : 'direct',
        'messageId': msgId,
      });

    if (isSpace) {
      ref.read(tcpMessagingServiceProvider).broadcastMessage(payload);
    } else {
      ref.read(tcpMessagingServiceProvider).sendToPeer(widget.targetPeer.ipAddress, payload);
    }
    ref.read(identityServiceProvider).incrementMessageCount();
    _textController.clear();
  }

  void _showActions(ChatMessage msg, bool isMe) {
    HapticFeedback.mediumImpact();
    final idService = ref.read(identityServiceProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _ReactionSheet(
            canReport: !isMe && !idService.isGhostMode,
            onReact: () {
              Navigator.pop(context);
              _showEmojiPicker(msg);
              idService.incrementReactionCount();
            },
            onReport: () {
              Navigator.pop(context);
              _report(msg.senderId);
            },
          ),
    );
  }

  void _showEmojiPicker(ChatMessage msg) {
    const emojis = ['❤️', '😂', '😮', '😢', '🔥', '👍', '👎', '🎉'];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: emojis.map((emoji) {
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                final msgId = '${msg.timestamp.millisecondsSinceEpoch}_${msg.senderId.hashCode}';
                final idService = ref.read(identityServiceProvider);
                ref.read(tcpMessagingServiceProvider).sendMessageReaction(
                  messageId: msgId,
                  emoji: emoji,
                  userId: idService.id,
                  displayName: idService.safeDisplayName,
                );
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _report(String targetId) {
    final idService = ref.read(identityServiceProvider);
    final msg = ChatMessage(
      senderId: idService.id,
      displayName: idService.safeDisplayName,
      text: targetId,
      timestamp: DateTime.now(),
      isAnonymous: false,
      type: 'report',
    );
    ref.read(tcpMessagingServiceProvider).broadcastMessage(msg.toJson());
  }

  void _showChatMenu(Peer peer) {
    final meta =
        peer.ipAddress == 'hosted on this device'
            ? ref.read(wifiDiscoveryServiceProvider).hostedSpaceMeta
            : null;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChatMenuSheet(peer: peer, meta: meta),
    );
  }
}

class _ChatAppBar extends StatelessWidget {
  final Peer peer;
  final VoidCallback onMenu;

  const _ChatAppBar({required this.peer, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(8, topPad + 8, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceBase.withValues(alpha: 0.82),
            border: const Border(
              bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            peer.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (peer.displayName.startsWith('ghost_'))
                          const Icon(
                            Icons.visibility_off_rounded,
                            color: AppColors.ghost,
                          ),
                      ],
                    ),
                    Text(
                      'Live WiFi space',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onMenu,
                icon: const Icon(
                  Icons.more_horiz_rounded,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isExposed;
  final bool showTimestamp;
  final VoidCallback? onReactionTap;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isExposed,
    required this.showTimestamp,
    this.onReactionTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGhost = message.isAnonymous;
    final align = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.68;
    final nameColor =
        isExposed
            ? AppColors.danger
            : (isGhost ? AppColors.ghost : AppColors.primary);

    final decoration = BoxDecoration(
      gradient:
          isMe
              ? const LinearGradient(
                colors: [Color(0xFFF6D365), Color(0xFFEFC14F)],
              )
              : LinearGradient(
                colors:
                    isGhost
                        ? [const Color(0x447EE7FF), const Color(0x181D222B)]
                        : [const Color(0xFF1D222B), const Color(0xFF1A1F27)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(isMe ? 20 : 6),
        topRight: Radius.circular(isMe ? 6 : 20),
        bottomLeft: const Radius.circular(20),
        bottomRight: const Radius.circular(20),
      ),
      border: Border.all(
        color:
            isExposed
                ? AppColors.danger
                : (isGhost
                    ? AppColors.ghost.withValues(alpha: 0.42)
                    : AppColors.borderSubtle),
        width: isExposed ? 1.4 : 0.6,
      ),
      boxShadow: [
        BoxShadow(
          color: (isGhost ? AppColors.ghostGlow : AppColors.primaryGlow)
              .withValues(alpha: isMe || isGhost ? 0.22 : 0.04),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ],
    );

    return Align(
      alignment: align,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
        decoration: decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isExposed
                        ? '[EXPOSED] ${message.displayName}'
                        : message.displayName,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: nameColor,
                    ),
                  ),
                  if (isGhost) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.visibility_off_rounded,
                      color: AppColors.ghost,
                      size: 13,
                    ),
                  ],
                ],
              ),
            if (!isMe) const SizedBox(height: 4),
            Text(
              message.text,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                height: 1.3,
                color: isMe ? AppColors.surfaceBase : AppColors.textPrimary,
              ),
            ),
            if (message.reactions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: message.reactions.entries.map((entry) {
                  final emoji = entry.key;
                  final count = entry.value.length;
                  return GestureDetector(
                    onTap: onReactionTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isMe
                            ? AppColors.surfaceBase.withValues(alpha: 0.12)
                            : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isMe
                              ? AppColors.surfaceBase.withValues(alpha: 0.2)
                              : AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 2),
                          Text(
                            count > 1 ? '$count' : '',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isMe ? AppColors.surfaceBase : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (showTimestamp) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  _formatTime(message.timestamp),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color:
                        isMe
                            ? AppColors.surfaceBase.withValues(alpha: 0.68)
                            : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m ${time.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: GlassCard(
          borderRadius: BorderRadius.circular(22),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_tethering_rounded,
                color: AppColors.ghost,
                size: 34,
              ),
              const SizedBox(height: 12),
              Text(
                'No messages yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Messages from this live WiFi space will appear here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeReplyWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  const _SwipeReplyWrapper({required this.child, required this.onReply});

  @override
  State<_SwipeReplyWrapper> createState() => _SwipeReplyWrapperState();
}

class _SwipeReplyWrapperState extends State<_SwipeReplyWrapper> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate:
          (d) => setState(() => _dx = (_dx + d.delta.dx).clamp(0, 72)),
      onHorizontalDragEnd: (_) {
        if (_dx > 54) widget.onReply();
        setState(() => _dx = 0);
      },
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Opacity(
            opacity: (_dx / 72).clamp(0.0, 1.0),
            child: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.surfaceElevated,
                child: Icon(
                  Icons.reply_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_dx, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool hasText;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.hasText,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceBase.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.surfaceElevated,
                    child: Icon(
                      Icons.add_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      style: GoogleFonts.dmSans(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        hintStyle: GoogleFonts.dmSans(
                          color: AppColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  AnimatedScale(
                    scale: hasText ? 1 : 0.88,
                    duration: const Duration(milliseconds: 160),
                    child: IconButton.filled(
                      onPressed: hasText ? onSend : null,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.surfaceElevated,
                      ),
                      icon: Icon(
                        Icons.arrow_upward_rounded,
                        color:
                            hasText
                                ? AppColors.surfaceBase
                                : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReactionSheet extends StatelessWidget {
  final bool canReport;
  final VoidCallback onReport;
  final VoidCallback onReact;

  const _ReactionSheet({
    required this.canReport,
    required this.onReport,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          color: AppColors.surfaceBase.withValues(alpha: 0.94),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 18),
                GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _EmojiButton(
                        label: '👍',
                        onTap: () {
                          Navigator.pop(context);
                          onReact();
                        },
                      ),
                      _EmojiButton(
                        label: '❤️',
                        onTap: () {
                          Navigator.pop(context);
                          onReact();
                        },
                      ),
                      _EmojiButton(
                        label: '😂',
                        onTap: () {
                          Navigator.pop(context);
                          onReact();
                        },
                      ),
                      _EmojiButton(
                        label: '😮',
                        onTap: () {
                          Navigator.pop(context);
                          onReact();
                        },
                      ),
                      _EmojiButton(
                        label: '🎉',
                        onTap: () {
                          Navigator.pop(context);
                          onReact();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _ActionRow(
                  icon: Icons.reply_rounded,
                  label: 'Reply',
                  onTap: () => Navigator.pop(context),
                ),
                _ActionRow(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  onTap: () => Navigator.pop(context),
                ),
                if (canReport)
                  _ActionRow(
                    icon: Icons.flag_outlined,
                    label: 'Report',
                    color: AppColors.danger,
                    onTap: onReport,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _EmojiButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _ChatMenuSheet extends StatelessWidget {
  final Peer peer;
  final SpaceMeta? meta;

  const _ChatMenuSheet({required this.peer, required this.meta});

  @override
  Widget build(BuildContext context) {
    final ref = ProviderScope.containerOf(context, listen: false);
    final idService = ref.read(identityServiceProvider);
    final isHost = meta != null && meta!.adminId == idService.id;
    final canReport = !idService.isGhostMode && !isHost && meta != null;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          color: AppColors.surfaceBase.withValues(alpha: 0.94),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 18),
                GlassCard(
                  borderRadius: BorderRadius.circular(22),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                if (canReport)
                  _ActionRow(
                    icon: Icons.flag_outlined,
                    label: 'Report space',
                    color: AppColors.danger,
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(tcpMessagingServiceProvider).sendSpaceReport(
                            ipAddress: peer.ipAddress,
                            spaceId: meta!.spaceId,
                            reporterId: idService.id,
                            isAnonymous: idService.isGhostMode,
                          );
                    },
                  ),
                if (isHost)
                  _ActionRow(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete space',
                    color: AppColors.danger,
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(wifiDiscoveryServiceProvider).clearHostedSpace(reason: 'Space deleted by admin');
                      ref.read(tcpMessagingServiceProvider).broadcastSpaceClosed(
                            spaceId: meta!.spaceId,
                            reason: 'Space deleted by admin',
                          );
                    },
                  ),
                          Icon(
                            Icons.meeting_room_rounded,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              peer.displayName,
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (meta != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Admin: ${meta!.adminName}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${meta!.visibility.label} - ${meta!.lifetime.label}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _ActionRow(
                  icon: Icons.poll_rounded,
                  label: 'Create poll',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Poll creation is coming soon.'),
                      ),
                    );
                  },
                ),
                if (meta != null)
                  _ActionRow(
                    icon: Icons.people_outline_rounded,
                    label: 'Members (${meta!.memberCount})',
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (context) => _MemberListSheet(
                          spaceMeta: meta!,
                          adminName: meta!.adminName,
                          isHost: isHost,
                        ),
                      );
                    },
                  ),
                _ActionRow(
                  icon: Icons.info_outline_rounded,
                  label: 'Space info',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Space details are coming soon.'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberListSheet extends StatelessWidget {
  final SpaceMeta spaceMeta;
  final String adminName;
  final bool isHost;

  const _MemberListSheet({
    required this.spaceMeta,
    required this.adminName,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          color: AppColors.surfaceBase.withValues(alpha: 0.94),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Members',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${spaceMeta.memberCount} member${spaceMeta.memberCount > 1 ? 's' : ''}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                  child: Column(
                    children: [
                      _MemberTile(
                        name: adminName,
                        badge: 'Admin',
                        isOnline: true,
                        badgeColor: AppColors.primary,
                      ),
                      Divider(
                        height: 1,
                        color: AppColors.borderSubtle,
                        indent: 16,
                        endIndent: 16,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(
                          '${spaceMeta.memberCount - 1} other member${spaceMeta.memberCount - 1 != 1 ? 's' : ''}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.borderSubtle),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String name;
  final String? badge;
  final bool isOnline;
  final Color badgeColor;

  const _MemberTile({
    required this.name,
    this.badge,
    required this.isOnline,
    this.badgeColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badgeColor.withValues(alpha: 0.12),
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.08),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.person_rounded, color: badgeColor, size: 24),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green.shade400,
                        border: Border.all(color: AppColors.surfaceBase, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (badge != null)
                  Text(
                    badge!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: badgeColor,
                    ),
                  ),
              ],
            ),
          ),
          if (isOnline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade400.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade400.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Online',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatBackground extends StatelessWidget {
  const _ChatBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.35, -0.2),
          radius: 1.1,
          colors: [
            AppColors.ghostGlow.withValues(alpha: 0.18),
            AppColors.appBg,
          ],
        ),
      ),
    );
  }
}
