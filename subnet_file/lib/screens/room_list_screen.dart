import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../models/peer.dart';
import '../models/space.dart';
import '../navigation/app_page_route.dart';
import '../providers/providers.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import 'chat_screen.dart';

class RoomListScreen extends ConsumerStatefulWidget {
  const RoomListScreen({super.key});

  @override
  ConsumerState<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends ConsumerState<RoomListScreen> {
  String? _startupError;
  int _segment = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final peersAsyncValue = ref.watch(peersStreamProvider);
    final hostedSpace = ref.watch(hostedSpaceStreamProvider).valueOrNull;
    final hostedMeta = ref.watch(hostedSpaceMetaStreamProvider).valueOrNull;
    final idService = ref.watch(identityServiceProvider);

    return Stack(
      children: [
        const Positioned.fill(child: _SoftBg()),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Row(
                  children: [
                    Text(
                      'Spaces',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(width: 12),
                    _ModePill(
                      label: idService.isGhostMode ? 'Ghost' : 'Visible',
                      ghost: idService.isGhostMode,
                    ),
                    const Spacer(),
                    _CreateButton(onTap: () => _showCreateSpace(context)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _SearchPill(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 34,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _Chip(
                      label: 'All',
                      selected: _segment == 0,
                      onTap: () => setState(() => _segment = 0),
                    ),
                    _Chip(
                      label: 'Public',
                      selected: _segment == 1,
                      onTap: () => setState(() => _segment = 1),
                    ),
                    _Chip(
                      label: 'Private',
                      selected: _segment == 2,
                      onTap: () => setState(() => _segment = 2),
                    ),
                    _Chip(
                      label: 'Ghost Only',
                      selected: _segment == 3,
                      onTap: () => setState(() => _segment = 3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child:
                    _startupError != null
                        ? _ErrorState(message: _startupError!)
                        : peersAsyncValue.when(
                          data:
                              (peers) => _SpacesList(
                                peers: peers,
                                hostedSpace: hostedSpace,
                                hostedMeta: hostedMeta,
                                segment: _segment,
                              ),
                          loading:
                              () => const _EmptyState(
                                title: 'Finding nearby spaces...',
                                subtitle: 'Subnet is listening on this WiFi.',
                              ),
                          error: (err, _) => _ErrorState(message: '$err'),
                        ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCreateSpace(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _CreateSpaceSheet(),
    );
  }
}

class _SpacesList extends ConsumerWidget {
  final List<Peer> peers;
  final String? hostedSpace;
  final SpaceMeta? hostedMeta;
  final int segment;

  const _SpacesList({
    required this.peers,
    required this.hostedSpace,
    required this.hostedMeta,
    required this.segment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasHostedSpace =
        hostedSpace != null && hostedSpace!.trim().isNotEmpty;
    final items = <_SpaceItem>[];
    final spacePeers = peers.where((peer) => peer.spaceMeta != null).toList();

    if (hasHostedSpace) {
      final idService = ref.read(identityServiceProvider);
      final hostedPeer = Peer(
        ipAddress: 'hosted on this device',
        displayName: hostedSpace!,
        deviceId: idService.id,
        isGhost: idService.isGhostMode,
        spaceMeta: hostedMeta,
      );
      items.add(
        _SpaceItem(
          peer: hostedPeer,
          hosted: true,
          visibility: hostedMeta?.visibility ?? SpaceVisibility.public,
          lifetime: hostedMeta?.lifetime,
          members: hostedMeta?.memberCount ?? 1,
          meta: hostedMeta,
        ),
      );
    }

    for (final peer in spacePeers) {
      items.add(
        _SpaceItem(
          peer: peer,
          hosted: false,
          visibility: peer.spaceMeta!.visibility,
          lifetime: peer.spaceMeta!.lifetime,
          members: peer.spaceMeta!.memberCount,
          meta: peer.spaceMeta,
        ),
      );
    }

    final filtered =
        items.where((item) {
          switch (segment) {
            case 1:
              return item.visibility == SpaceVisibility.public;
            case 2:
              return item.visibility == SpaceVisibility.private;
            case 3:
              return item.visibility == SpaceVisibility.ghost;
            default:
              return true;
          }
        }).toList();

    filtered.sort((a, b) => b.members.compareTo(a.members));

    if (filtered.isEmpty) {
      return const _EmptyState(
        title: 'No spaces on this WiFi',
        subtitle:
            'Try another filter or create a space to start the conversation.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 122),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = filtered[index];
        return _SpaceCard(
          item: item,
          index: index,
          onJoin: () async => _openSpace(context, ref, item),
        );
      },
    );
  }

  Future<void> _openSpace(
    BuildContext context,
    WidgetRef ref,
    _SpaceItem item,
  ) async {
    final idService = ref.read(identityServiceProvider);

    if (item.visibility == SpaceVisibility.ghost && !idService.isGhostMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Switch to Ghost mode to enter ghost-only spaces.'),
        ),
      );
      return;
    }

    String? accessKey;
    if (item.visibility == SpaceVisibility.private && !item.hosted) {
      accessKey = await _askForKey(context);
      if (accessKey == null || accessKey.trim().isEmpty) return;
    }

    if (item.hosted) {
      if (context.mounted) {
        Navigator.of(
          context,
        ).push(AppPageRoute.slideUp(ChatScreen(targetPeer: item.peer)));
      }
      return;
    }

    await ref.read(tcpMessagingServiceProvider).sendChatRequest(
          ipAddress: item.peer.ipAddress,
          senderId: idService.id,
          displayName: idService.safeDisplayName,
          isAnonymous: idService.isGhostMode,
          spaceId: item.meta?.spaceId,
          spaceName: item.meta?.name ?? item.peer.displayName,
          accessKey: accessKey,
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Join request sent to ${item.peer.displayName}')),
      );
    }
  }

  Future<String?> _askForKey(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.surfaceBase,
            title: const Text('Enter private key'),
            content: TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Space key'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Join'),
              ),
            ],
          ),
    );
  }
}

class _SpaceItem {
  final Peer peer;
  final bool hosted;
  final SpaceVisibility visibility;
  final SpaceLifetime? lifetime;
  final int members;
  final SpaceMeta? meta;

  const _SpaceItem({
    required this.peer,
    required this.hosted,
    required this.visibility,
    required this.lifetime,
    required this.members,
    this.meta,
  });
}

class _SpaceCard extends StatelessWidget {
  final _SpaceItem item;
  final int index;
  final VoidCallback onJoin;

  const _SpaceCard({
    required this.item,
    required this.index,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final accents = [
      AppColors.primary,
      const Color(0xFF9B7CFF),
      const Color(0xFF74E19A),
      const Color(0xFFFF78AD),
    ];
    final icons = [
      Icons.menu_book_rounded,
      Icons.music_note_rounded,
      Icons.shield_moon_rounded,
      Icons.sports_esports_rounded,
    ];
    final accent = accents[index % accents.length];

    return GlassCard(
      onTap: onJoin,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
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
            child: Icon(icons[index % icons.length], color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.peer.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Tag(
                      label: item.visibility.label,
                      color: _tagColor(item.visibility),
                    ),
                    if (item.lifetime == SpaceLifetime.temporary)
                      const _Tag(
                        label: 'Temporary',
                        color: AppColors.textTertiary,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.hosted
                      ? 'Hosted by you - ${item.members} people'
                      : '${item.members} people',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: onJoin,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.surfaceElevated,
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(item.hosted ? 'Open' : 'Join'),
          ),
        ],
      ),
    );
  }

  Color _tagColor(SpaceVisibility visibility) {
    switch (visibility) {
      case SpaceVisibility.private:
        return AppColors.primary;
      case SpaceVisibility.ghost:
        return AppColors.ghost;
      case SpaceVisibility.public:
        return AppColors.success;
    }
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
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

class _SearchPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: AppColors.textTertiary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            'Search spaces',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
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
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectChip({
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

class _CreateButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onTap,
      icon: const Icon(Icons.add_rounded),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surfaceElevated,
        foregroundColor: AppColors.textPrimary,
      ),
    );
  }
}

class _CreateSpaceSheet extends ConsumerStatefulWidget {
  const _CreateSpaceSheet();

  @override
  ConsumerState<_CreateSpaceSheet> createState() => _CreateSpaceSheetState();
}

class _CreateSpaceSheetState extends ConsumerState<_CreateSpaceSheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _accessKeyController = TextEditingController();
  SpaceVisibility _visibility = SpaceVisibility.public;
  SpaceLifetime _lifetime = SpaceLifetime.permanent;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _accessKeyController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    if (name.isEmpty) return;

    if (_visibility == SpaceVisibility.private &&
        _accessKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a key for private spaces.')),
      );
      return;
    }

    final idService = ref.read(identityServiceProvider);
    if (_visibility == SpaceVisibility.ghost && !idService.isGhostMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Switch to Ghost mode to create a ghost-only space.'),
        ),
      );
      return;
    }

    const uuid = Uuid();
    setState(() => _saving = true);
    final meta = SpaceMeta(
      spaceId: uuid.v4(),
      adminId: idService.id,
      adminName: idService.safeDisplayName,
      name: name,
      description: description,
      visibility: _visibility,
      lifetime: _lifetime,
      accessKey:
          _visibility == SpaceVisibility.private
              ? _accessKeyController.text.trim()
              : null,
      memberCount: 1,
      reportCount: 0,
      createdAt: DateTime.now(),
    );
    await ref.read(wifiDiscoveryServiceProvider).createHostedSpace(meta);
    await idService.incrementSpacesJoinedCount();
    if (!mounted) return;
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      AppPageRoute.slideUp(
        ChatScreen(
          targetPeer: Peer(
            ipAddress: 'hosted on this device',
            displayName: name,
            deviceId: idService.id,
            isGhost: idService.isGhostMode,
            spaceMeta: meta,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        decoration: const BoxDecoration(
          color: AppColors.surfaceBase,
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Create New Space',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Space Name',
                  hintText: 'Astronomy Club',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'A place for stargazers and space lovers.',
                ),
              ),
              const SizedBox(height: 16),
              Text('Visibility', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SelectChip(
                    label: 'Public',
                    selected: _visibility == SpaceVisibility.public,
                    onTap:
                        () => setState(
                          () => _visibility = SpaceVisibility.public,
                        ),
                  ),
                  _SelectChip(
                    label: 'Private',
                    selected: _visibility == SpaceVisibility.private,
                    onTap:
                        () => setState(
                          () => _visibility = SpaceVisibility.private,
                        ),
                  ),
                  _SelectChip(
                    label: 'Ghost',
                    selected: _visibility == SpaceVisibility.ghost,
                    onTap:
                        () =>
                            setState(() => _visibility = SpaceVisibility.ghost),
                  ),
                ],
              ),
              if (_visibility == SpaceVisibility.private) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _accessKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Private Key',
                    hintText: 'Set a key to join',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('Lifetime', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SelectChip(
                    label: 'Permanent',
                    selected: _lifetime == SpaceLifetime.permanent,
                    onTap:
                        () =>
                            setState(() => _lifetime = SpaceLifetime.permanent),
                  ),
                  _SelectChip(
                    label: 'Temporary',
                    selected: _lifetime == SpaceLifetime.temporary,
                    onTap:
                        () =>
                            setState(() => _lifetime = SpaceLifetime.temporary),
                  ),
                ],
              ),
              if (_lifetime == SpaceLifetime.temporary)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Temporary spaces disappear after 30 minutes with no active members.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _create,
                  child: Text(_saving ? 'Creating...' : 'Create Space'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 18),
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
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
        ),
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
          center: const Alignment(0.5, -0.35),
          radius: 1.15,
          colors: [
            AppColors.primaryGlow.withValues(alpha: 0.14),
            AppColors.appBg,
          ],
        ),
      ),
    );
  }
}
